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
  /// 取值来自蓝湖稿标注：2（产品图标）/ 4（额度条）/ 8 / 12（运营位）/
  /// 16 / 20（胶囊按钮）/ 24。
  static const double radiusXxs = 2;
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusBanner = 12;
  static const double radiusMd = 16;
  static const double radiusPill = 20;
  static const double radiusLg = 24;

  /// 6pt —— 登录页未勾选协议提示条的圆角
  /// （蓝湖稿 `01-02 - 登录-已输入-勾选` 的「形状结合」实测）。
  static const double radiusToast = 6;
}
