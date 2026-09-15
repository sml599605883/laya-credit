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
import 'package:laya_credit/data/models/personal_center_data.dart';
import 'package:laya_credit/data/repositories/app_repository.dart';
import 'package:laya_credit/theme/app_assets.dart';
import 'package:laya_credit/main.dart';
import 'package:laya_credit/pages/home_page.dart';
import 'package:laya_credit/pages/login_page.dart';
import 'package:laya_credit/providers/repository_provider.dart';
import 'package:laya_credit/providers/session_provider.dart';
import 'package:laya_credit/widgets/state_views.dart';
import 'package:laya_credit/widgets/tab_bar/app_tab_bar.dart';

/// 用桩仓库替掉真实网络请求，让页面测试可预期。
/// HttpClient 只作为占位传入，桩方法不会真的发请求。
class _StubAppRepository extends AppRepository {
  _StubAppRepository({this.home, this.personalCenter, this.failure})
    : super(_placeholderClient());

  final HomeData? home;
  final PersonalCenterData? personalCenter;
  final Object? failure;

  @override
  Future<ApiResponse<HomeData>> getHomePage() async {
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data:
          home ??
          const HomeData(banner: null, product: null, orders: [], notices: []),
    );
  }

  @override
  Future<ApiResponse<PersonalCenterData>> getPersonalCenter() async {
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data:
          personalCenter ??
          const PersonalCenterData(
            services: [],
            hasRedPoint: false,
            redPointId: '',
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
  Future<void> Function(ProviderContainer container)? setUp,
}) async {
  _usePhoneSurface(tester);
  const app = LayaCreditApp();

  // 只建一个容器：嵌套 UncontrolledProviderScope + ProviderScope 会让
  // override 落在子容器上，父容器里的 session 与仓库对不上，测试结论会失真。
  final container = ProviderContainer(
    overrides: [
      if (repository != null)
        appRepositoryProvider.overrideWith((ref) async => repository),
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
          banner: null,
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
          banner: null,
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
          banner: null,
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

  testWidgets('首页额度头图渲染后端下发的产品、额度、期限与申请入口', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banner: null,
          orders: [],
          notices: [],
          product: HomeProductCard(
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

  testWidgets('登录页两位都填了才放开提交，未勾选协议时给提示条', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '1234');
    await tester.pump();

    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit-button')),
    );
    expect(submit.onPressed, isNotNull);

    // 设计稿默认态协议就是勾上的。
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxChecked);

    // 取消勾选后提交：不发请求，只浮出设计稿里的提示条。
    await tester.tap(find.byKey(const Key('login-agreement-checkbox')));
    await tester.pump();
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxUnchecked);

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

    // 勾选协议只是提交的前置校验，不影响按钮可用状态。
    await tester.tap(find.byKey(const Key('login-agreement-checkbox')));
    await tester.pump();
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxChecked);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit-button')))
          .onPressed,
      isNotNull,
    );
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

  testWidgets('登录后个人中心展示手机号、服务入口与退出按钮', (tester) async {
    await _pumpApp(
      tester,
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
      repository: _StubAppRepository(
        personalCenter: const PersonalCenterData(
          services: [
            ServiceEntry(
              id: '15',
              title: 'Layanan Online',
              key: 'customer_service_center',
              iconUrl: '',
              linkUrl: '',
              jumpUrl: '',
              isH5: true,
            ),
          ],
          hasRedPoint: true,
          redPointId: '1394',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    expect(find.text('9171234567'), findsOneWidget);
    expect(find.text('To repay'), findsOneWidget);
    expect(find.text('Layanan Online'), findsOneWidget);
    expect(find.byKey(const Key('mine-logout-button')), findsOneWidget);
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

    expect(home.banner?.imageUrl, 'https://cdn.example.com/banner.png');
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
}
