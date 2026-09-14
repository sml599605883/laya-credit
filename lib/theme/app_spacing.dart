/// 设计令牌：间距。
///
/// 蓝湖稿以 375pt 宽为基准，所有间距必须是 8pt 的整数倍。
/// 这里只放「语义间距」，不要在业务代码里写裸数字。
abstract final class AppSpacing {
  /// 8pt —— 元素内部紧凑间距。
  static const double xs = 8;

  /// 16pt —— 常规元素间距、页面左右安全边距。
  static const double sm = 16;

  /// 24pt —— 模块之间的间距。
  static const double md = 24;

  /// 32pt —— 大模块之间的间距。
  static const double lg = 32;

  /// 40pt —— 页面级的上下留白。
  static const double xl = 40;

  /// 页面左右统一边距。
  static const double pageHorizontal = 16;

  /// 圆角。
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
}
