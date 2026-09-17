import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/network/api_endpoints.dart';
import 'package:laya_credit/core/network/api_exception.dart';
import 'package:laya_credit/core/network/api_fields.dart';
import 'package:laya_credit/core/network/api_protocol.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/network/common_params.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/data/models/home_data.dart';
import 'package:laya_credit/data/models/login_result.dart';
import 'package:laya_credit/data/models/sms_channel_options.dart';
import 'package:laya_credit/data/repositories/app_repository.dart';
import 'package:laya_credit/data/repositories/auth_repository.dart';
import 'package:laya_credit/data/repositories/product_repository.dart';
import 'package:laya_credit/data/models/product_apply_result.dart';
import 'package:laya_credit/data/models/product_detail.dart';
import 'package:laya_credit/theme/app_assets.dart';
import 'package:laya_credit/main.dart';
import 'package:laya_credit/pages/home_page.dart';
import 'package:laya_credit/pages/login_page.dart';
import 'package:laya_credit/providers/network_provider.dart';
import 'package:laya_credit/providers/repository_provider.dart';
import 'package:laya_credit/providers/session_provider.dart';
import 'package:laya_credit/widgets/state_views.dart';
import 'package:laya_credit/widgets/tab_bar/app_tab_bar.dart';

/// 用桩仓库替掉真实网络请求，让页面测试可预期。
/// HttpClient 只作为占位传入，桩方法不会真的发请求。
class _StubAppRepository extends AppRepository {
  _StubAppRepository({this.home, this.failure}) : super(_placeholderClient());

  final HomeData? home;
  final Object? failure;

  @override
  Future<ApiResponse<HomeData>> getHomePage() async {
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data:
          home ??
          const HomeData(banners: [], product: null, orders: [], notices: []),
    );
  }
}

/// 登录/发码仓库桩：只记录调用，不发网络。
class _StubAuthRepository extends AuthRepository {
  _StubAuthRepository({this.failure, this.delay}) : super(_placeholderClient());

  final Object? failure;

  /// 模拟慢请求，用来观察请求进行中的 UI。
  final Duration? delay;

  int sendCodeCalls = 0;
  int loginCalls = 0;

  @override
  Future<ApiResponse<void>> sendSmsCode({
    required String phone,
    required SmsChannel channel,
  }) async {
    sendCodeCalls++;
    if (delay case final wait?) await Future<void>.delayed(wait);
    if (failure case final error?) throw error;
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }

  @override
  Future<ApiResponse<LoginResult>> login({
    required String phone,
    required String code,
  }) async {
    loginCalls++;
    if (delay case final wait?) await Future<void>.delayed(wait);
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: LoginResult(
        sessionId: 'test-session',
        phone: phone,
        realName: '',
        isOldUser: true,
        smsMaxId: '1',
      ),
    );
  }
}

/// 产品申请仓库桩：记录准入调用，返回可配的准入 / 详情结果。
class _StubProductRepository extends ProductRepository {
  _StubProductRepository({
    this.applyResult = const ProductApplyResult(
      statusCode: 200,
      jumpUrl: '',
      jumpType: 0,
      message: '',
    ),
    this.detail = const ProductDetail(
      resultCode: 200,
      basicInfo: ProductBasicInfo(orderNo: 'ORDER-1'),
      nextStep: ProductNextStep(taskType: 'Kegful', title: 'Identity'),
    ),
  }) : super(_placeholderClient());

  final ProductApplyResult applyResult;
  final ProductDetail detail;

  /// (productId, apiRemind)
  final List<(String, int)> applyCalls = [];
  int detailCalls = 0;

  @override
  Future<ApiResponse<ProductApplyResult>> applyProduct({
    required String productId,
    int apiRemind = 0,
  }) async {
    applyCalls.add((productId, apiRemind));
    return ApiResponse(code: 0, message: 'success', data: applyResult);
  }

  @override
  Future<ApiResponse<ProductDetail>> getProductDetail({
    required String productId,
  }) async {
    detailCalls++;
    return ApiResponse(code: 0, message: 'success', data: detail);
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

/// 只记录请求、不发网络，用来校验仓库层传出的字段名。
class _RecordingClient extends HttpClient {
  _RecordingClient()
    : super(
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

  final List<(String, Map<String, Object?>)> calls = [];

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    required Map<String, Object?> params,
    required T Function(Object? data) parse,
  }) async {
    calls.add((path, params));
    return ApiResponse<T>(code: 0, message: 'success', data: parse(null));
  }
}

/// 首页额度大卡 + 授信进度阶段（蓝湖稿 02-01 / 02-02 的 LARGE_CARD）。
const _productCard = HomeProductCard(
  id: '1',
  productName: 'Pera Cash',
  productLogo: '',
  buttonText: 'Apply Now',
  amountRange: '\u20b160,000',
  amountRangeDes: 'Available up to',
  termInfo: '180 Days',
  termInfoDes: 'Loan terms',
  loanRate: '\u2264 0.5% Day',
  loanRateDes: 'Interest rate',
  certifyFinished: false,
  account: '',
  accountText: '',
  progressText: 'Credit activation progress',
  steps: [
    HomeProgressStep(
      title: 'Identity',
      amount: '\u20b1 30,000',
      selected: true,
    ),
    HomeProgressStep(title: 'Living', amount: '\u20b1 40,000', selected: false),
    HomeProgressStep(
      title: 'Basic information',
      amount: '\u20b150,000',
      selected: false,
    ),
    HomeProgressStep(
      title: 'Bank Card',
      amount: '\u20b160,000',
      selected: false,
    ),
  ],
);

/// 进行中的借款订单卡。
const _orderCard = HomeOrderCard(
  orderNo: '39236372837263237',
  productId: 1,
  productName: 'Pera Agad(AA)',
  productLogo: '',
  title: 'Already in default, please repay',
  displayAmount: '\u20b150,000',
  amountText: 'Loan Amount',
  date: '28-12-2022',
  dateText: 'Application date',
  orderStatusText: 'To repay',
  status: HomeOrderCardStatus.toRepay,
  progressText: '',
  steps: [],
  jumpUrl: '',
);

/// 推荐列表里的产品卡（蓝湖稿 02-01 的 PRODUCT_LIST 模块）。
const _recommendationCard = HomeProductListCard(
  id: '1',
  productName: 'PG Finance',
  productLogo: '',
  amountRange: '\u20b160,000',
  amountRangeDes: 'Available up to',
  loanRate: '\u2264 0.5% Day',
  loanRateDes: 'Interest rate',
  termInfo: '\u2264 0.5% Day',
  termInfoText: 'Loan terms',
  tips: ['Low interest rates', 'Ages 17 years and over can borrow'],
  buttonStyle: HomeProductCardButtonStyle.highlighted,
);

void _usePhoneSurface(WidgetTester tester) {
  // 默认的 800x600 测试窗口会把页面下半部分裁掉，断言会失真。
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 读取登录页协议行的勾选切图，用来判断当前是否勾选。
String _loginCheckboxAsset(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byKey(const Key('login-agreement-checkbox')),
      matching: find.byType(Image),
    ),
  );
  return (image.image as AssetImage).assetName;
}

/// 登录页底部运营 Banner（文案已含在切图里）。
Finder _loginBanner() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == AppAssets.loginBanner,
);

/// 登录输入框当前的文本。
String _loginFieldValue(WidgetTester tester, Key fieldKey) {
  return tester.widget<TextField>(find.byKey(fieldKey)).controller!.text;
}

/// 某个登录输入框当前是否持有焦点（有焦点即键盘会弹出）。
bool _loginFieldFocused(WidgetTester tester, Key fieldKey) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(EditableText),
    ),
  );
  return editable.focusNode.hasFocus;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  AppRepository? repository,
  AuthRepository? authRepository,
  ProductRepository? productRepository,
  Future<void> Function(ProviderContainer container)? setUp,
}) async {
  _usePhoneSurface(tester);
  const app = LayaCreditApp();

  // 只建一个容器：嵌套 UncontrolledProviderScope + ProviderScope 会让
  // override 落在子容器上，父容器里的 session 与仓库对不上，测试结论会失真。
  final container = ProviderContainer(
    overrides: [
      // 测试进程里没有 device_info_plus / package_info_plus 的原生实现，
      // 真跑 DeviceParamsLoader 会一直等插件回调、挂到 8 秒超时后留下未完成的定时器。
      // 直接给一份固定设备信息，顺带让「APP Version」这类展示变得可断言。
      deviceParamsProvider.overrideWith(
        (ref) async => const DeviceParams(
          deviceId: 'test-device',
          appVersion: '1.0.0',
          modelName: 'iPhone',
          systemVersion: '18.2',
          advertisingId: '',
        ),
      ),
      if (repository != null)
        appRepositoryProvider.overrideWith((ref) async => repository),
      if (authRepository != null)
        authRepositoryProvider.overrideWith((ref) async => authRepository),
      if (productRepository != null)
        productRepositoryProvider.overrideWith(
          (ref) async => productRepository,
        ),
    ],
  );
  addTearDown(container.dispose);

  if (setUp != null) await setUp(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}

/// 假装弹出的键盘高度（pt）。
const _keyboard = 330.0;

void main() {
  testWidgets('首页渲染标题与底部导航', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    expect(find.text('Laya Credit'), findsOneWidget);
    expect(find.byKey(const Key('app-tab-bar')), findsOneWidget);
  });

  testWidgets('悬浮底部导航不遮挡首页内容', (tester) async {
    const safeBottom = 34.0;
    // 真机底部安全区（刘海屏 34pt）：底栏在安全区之上再让出胶囊的高度。
    tester.view.padding = const FakeViewPadding(bottom: safeBottom * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: safeBottom * 3);
    // 内容必须比屏幕高，才能验证「滚到底之后不被胶囊挡住」。
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: _productCard,
          notices: [],
          orders: [_orderCard, _orderCard],
        ),
      ),
    );

    final bar = find.byKey(const Key('app-tab-bar'));
    final barRect = tester.getRect(bar);
    final pillRect = tester.getRect(find.byKey(const Key('app-tab-bar-pill')));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // 底栏自身高度就是页面要避让的遮挡高度（胶囊 + 下间距 + 安全区），
    // 各 Tab 页照着这个值预留底部内边距，两边必须一致。
    expect(
      barRect.height,
      moreOrLessEquals(AppTabBar.overlapHeight(tester.element(bar))),
    );
    expect(barRect.height, greaterThan(pillRect.height + safeBottom));
    expect(pillRect.top, moreOrLessEquals(barRect.top));

    // 内容铺到屏幕底部（extendBody），从胶囊下方穿过，而不是被截在胶囊顶边。
    final listRect = tester.getRect(
      find.descendant(
        of: find.byType(HomePage),
        matching: find.byType(ListView),
      ),
    );
    expect(listRect.bottom, moreOrLessEquals(screenHeight));

    // 滚到底后最后一条内容停在胶囊上方，不会被永久遮住。
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    final lastCard = find.text('Already in default, please repay').last;
    expect(tester.getRect(lastCard).bottom, lessThanOrEqualTo(pillRect.top));
  });

  testWidgets('首页没有产品大卡时只渲染运营位，不出现设计稿以外的空态卡', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    expect(find.byKey(const Key('home-banner')), findsOneWidget);
    // 设计稿 02-01 只有「额度头图 + 运营位」，没有空态卡与兜底申请按钮
    // （02-03 的进度空态属于进度页）。
    expect(find.text('No loan in progress'), findsNothing);
    expect(find.byKey(const Key('home-apply-button')), findsNothing);
  });

  testWidgets('首页按设计稿 02-02 渲染授信进度卡', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: _productCard,
          orders: [],
          notices: [],
        ),
      ),
    );

    // 卡片视觉是设计稿导出的整卡底图（标题文字烘焙在底图里），页面只叠三行内容。
    expect(find.byKey(const Key('home-progress-card')), findsOneWidget);
    expect(find.text('Credit activation progress'), findsNothing);
    expect(find.text('\u20b1 30,000'), findsOneWidget);
    // \u20b160,000 在额度头图里也有一份，进度卡里是第 4 个阶段。
    expect(find.text('\u20b150,000'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Bank Card'), findsOneWidget);
    // 申请入口在额度卡里，只此一处。
    expect(find.byKey(const Key('home-apply-button')), findsOneWidget);
  });

  testWidgets('首页有进行中订单时展示借款进度卡', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: null,
          notices: [],
          orders: [
            HomeOrderCard(
              orderNo: '39236372837263237',
              productId: 1,
              productName: 'Pera Agad(AA)',
              productLogo: '',
              title: 'Already in default, please repay',
              displayAmount: '\u20b150,000',
              amountText: 'Loan Amount',
              date: '28-12-2022',
              dateText: 'Application date',
              orderStatusText: 'To repay',
              status: HomeOrderCardStatus.toRepay,
              progressText: '',
              steps: [],
              jumpUrl: '',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Already in default, please repay'), findsOneWidget);
    expect(find.text('\u20b150,000'), findsOneWidget);
  });

  testWidgets('首页按设计稿 02-01 渲染推荐列表，标题右侧不出现 More 与箭头', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: null,
          orders: [],
          notices: [],
          productList: [_recommendationCard],
        ),
      ),
    );

    expect(find.text('Recommendation'), findsOneWidget);
    // 设计稿标题右侧的「More + 箭头」按产品要求不渲染。
    expect(find.text('More'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    expect(find.text('PG Finance'), findsOneWidget);
    expect(find.text('\u20b160,000'), findsOneWidget);
    expect(find.text('Available up to'), findsOneWidget);
    expect(find.text('Interest rate'), findsOneWidget);
    expect(find.text('Loan terms'), findsOneWidget);
    expect(
      find.text('Low interest rates / Ages 17 years and over can borrow'),
      findsOneWidget,
    );

    // 按钮是整块切图，按后端 `holts` 选三态配色（这里是高亮）。
    final button = tester.widget<Image>(
      find.byKey(const ValueKey('home-recommendation-apply-1')),
    );
    expect(
      (button.image as AssetImage).assetName,
      AppAssets.homeApplyNowHighlight,
    );
  });

  testWidgets('首页推荐卡整块可点击：点空白处同样走申请流程', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: null,
          orders: [],
          notices: [],
          productList: [_recommendationCard],
        ),
      ),
    );

    await tester.tap(find.text('PG Finance'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('首页没有推荐列表时整块不渲染，不出现空态标题', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    expect(find.text('Recommendation'), findsNothing);
  });

  testWidgets('首页额度头图渲染后端下发的产品、额度、期限与申请入口', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: HomeProductCard(
            id: '1',
            productName: 'Pera Cash',
            productLogo: '',
            buttonText: 'Apply Now',
            amountRange: '\u20b160,000',
            amountRangeDes: 'Available up to',
            termInfo: '180 Days',
            termInfoDes: 'Loan terms',
            loanRate: '\u2264 0.5% Day',
            loanRateDes: 'Interest rate',
            certifyFinished: false,
            account: '',
            accountText: '',
            progressText: '',
            steps: [],
          ),
        ),
      ),
    );

    expect(find.text('Pera Cash'), findsOneWidget);
    expect(find.text('\u20b160,000'), findsOneWidget);
    expect(find.text('Available up to'), findsOneWidget);
    expect(find.text('180 Days'), findsOneWidget);
    expect(find.text('\u2264 0.5% Day'), findsOneWidget);
    expect(find.text('Apply Now'), findsOneWidget);
    expect(find.text('Confirm your loan\uFF0CCash hits fast.'), findsOneWidget);
    // 申请入口在额度卡里，不再额外渲染兜底按钮。
    expect(find.byKey(const Key('home-apply-button')), findsOneWidget);
  });

  testWidgets('首页额度大卡整块可点击：点空白区域同样进入申请流程', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
    );

    // 点在卡片上的非按钮区域（期限文案），而不是 Apply 按钮。
    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    // 游客点击整卡会走和按钮一致的登录引导。
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('首页运营位多条 banner 自动轮播', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [
            HomeBanner(
              id: '1',
              imageUrl: 'https://cdn.example.com/a.png',
              jumpUrl: '',
            ),
            HomeBanner(
              id: '2',
              imageUrl: 'https://cdn.example.com/b.png',
              jumpUrl: '',
            ),
          ],
          product: null,
          orders: [],
          notices: [],
        ),
      ),
    );

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    final start = controller.page!;

    // 每 3 秒切到下一条：等一拍定时器 + 300ms 切换动画。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 350));

    expect(controller.page, closeTo(start == 0 ? 1 : 0, 0.01));

    // 卸载页面，取消轮播定时器，避免测试结束时留下 pending timer。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('首页接口失败时展示错误态而不是闪退', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        failure: const ApiException(
          type: ApiFailureType.noConnection,
          message: '网络连接失败，请检查网络设置',
        ),
      ),
    );

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('网络连接失败，请检查网络设置'), findsOneWidget);
  });

  testWidgets('未登录时点击受保护的 Tab 会跳转登录页', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter mobile number'), findsOneWidget);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
  });

  testWidgets('未登录时统计 Tab 同样需要登录', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-stats')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter mobile number'), findsOneWidget);
  });

  testWidgets('登录页在未填手机号时禁用获取验证码与提交', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    final sendCode = tester.widget<TextButton>(
      find.byKey(const Key('login-send-code-button')),
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit-button')),
    );

    expect(sendCode.onPressed, isNull);
    expect(submit.onPressed, isNull);
  });

  testWidgets('登录页手机号或验证码没填完时不发登录请求', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    // 差一位：按钮保持禁用，也不会触发自动登录。
    await tester.enterText(find.byKey(const Key('login-code-field')), '12345');
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit-button')))
          .onPressed,
      isNull,
    );
    expect(auth.loginCalls, 0);
  });

  testWidgets('登录页验证码填满 6 位自动提交，登录成功后关掉登录页', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 1);
    expect(find.byKey(const Key('login-phone-field')), findsNothing);
  });

  testWidgets('提交登录时收起键盘并显示全屏 loading', (tester) async {
    final auth = _StubAuthRepository(delay: const Duration(milliseconds: 300));
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    // 填满 6 位触发自动提交。
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 请求进行中：键盘收起 + 整屏 loading。
    expect(_loginFieldFocused(tester, const Key('login-code-field')), isFalse);
    // 两个转圈：提交按钮内嵌的那个 + 全屏 loading 的那个。
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('login-phone-field')), findsNothing);
  });

  testWidgets('自动登录失败会清空验证码并回焦，错误走通用文案', (tester) async {
    final auth = _StubAuthRepository(
      failure: const ApiException(
        type: ApiFailureType.noConnection,
        message: '网络连接失败，请检查网络设置',
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();

    expect(find.text('网络连接失败，请检查网络设置'), findsOneWidget);
    expect(_loginFieldValue(tester, const Key('login-code-field')), isEmpty);
    expect(_loginFieldFocused(tester, const Key('login-code-field')), isTrue);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('登录态失效不弹错误提示，交给全局登出流程', (tester) async {
    final auth = _StubAuthRepository(
      failure: const ApiException(
        type: ApiFailureType.authentication,
        message: '登录已过期',
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();

    expect(find.text('登录已过期'), findsNothing);
    expect(find.text('Unable to complete the request.'), findsNothing);
  });

  testWidgets('发码成功后进入倒计时并聚焦验证码框', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.sendCodeCalls, 1);
    expect(find.text('Verification code sent.'), findsOneWidget);
    expect(find.text('60 S'), findsOneWidget);
    expect(_loginFieldFocused(tester, const Key('login-code-field')), isTrue);

    // 收掉倒计时，避免测试结束时还有未完成的计时器。
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('退出登录后登录页回填上次的手机号', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      setUp: (container) async {
        final session = container.read(userSessionProvider.notifier);
        await session.setSession(
          token: 'test-session',
          userId: '1',
          phone: '9171234567',
        );
        // 退出登录只清 token，手机号留着给下次登录回填。
        await session.clearSession();
      },
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    expect(
      _loginFieldValue(tester, const Key('login-phone-field')),
      '9171234567',
    );
    // 手机号回填后「Get it」直接可用。
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('login-send-code-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('未勾选协议时不发请求，点提交浮出提示条', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    // 设计稿默认态协议就是勾上的。
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxChecked);

    // 先取消勾选再填验证码：自动提交静默失败，不发请求。
    await tester.tap(find.byKey(const Key('login-agreement-checkbox')));
    await tester.pump();
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxUnchecked);

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();
    expect(auth.loginCalls, 0);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);

    // 手动提交才浮出设计稿里的提示条。
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();
    expect(
      find.text('Please read and agree to the Privacy Agreement'),
      findsOneWidget,
    );

    // 提示条 2 秒后自动收起。
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('Please read and agree to the Privacy Agreement'),
      findsNothing,
    );
    expect(auth.loginCalls, 0);
  });

  testWidgets('登录页协议里的链接响应点击，不会连带切换勾选态', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    // 点 `Privacy Policy` 只走链接回调，勾选态保持默认的已勾选。
    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    await tester.pump();
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxChecked);

    // 放掉链接回调里的 Toast 动画，避免测试结束时有未完成的计时器。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('登录页点击空白处收起键盘', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    const phoneField = Key('login-phone-field');
    await tester.tap(find.byKey(phoneField));
    await tester.pumpAndSettle();
    expect(_loginFieldFocused(tester, phoneField), isTrue);

    // 点标题下方的空白背景（品牌行左侧）。
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(_loginFieldFocused(tester, phoneField), isFalse);
  });

  testWidgets('键盘弹出时底部 Banner 不被顶起，只有表单区让位', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    final formArea = find.descendant(
      of: find.byType(LoginPage),
      matching: find.byType(SingleChildScrollView),
    );
    final bannerBefore = tester.getRect(_loginBanner());
    final formBefore = tester.getRect(formArea);
    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // Banner 下方的留白（Banner + 间距 + 安全区）不算被键盘盖住。
    final bottomBlock = screenBottom - formBefore.bottom;

    // 测试面是 3 倍图，990 物理像素 = 330pt 键盘。
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 3);
    await tester.pumpAndSettle();

    expect(tester.getRect(_loginBanner()), bannerBefore);
    // 表单区底部正好停在键盘上沿，中间不留空白。
    expect(tester.getRect(formArea).bottom, screenBottom - _keyboard);
    expect(
      tester.getRect(formArea).height,
      formBefore.height - (_keyboard - bottomBlock),
    );
  });

  testWidgets('登录后个人中心按蓝湖稿 07-01 展示头图与两组入口', (tester) async {
    await _pumpApp(
      tester,
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
      repository: _StubAppRepository(),
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    // 头图：标题 + 手机号脱敏（设计稿 `962 **** 1300`）。
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('917 **** 4567'), findsOneWidget);

    // 订单入口四个筛选项，顺序与设计稿 `list_3` 一致。
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);

    // 两组入口都是客户端固定内容，不依赖后端下发。
    expect(find.text('Customer Service'), findsOneWidget);
    expect(find.text('Smart customer service'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('APP Version'), findsOneWidget);
    expect(find.text('Privacy Agreement'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // 订单卡底部那块薄荷色「肩线」是设计稿 `image_2` 的切图，别退回手画。
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                AppAssets.mineOrderCardShoulder,
      ),
      findsOneWidget,
    );
  });

  testWidgets('个人中心 Account 行弹出设计稿里的退出面板', (tester) async {
    // 设计稿的面板画到 812pt 底边，没有留手势条的位置，真机上必须自己让开。
    const safeBottom = 34.0;
    tester.view.padding = const FakeViewPadding(bottom: safeBottom * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: safeBottom * 3);

    await _pumpApp(
      tester,
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
      repository: _StubAppRepository(),
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();

    // 设计稿 `07-01 - 个人中心-退出` 的三个行动项。
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Quit'), findsOneWidget);

    // 面板背景铺到底，但最后一行要整个待在安全区之上。
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(
      sheet.bottom - tester.getRect(find.text('Quit')).bottom,
      greaterThanOrEqualTo(safeBottom),
    );
  });

  // ---------- 接口文档字段契约 ----------
  // 后端字段名是混淆串，写错了不会报错、只会静默读到 null，这里锁住映射。

  test('首页 PROCESS_LIST 用订单卡自己的字段名解析', () {
    final home = HomeData.fromJson(const {
      'kneeing': [
        {
          'liquidators': 'PROCESS_LIST',
          'stabiliment': [
            {
              'resex': '39236372837263237',
              'tartarizing': 1,
              'current': 'Pera Agad(AA)',
              'unpaying': 'https://cdn.example.com/logo.png',
              'upbear': 'Already in default, please repay',
              'libertytown': '\u20b150,000',
              'cuboid': 'To repay',
              'satin': 2,
              'superidealness': 'ph://laya-credit/ios/IdeogrammicCothurni',
            },
          ],
        },
      ],
    });

    final order = home.orders.single;
    expect(order.productName, 'Pera Agad(AA)');
    expect(order.productLogo, 'https://cdn.example.com/logo.png');
    expect(order.displayAmount, '\u20b150,000');
    expect(order.status, HomeOrderCardStatus.toRepay);
  });

  test('首页 PRODUCT_LIST 用 Sixcylinder 混淆值解析推荐列表', () {
    final home = HomeData.fromJson(const {
      'kneeing': [
        {
          'liquidators': 'Sixcylinder',
          'stabiliment': [
            {
              'cussedly': 1,
              'heartfelt': 'Pera Pitaka(AA)',
              'bathtubs': 'https://cdn.example.com/logo.png',
              'wastefulnesses': '\u20b150,000',
              'octodentate': 'Maximum Loan Amount Upto',
              'mesometral': 'Interest Rate',
              'antibilious': '\u2264 0.5% Day',
              'lxe': 'Loan terms',
              'gundy': '121day',
              'islet': ['Low Interest Rates', '17 years old can be borrowed'],
              'holts': 1,
            },
          ],
        },
      ],
    });

    final card = home.productList.single;
    expect(card.id, '1');
    expect(card.productName, 'Pera Pitaka(AA)');
    expect(card.productLogo, 'https://cdn.example.com/logo.png');
    expect(card.amountRange, '\u20b150,000');
    expect(card.amountRangeDes, 'Maximum Loan Amount Upto');
    expect(card.loanRateDes, 'Interest Rate');
    expect(card.loanRate, '\u2264 0.5% Day');
    expect(card.termInfoText, 'Loan terms');
    expect(card.termInfo, '121day');
    expect(card.tips, ['Low Interest Rates', '17 years old can be borrowed']);
    expect(card.buttonStyle, HomeProductCardButtonStyle.highlighted);
    // 推荐列表不是产品大卡，不能顶掉头图的 LARGE_CARD。
    expect(home.product, isNull);
  });

  test('推荐卡按钮配色 holts 覆盖三态，缺省回落正常态', () {
    HomeProductCardButtonStyle styleOf(Object? holts) => HomeData.fromJson({
      'kneeing': [
        {
          'liquidators': 'PRODUCT_LIST',
          'stabiliment': [
            {'heartfelt': 'Pera Pitaka(AA)', 'holts': holts},
          ],
        },
      ],
    }).productList.single.buttonStyle;

    expect(styleOf(1), HomeProductCardButtonStyle.highlighted);
    expect(styleOf(0), HomeProductCardButtonStyle.normal);
    expect(styleOf(-1), HomeProductCardButtonStyle.grayed);
    expect(styleOf(null), HomeProductCardButtonStyle.normal);
  });

  test('首页 kneeing 用测试环境下发的混淆模块名解析', () {
    // 文档 `7.map.html` 写的是 BANNER / LARGE_CARD / AD_LIST，
    // 测试环境下发的却是混淆串，两种都要能解析。
    final home = HomeData.fromJson(const {
      'kneeing': [
        {
          'liquidators': 'MalvernePlucked',
          'stabiliment': [
            {
              'cussedly': '1',
              'avern': 'https://cdn.example.com/banner.png',
              'superidealness': 'ph://banner',
            },
          ],
        },
        {
          'liquidators': 'LupusesWheelrace',
          'stabiliment': [
            {
              'heartfelt': 'Pera Cash',
              'bathtubs': 'https://cdn.example.com/logo.png',
              'curitiba': 'Apply Now',
              'wastefulnesses': '\u20b160,000',
              'octodentate': 'Available up to',
              'gundy': '180 Days',
              'solomon': 'Loan terms',
              'antibilious': '\u2264 0.5% Day',
              'mesometral': 'Interest rate',
              'vesperal': 'Credit activation progress',
              'kailua': 0,
              'unobtrusiveness': [
                {
                  'upbear': 'Identity',
                  'beingless': '\u20b1 30,000',
                  'estamp': 1,
                },
                {'upbear': 'Living', 'beingless': '\u20b1 40,000', 'estamp': 0},
              ],
            },
          ],
        },
        {
          'liquidators': 'BelliferousOverfertilizing',
          'stabiliment': [
            {'upbear': '<span>2,000 pesos</span>'},
          ],
        },
      ],
    });

    expect(home.banners.first.imageUrl, 'https://cdn.example.com/banner.png');
    expect(home.product?.productName, 'Pera Cash');
    expect(home.product?.termInfo, '180 Days');
    expect(home.product?.steps.map((step) => step.title), [
      'Identity',
      'Living',
    ]);
    expect(home.product?.steps.first.selected, isTrue);
    expect(home.notices, hasLength(1));
  });

  test('加签覆盖的参数与实际下发的公共参数完全一致', () {
    final common = CommonParams.create(
      deviceId: 'device',
      market: 'market',
      appVersion: '1.0.0',
      deviceName: 'iPhone 16 Pro',
      osVersion: '18.2',
      advertisingId: 'device',
    );
    final signInput = CommonParams.signable(common, '/outsulk/connectedly');

    // 后端是拿收到的参数重算签名的：多签一个没下发的字段（曾经 gruelled
    // 只在签名里出现）会被判成 code 400。
    final signedKeys = signInput.keys.toSet()
      ..remove(ApiProtocol.signaturePath);
    expect(signedKeys, common.keys.toSet());
    expect(common.containsKey(ApiProtocol.clientType), isTrue);
    // stith 与签名本身不参与签名。
    expect(signInput.containsKey(ApiProtocol.obfuscation), isFalse);
    expect(signInput.containsKey(ApiProtocol.signature), isFalse);
  });

  test('banner 点击上报带的是文档字段 geheimrat', () async {
    final client = _RecordingClient();
    await AppRepository(client).recordBannerClick('1394');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.bannerClick);
    expect(params[ApiFields.bannerConfigId], '1394');
    expect(params.containsKey(ApiFields.obfuscateBannerClick), isTrue);
  });

  test('点击申请接口带产品 id、来源标识与固定的模块参数', () async {
    final client = _RecordingClient();
    await ProductRepository(client).applyProduct(productId: '7', apiRemind: 0);

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.productApply);
    expect(params[ApiFields.productId], '7');
    expect(params[ApiFields.apiRemind], '0');
    // 文档标注已弃用，但仍要固定下发。
    expect(params[ApiFields.applyModuleId], '1001');
    expect(params[ApiFields.applyPosition], '1000');
    expect(params[ApiFields.applySubModuleId], '1000');
    expect(params.containsKey(ApiFields.obfuscateApply1), isTrue);
    expect(params.containsKey(ApiFields.obfuscateApply2), isTrue);
  });

  test('产品详情解析 priapi 与 cretonne 下一步认证项', () {
    final detail = ProductDetail.fromJson({
      ApiFields.applyResultCode: 200,
      ApiFields.productDetail: {
        ApiFields.itemId: '7',
        ApiFields.productName: 'Pera Agad',
        ApiFields.detailOrderNo: 'ORDER-9',
        ApiFields.detailOrderId: 266561,
        ApiFields.amount: '1000',
        ApiFields.detailTerm: '91',
        ApiFields.detailTermType: '1',
      },
      ApiFields.detailNextStep: {
        ApiFields.detailTaskType: 'Bespattered',
        ApiFields.itemTitle: 'Informasi bank',
        ApiFields.jumpUrl: '',
        ApiFields.applyJumpType: 0,
      },
    });

    expect(detail.resultCode, 200);
    expect(detail.basicInfo.productId, '7');
    expect(detail.basicInfo.orderNo, 'ORDER-9');
    expect(detail.basicInfo.orderId, 266561);
    expect(detail.basicInfo.loanTerm, '91');
    expect(detail.basicInfo.termType, '1');
    expect(detail.nextStep.taskType, 'Bespattered');
    expect(detail.nextStep.title, 'Informasi bank');
  });

  test('准入结果解析 countercharged / superidealness 与跳转类型', () {
    final result = ProductApplyResult.fromJson({
      ApiFields.applyResultCode: 302,
      ApiFields.jumpUrl: 'ph://laya-credit/ios/IntervesicularSauder',
      ApiFields.applyJumpType: 0,
      ApiFields.applyMessage: 'success',
    });

    expect(result.statusCode, 302);
    expect(result.hasJump, isTrue);
    expect(result.isAdmitted, isFalse);
    expect(result.jumpType, 0);
  });

  testWidgets('已登录用户点额度大卡会发起点击申请', (tester) async {
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    // 点大卡的非按钮区域，走的是同一处 _openApply 逻辑。
    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(productRepository.applyCalls, [('1', 0)]);
  });

  testWidgets('准入失败时不继续拉产品详情', (tester) async {
    final productRepository = _StubProductRepository(
      applyResult: const ProductApplyResult(
        statusCode: 505,
        jumpUrl: '',
        jumpType: 0,
        message: 'Risk rejected',
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(productRepository.applyCalls, hasLength(1));
    expect(productRepository.detailCalls, 0);
    expect(find.text('Risk rejected'), findsOneWidget);
  });

  testWidgets('准入成功后拉产品详情并按下一步认证项提示', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-1'),
        nextStep: ProductNextStep(
          taskType: 'Bespattered',
          title: 'Informasi bank',
        ),
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(productRepository.applyCalls, hasLength(1));
    expect(productRepository.detailCalls, 1);
    expect(find.text('Please complete Informasi bank'), findsOneWidget);
  });
}
