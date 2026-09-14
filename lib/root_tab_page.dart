import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/navigation.dart';
import 'pages/home_page.dart';
import 'pages/mine_page.dart';
import 'pages/stats_page.dart';
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

class _RootTabPageState extends ConsumerState<RootTabPage> {
  int _currentIndex = 0;

  /// 防止连点 Tab 叠加打开多个登录页。
  bool _openingLogin = false;

  StreamSubscription<void>? _sessionExpirySubscription;

  /// 首页允许游客浏览，其余 Tab 需要登录。
  static bool _requiresLogin(int index) => index != 0;

  @override
  void initState() {
    super.initState();
    _sessionExpirySubscription = ref
        .read(sessionExpirySignalProvider)
        .events
        .listen((_) => _handleSessionExpired());
  }

  @override
  void dispose() {
    _sessionExpirySubscription?.cancel();
    super.dispose();
  }

  Future<void> _selectTab(int index) async {
    if (index == _currentIndex) return;

    if (_requiresLogin(index) && !ref.read(userSessionProvider).isLoggedIn) {
      final loggedIn = await _openLogin();
      if (!loggedIn || !mounted) return;
    }

    setState(() => _currentIndex = index);
  }

  /// token 过期：回到首页 Tab 并弹出登录页。
  /// 主动退出登录不会走这里，避免用户刚退出就被重新弹登录页。
  Future<void> _handleSessionExpired() async {
    if (!mounted) return;
    if (_currentIndex != 0) setState(() => _currentIndex = 0);
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
        setState(() => _currentIndex = 0);
      }
    });

    return Scaffold(
      // 底部导航只留出胶囊区域，其余底色与各 Tab 页面一致（设计稿 02-01 / 07-01）。
      backgroundColor: AppColors.surfaceMint,
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
