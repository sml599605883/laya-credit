import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/data/models/home_data.dart';
import 'package:laya_credit/data/repositories/app_repository.dart';
import 'package:laya_credit/pages/progress_page.dart';
import 'package:laya_credit/providers/home_provider.dart';
import 'package:laya_credit/providers/repository_provider.dart';

HomeOrderCard _order({
  HomeOrderCardStatus status = HomeOrderCardStatus.reviewed,
  String statusText = '',
  String amountText = 'Loan Amount',
  String dateText = 'Loan Date',
  String jumpUrl = 'https://example.com/order/detail',
}) {
  return HomeOrderCard(
    orderNo: '672024120400405591971039',
    productId: 1,
    productName: 'Cash Moca',
    productLogo: '',
    title: 'Credit activation progress',
    displayAmount: '₱20.000',
    amountText: amountText,
    date: '12-07-2024',
    dateText: dateText,
    orderStatusText: statusText,
    status: status,
    progressText: '',
    steps: const [],
    jumpUrl: jumpUrl,
  );
}

/// 假的首页仓库：返回固定进度卡片，并记录首页接口调用次数。
class _FakeAppRepository extends AppRepository {
  _FakeAppRepository(this.orders, {this.failure}) : super(_placeholderClient());

  final List<HomeOrderCard> orders;
  final Object? failure;
  int homeCalls = 0;

  @override
  Future<ApiResponse<HomeData>> getHomePage() async {
    homeCalls++;
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: HomeData(
        banners: const [],
        product: null,
        orders: orders,
        notices: const [],
      ),
    );
  }
}

HttpClient _placeholderClient() {
  return HttpClient(
    config: NetworkConfig(
      apiBase: Uri.parse('https://localhost/'),
      signSecret: 'test',
      marketIdentifier: 'test',
    ),
    device: const DeviceParams(
      deviceId: 'test-device',
      appVersion: '1.0.0',
      modelName: 'test',
      systemVersion: '1.0',
      advertisingId: '',
    ),
    getUserToken: () => null,
    onAuthExpired: () {},
  );
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _pumpProgress(
  WidgetTester tester,
  _FakeAppRepository repository, {
  double topInset = 0,
}) async {
  _usePhoneSurface(tester);
  if (topInset > 0) {
    tester.view.padding = FakeViewPadding(top: topInset * 3);
  }
  final container = ProviderContainer(
    overrides: [
      appRepositoryProvider.overrideWith((ref) async => repository),
      // 测试进程里没有 BotToastInit，刷新时的全局 Loading 遮罩换成空实现。
      homeLoadingIndicatorProvider.overrideWithValue(
        HomeLoadingIndicator(show: () {}, hide: () {}),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ProgressPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('刘海屏下标题让出顶部安全区，不被遮挡', (tester) async {
    // 88pt 状态栏 / 刘海：标题必须整体落在安全区之下。
    await _pumpProgress(tester, _FakeAppRepository(const []), topInset: 88);

    final titleTop = tester.getTopLeft(find.text('progress')).dy;
    expect(titleTop, greaterThanOrEqualTo(88));
  });

  testWidgets('无进度数据时展示空态插画与提示文案', (tester) async {
    await _pumpProgress(tester, _FakeAppRepository(const []));

    expect(find.byKey(const Key('progress-empty-image')), findsOneWidget);
    expect(find.text('No progress yet'), findsOneWidget);
    expect(find.byKey(const Key('progress-scroll')), findsOneWidget);
  });

  testWidgets('按下发的借款进度卡逐张渲染产品行与金额 / 日期小表', (tester) async {
    await _pumpProgress(
      tester,
      _FakeAppRepository([
        _order(status: HomeOrderCardStatus.reviewed, statusText: 'In Review'),
        _order(
          status: HomeOrderCardStatus.toRepay,
          statusText: 'Repayment Due',
          amountText: 'Repayment',
          dateText: 'Repayment Date',
        ),
      ]),
    );

    expect(find.byKey(const Key('progress-card-reviewed')), findsOneWidget);
    expect(find.byKey(const Key('progress-card-toRepay')), findsOneWidget);
    expect(find.text('In Review'), findsOneWidget);
    expect(find.text('Repayment Due'), findsOneWidget);
    expect(find.text('Cash Moca'), findsNWidgets(2));
    expect(find.text('₱20.000'), findsNWidgets(2));
    expect(find.text('12-07-2024'), findsNWidgets(2));
    expect(find.text('Repayment'), findsOneWidget);
    expect(find.text('Repayment Date'), findsOneWidget);
  });

  group('状态分档与按钮', () {
    testWidgets('审核中 / 放款中只有状态条，没有按钮', (tester) async {
      await _pumpProgress(
        tester,
        _FakeAppRepository([
          _order(status: HomeOrderCardStatus.reviewed),
          _order(status: HomeOrderCardStatus.disbursing),
        ]),
      );

      expect(find.text('In Review'), findsOneWidget);
      expect(find.text('Awaiting Funds'), findsOneWidget);
      expect(find.text('Change'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('待还款 / 已逾期各一颗 Change 按钮', (tester) async {
      await _pumpProgress(
        tester,
        _FakeAppRepository([
          _order(status: HomeOrderCardStatus.toRepay),
          _order(status: HomeOrderCardStatus.overdue),
        ]),
      );

      expect(find.text('Repayment Due'), findsOneWidget);
      expect(find.text('Past Due'), findsOneWidget);
      expect(find.text('Change'), findsNWidgets(2));
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('放款失败给 Try again + Change 两颗按钮', (tester) async {
      await _pumpProgress(
        tester,
        _FakeAppRepository([_order(status: HomeOrderCardStatus.failed1)]),
      );

      expect(find.text('Transfer Unsuccessful'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('后端状态文案为空时回落到设计稿默认文案', (tester) async {
      await _pumpProgress(
        tester,
        _FakeAppRepository([_order(status: HomeOrderCardStatus.disbursing)]),
      );

      expect(find.text('Awaiting Funds'), findsOneWidget);
    });
  });

  testWidgets('下拉刷新重新拉取首页进度数据', (tester) async {
    final repository = _FakeAppRepository([_order()]);
    await _pumpProgress(tester, repository);
    expect(repository.homeCalls, 1);

    await tester.fling(
      find.byKey(const Key('progress-scroll')),
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repository.homeCalls, 2);
  });

  testWidgets('接口失败时展示错误态与重试入口', (tester) async {
    await _pumpProgress(
      tester,
      _FakeAppRepository(const [], failure: Exception('boom')),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const Key('progress-empty-image')), findsNothing);
  });
}
