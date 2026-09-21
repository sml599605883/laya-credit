import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/navigation.dart';
import 'pages/home_page.dart';
import 'pages/mine_page.dart';
import 'pages/stats_page.dart';
import 'providers/home_provider.dart';
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
      return;
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasInBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final resumedFromBackground = _wasInBackground;
    final firstInactiveResume =
        _wasInactive && !_inactiveResumeRefreshConsumed;
    _wasInactive = false;
    _wasInBackground = false;
    if (!resumedFromBackground && !firstInactiveResume) return;
    if (!resumedFromBackground) _inactiveResumeRefreshConsumed = true;
    // 停在子页面（认证 / 活体等）时不刷，避免无谓请求。
    if (_isTopRoute) _refreshHome();
  }

  /// 从子页面（认证流程 / 产品详情等）返回根容器时刷新首页，
  /// 对齐 dali_cash 的 `onRouteChanged`。
  @override
  void didPopNext() => _refreshHome();

  /// 本路由是否处于最上层。
  bool get _isTopRoute => ModalRoute.of(context)?.isCurrent ?? true;

  /// 仅在首页 Tab 可见时刷新。
  void _refreshHome() {
    if (_currentIndex != 0) return;
    unawaited(ref.read(homeDataProvider.notifier).refresh());
  }

  /// 回落到首页 Tab 并刷新（退出登录 / token 过期）。
  ///
  /// 登录态变化后额度、订单都会变，这里必须重新拉一次，
  /// 对齐 dali_cash 的 `returnToHomeTab`。
  void _returnToHome() {
    if (_currentIndex != 0) setState(() => _currentIndex = 0);
    _refreshHome();
  }

  Future<void> _selectTab(int index) async {
    if (index == _currentIndex) return;

    if (_requiresLogin(index) && !ref.read(userSessionProvider).isLoggedIn) {
      final loggedIn = await _openLogin();
      if (!loggedIn || !mounted) return;
    }

    setState(() => _currentIndex = index);
    // 切回首页时刷新，对齐 dali_cash 的 `selectTab`。
    _refreshHome();
  }

  /// token 过期：回到首页 Tab 并弹出登录页。
  /// 主动退出登录不会走这里，避免用户刚退出就被重新弹登录页。
  Future<void> _handleSessionExpired() async {
    if (!mounted) return;
    _returnToHome();
    await _openLogin();
  }

  Future<bool> _openLogin() async {
    if (_openingLogin) return false;
    _openingLogin = true;
    try {
      return await AppNavigator.toLogin();
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
          StatsPage(isActive: _currentIndex == 1),
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
