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

  /// 认证流程相关的路由集合。
  ///
  /// 进入下一个认证项（活体 / 个人信息 / 工作 / 联系人 / 绑卡）时会清掉这些页面，
  /// 避免认证页在返回栈里层层堆叠。新增认证页时记得补进来。
  static const Set<String> _certificationRoutes = {
    AppRoutes.idVerification,
    AppRoutes.idUpload,
    AppRoutes.idConfirm,
    AppRoutes.faceVerification,
    AppRoutes.personalInfo,
    AppRoutes.workInfo,
    AppRoutes.emergencyContact,
  };

  /// 压栈到顶层认证页，同时清掉返回栈里已有的认证页。
  ///
  /// 证件选择 → 上传 → 确认是同一认证项的子步骤，用普通 [push] 堆叠；
  /// 进入下一个认证项时用本方法，用户返回会直接回到入口页，
  /// 而不是上一个认证项的页面（对齐 peso_shield 的顶层认证机制）。
  static Future<T?> pushTopLevelCertification<T>(
    String route, {
    Object? arguments,
  }) {
    _warn(route);
    return _navigator!.pushNamedAndRemoveUntil<T>(route, (pageRoute) {
      final name = pageRoute.settings.name;
      // 保留非认证流程的页面（首页 / 登录等）。
      return name != null &&
          name.isNotEmpty &&
          !_certificationRoutes.contains(name);
    }, arguments: arguments);
  }

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
