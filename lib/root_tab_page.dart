import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/navigation.dart';
import 'core/permissions/permission_coordinator.dart';
import 'data/models/app_dialog.dart';
import 'pages/home_page.dart';
import 'pages/mine_page.dart';
import 'pages/progress_page.dart';
import 'pages/widgets/app_marketing_popup.dart';
import 'pages/widgets/app_upgrade_popup.dart';
import 'providers/home_provider.dart';
import 'providers/popup_provider.dart';
import 'providers/session_provider.dart';
import 'theme/theme.dart';
import 'widgets/tab_bar/app_tab_bar.dart';

/// 底部 Tab 容器（对应路由 `AppRoutes.root`）。
///
/// Tab 切换用 [IndexedStack]：各 Tab 的 State 会被保留，切回来不会重新加载数据，
/// 也不会丢失滚动位置。代价是首帧会同时构建三个页面，
/// 后续如果某个 Tab 首屏很重，再改成按需构建。
class RootTabPage extends ConsumerStatefulWidget {
  const RootTabPage({super.key});

  @override
  ConsumerState<RootTabPage> createState() => _RootTabPageState();
}

class _RootTabPageState extends ConsumerState<RootTabPage>
    with WidgetsBindingObserver, RouteAware {
  int _currentIndex = 0;

  /// 防止连点 Tab 叠加打开多个登录页。
  bool _openingLogin = false;

  StreamSubscription<void>? _sessionExpirySubscription;

  /// 生命周期恢复刷新用：区分「从后台回来」与「首次 inactive→resumed」，
  /// 后者只认一次，避免权限弹窗 / 分享面板等瞬时 inactive 反复触发刷新。
  bool _wasInactive = false;
  bool _wasInBackground = false;
  bool _inactiveResumeRefreshConsumed = false;

  /// 定位授权弹窗刚关闭时的恢复事件要忽略：那一刻「立即申请」会自动继续，
  /// 再刷一次首页 / 弹窗接口既重复请求，弹窗还可能顶进认证流程里
  /// （对齐 dali_cash 的 `_ignoreLocationPermissionResume`）。
  bool _ignoreLocationPermissionResume = false;

  /// 路由返回后延迟到下一帧再刷新：账户列表 / 绑卡页提交成功时，返回根页
  /// 的下一拍会立刻进入新的订单 WebView。此时根页并未真正可见，不能多打一次
  /// 首页接口；等帧末确认根页仍在栈顶后再刷新。
  bool _returnRefreshScheduled = false;

  /// 首页允许游客浏览，其余 Tab 需要登录。
  static bool _requiresLogin(int index) => index != 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionExpirySubscription = ref
        .read(sessionExpirySignalProvider)
        .events
        .listen((_) => _handleSessionExpired());
    // 首帧就停在首页，对齐 dali_cash 的 onReady：拉一次首页弹窗（场景 1）。
    _requestTabPopup(_currentIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _sessionExpirySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _wasInactive = true;
      if (PermissionCoordinator.instance.isRequestingLocationPermission) {
        _ignoreLocationPermissionResume = true;
      }
      return;
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasInBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final resumedFromBackground = _wasInBackground;
    final firstInactiveResume = _wasInactive && !_inactiveResumeRefreshConsumed;
    _wasInactive = false;
    _wasInBackground = false;
    // 定位系统弹窗关闭：不刷新（真从后台回来时 resumedFromBackground 为 true，
    // 那种恢复仍照常刷新）。
    if (_ignoreLocationPermissionResume && !resumedFromBackground) {
      _ignoreLocationPermissionResume = false;
      return;
    }
    _ignoreLocationPermissionResume = false;
    if (!resumedFromBackground && !firstInactiveResume) return;
    if (!resumedFromBackground) _inactiveResumeRefreshConsumed = true;
    // 停在子页面（认证 / 活体等）时不刷，避免无谓请求。
    if (_isTopRoute) _refreshHomeData();
  }

  /// 从子页面（认证流程 / 产品详情等）返回根容器时刷新首页数据，
  /// 对齐 dali_cash 的 `onRouteChanged`。
  @override
  void didPopNext() => _scheduleRefreshAfterReturn();

  void _scheduleRefreshAfterReturn() {
    if (_returnRefreshScheduled) return;
    _returnRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _returnRefreshScheduled = false;
      if (!mounted || !_isTopRoute) return;
      _refreshHomeData();
    });
  }

  /// 本路由是否处于最上层。
  bool get _isTopRoute => ModalRoute.of(context)?.isCurrent ?? true;

  /// 刷新当前 Tab 的数据并请求该 Tab 的弹窗。
  ///
  /// 首页 Tab（0）与进度 Tab（1）共用同一份 `homeDataProvider`（进度卡来自
  /// 首页接口的 `PROCESS_LIST` 模块），所以这两个 Tab 可见时都要刷；
  /// 个人中心（2）是纯本地内容，不拉首页接口，只在可见时请求弹窗（场景 2）。
  void _refreshHomeData() {
    final index = _currentIndex;
    if (index == 0 || index == 1) {
      unawaited(ref.read(homeDataProvider.notifier).refresh());
    }
    _requestTabPopup(index);
  }

  /// 请求当前 Tab 对应的弹窗（`GET /outsulk/agatize`）。
  ///
  /// 首页场景 `1` / 个人中心场景 `2`，进度 Tab 不请求。请求失败不影响页面，
  /// 拿到弹窗后由 [appPopupProvider] 的监听统一展示，见 [AppPopupNotifier]。
  void _requestTabPopup(int index) {
    final scene = switch (index) {
      0 => AppPopupScene.home,
      2 => AppPopupScene.mine,
      _ => null,
    };
    if (scene == null) return;
    unawaited(ref.read(appPopupProvider.notifier).request(scene));
  }

  /// 按弹窗类型展示。当前已接入应用内升级与营销弹窗，其余类型先记日志。
  void _showPopup(AppDialog dialog) {
    // 在回调里直接弹窗可能撞上当前帧的构建，延后到帧末再弹。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (dialog.type) {
        case AppPopupType.appUpgrade:
          showAppUpgradePopup(context: context, dialog: dialog);
        case AppPopupType.marketing:
          showAppMarketingPopup(context: context, dialog: dialog);
        default:
          debugPrint('[Popup] 暂未接入的弹窗类型: ${dialog.type}');
      }
    });
  }

  /// 回落到首页 Tab 并刷新（退出登录 / token 过期）。
  ///
  /// 登录态变化后额度、订单都会变，这里必须重新拉一次，
  /// 对齐 dali_cash 的 `returnToHomeTab`。
  void _returnToHome() {
    if (_currentIndex != 0) setState(() => _currentIndex = 0);
    _refreshHomeData();
  }

  Future<void> _selectTab(int index) async {
    if (index == _currentIndex) return;

    if (_requiresLogin(index) && !ref.read(userSessionProvider).isLoggedIn) {
      final loggedIn = await _openLogin();
      if (!loggedIn || !mounted) return;
      // 从受保护 Tab 拉起登录时，登录页关闭后统一回首页；不要继续落到
      // 用户刚才点击的 Progress / 个人中心，避免不同入口登录后的落点不一致。
      _returnToHome();
      return;
    }

    setState(() => _currentIndex = index);
    // 切到首页 / 进度时刷新它们共用的数据源，对齐 dali_cash 的 `selectTab`。
    _refreshHomeData();
  }

  /// token 过期：回到首页 Tab 并弹出登录页。
  /// 主动退出登录不会走这里，避免用户刚退出就被重新弹登录页。
  Future<void> _handleSessionExpired() async {
    if (!mounted) return;
    _returnToHome();
    await _openLogin(clearSessionStack: true);
  }

  Future<bool> _openLogin({bool clearSessionStack = false}) async {
    if (_openingLogin) return false;
    _openingLogin = true;
    try {
      return await AppNavigator.toLogin(clearSessionStack: clearSessionStack);
    } finally {
      _openingLogin = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 退出登录后，当前停在不允许游客访问的 Tab 上时回落到首页。
    ref.listen(userSessionProvider, (previous, next) {
      if (previous?.isLoggedIn == true &&
          !next.isLoggedIn &&
          _requiresLogin(_currentIndex)) {
        _returnToHome();
      }
    });

    // 弹窗请求结果 -> 展示弹窗：由状态变化驱动，不在请求回调里直接用 context。
    ref.listen(appPopupProvider, (previous, next) {
      if (next == null || !next.hasPopup) return;
      _showPopup(next);
    });

    return Scaffold(
      // 底色与各 Tab 页面一致（设计稿 02-01 / 07-01）。
      backgroundColor: AppColors.surfaceMint,
      // 底部导航是浮层：页面内容铺到屏幕底部、从胶囊下方穿过，
      // 各页自己用 `AppTabBar.overlapHeight` 预留底部内边距。
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(isActive: _currentIndex == 0),
          const ProgressPage(),
          MinePage(isActive: _currentIndex == 2),
        ],
      ),
      bottomNavigationBar: AppTabBar(
        currentIndex: _currentIndex,
        onSelected: _selectTab,
      ),
    );
  }
}
