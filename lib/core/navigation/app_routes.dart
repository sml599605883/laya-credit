/// 全局路由表。
///
/// 所有页面跳转都通过这里的常量进行，禁止在业务代码里写裸字符串路由名，
/// 否则拼写错误只会在运行时才暴露。
abstract final class AppRoutes {
  /// 根页面（底部 Tab 容器）。
  static const root = '/';

  /// 首页 Tab。
  static const home = '/home';

  /// 统计 Tab。
  static const stats = '/stats';

  /// 个人中心 Tab。
  static const mine = '/mine';

  /// 登录页。
  static const login = '/login';

  /// 证件选择页（认证流程第一步）。
  static const idVerification = '/id-verification';

  /// 证件上传页（认证流程第二步）。
  static const idUpload = '/id-upload';

  /// 证件信息确认页（认证流程第三步，识别结果核对）。
  static const idConfirm = '/id-confirm';

  /// 全部路由（用于启动自检与埋点白名单）。
  static const List<String> all = [
    root,
    home,
    stats,
    mine,
    login,
    idVerification,
    idUpload,
    idConfirm,
  ];

  /// 路由名是否已注册。
  static bool isValid(String? route) => route != null && all.contains(route);
}
