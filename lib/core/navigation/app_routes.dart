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

  /// 全部路由（用于启动自检与埋点白名单）。
  static const List<String> all = [root, home, stats, mine, login];

  /// 路由名是否已注册。
  static bool isValid(String? route) => route != null && all.contains(route);
}
