import 'package:flutter/material.dart';

import '../config/api_environment.dart';
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

  /// 借款申请 / 认证流程相关的路由集合。
  ///
  /// 进入下一个认证项（活体 / 个人信息 / 工作 / 联系人 / 绑卡）或跳 H5 时会清掉
  /// 这些页面，避免认证页 / 借款确认页在返回栈里层层堆叠。新增认证页时记得补进来。
  ///
  /// `bindCard` 与 `loanConfirm` 是本流程的最后两屏：绑卡页提交成功后会由
  /// [ProductApplicationFlow] 重新进借款确认页，把它们放进集合里可以顺带清掉
  /// 上一张绑卡页 / 借款确认页，不会出现「确认页叠确认页」。
  static const Set<String> _certificationRoutes = {
    AppRoutes.idVerification,
    AppRoutes.idUpload,
    AppRoutes.idConfirm,
    AppRoutes.faceVerification,
    AppRoutes.personalInfo,
    AppRoutes.workInfo,
    AppRoutes.emergencyContact,
    AppRoutes.bindCard,
    AppRoutes.loanConfirm,
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

  /// 打开通用 H5 页。地址必须是 http/https；非法地址返回 null 并打日志。
  ///
  /// 与进入认证流程一致，会清掉返回栈里已有的认证页：用户从 H5 返回时
  /// 直接回到入口页，而不是上一个半完成的认证页。
  static Future<T?>? toWebView<T extends Object?>({
    required String url,
    String? title,
  }) {
    final uri = webViewUri(url);
    if (uri == null) {
      debugPrint('[AppNavigator] 无效的 WebView 地址: $url');
      return null;
    }
    _warn(AppRoutes.webView);
    return _navigator!.pushNamedAndRemoveUntil<T>(AppRoutes.webView, (
      pageRoute,
    ) {
      final name = pageRoute.settings.name;
      // 保留非认证流程的页面（首页 / 登录等）。
      return name != null &&
          name.isNotEmpty &&
          !_certificationRoutes.contains(name);
    }, arguments: WebViewPageArguments(url: uri.toString(), title: title));
  }

  /// 校验并规范化 H5 地址：仅放行带 host 的 http/https。
  static Uri? webViewUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  /// 用 H5 站点根地址 + 相对路径打开 WebView。
  ///
  /// TODO(混淆串): H5 路由路径待接口文档下发后替换（dali 用 `/#/Turbocharger` 等）。
  static const privacyAgreementPath = '/#/PrivacyAgreement';
  static const customerServicePath = '/#/CustomerService';

  static Future<T?>? toWebPath<T extends Object?>({
    required String path,
    String? title,
  }) {
    final base = Uri.tryParse(ApiEnvironment.h5Base);
    if (base == null || base.host.isEmpty) {
      debugPrint('[AppNavigator] 无效的 H5 站点地址: ${ApiEnvironment.h5Base}');
      return null;
    }
    return toWebView<T>(
      url: base.resolve(path.trim()).toString(),
      title: title,
    );
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
