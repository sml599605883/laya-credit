import 'package:flutter/material.dart';

import 'app_route_generator.dart';
import 'app_routes.dart';

/// 全局导航入口。
///
/// 之所以用 [navigatorKey] 而不是各页面自己的 `Navigator.of(context)`：
/// 支付回调、推送、会话过期这些场景没有页面 context，但仍然需要跳转。
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get _navigator => navigatorKey.currentState;

  static BuildContext? get _context => navigatorKey.currentContext;

  static void _warn(String route) {
    if (!AppRoutes.isValid(route)) {
      debugPrint('[AppNavigator] 未注册的路由名: $route');
    }
  }

  /// 压栈到指定路由。
  static Future<T?> push<T>(String route, {Object? arguments}) {
    _warn(route);
    return _navigator!.pushNamed<T>(route, arguments: arguments);
  }

  /// 替换当前页面。
  static Future<T?> replace<T>(String route, {Object? arguments}) {
    _warn(route);
    return _navigator!.pushReplacementNamed<T, dynamic>(
      route,
      arguments: arguments,
    );
  }

  /// 清空路由栈后跳转（登录成功、退出登录等场景）。
  static Future<T?> resetTo<T>(String route, {Object? arguments}) {
    _warn(route);
    return _navigator!.pushNamedAndRemoveUntil<T>(
      route,
      (_) => false,
      arguments: arguments,
    );
  }

  /// 返回上一页；无可返回页面时不做事。
  static void pop<T>([T? result]) {
    final navigator = _navigator;
    if (navigator == null || !navigator.canPop()) return;
    navigator.pop<T>(result);
  }

  /// 返回到根页面。
  static void popToRoot() {
    _navigator?.popUntil((route) => route.isFirst);
  }

  static bool canPop() => _navigator?.canPop() ?? false;

  // ==================== 便捷方法 ====================

  /// 打开登录页，返回是否登录成功。
  static Future<bool> toLogin({Future<void> Function()? onLoginSuccess}) async {
    final result = await push<bool>(
      AppRoutes.login,
      arguments: LoginPageArguments(onLoginSuccess: onLoginSuccess),
    );
    return result ?? false;
  }

  /// 显示对话框（无需页面 context）。
  static Future<T?> showDialogWidget<T>({
    required Widget dialog,
    bool barrierDismissible = true,
  }) {
    final context = _context;
    if (context == null) return Future<T?>.value();
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => dialog,
    );
  }

  /// 显示底部弹窗（无需页面 context）。
  static Future<T?> showBottomSheetWidget<T>({
    required Widget sheet,
    bool isDismissible = true,
  }) {
    final context = _context;
    if (context == null) return Future<T?>.value();
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      builder: (_) => sheet,
    );
  }
}
