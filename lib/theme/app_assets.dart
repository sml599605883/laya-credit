/// 设计令牌：切图资源。
///
/// 路径对应 `pubspec.yaml` 中注册的 `assets/` 子目录。
abstract final class AppAssets {
  // 首页
  static const homeBackground = 'assets/home/home_background.png';
  static const homeHeaderGlow = 'assets/home/home_header_glow.png';
  static const homeMessage = 'assets/home/home_message.png';
  static const homeBanner = 'assets/home/home_banner.png';
  static const homeMoneyBag = 'assets/home/home_money_bag.png';
  static const homeProgressEmpty = 'assets/home/home_progress_empty.png';

  /// 授信进度卡整卡底图（蓝湖稿 02-02）：白描边 / 深色标题条 / 左侧金币 /
  /// 金色光晕 / 标题文字 / 柠檬绿卡身都在这一张合并位图里。
  static const homeProgressCard = 'assets/home/home_progress_card.png';

  /// 授信进度卡：进度槽上的阶段金币（已到达阶段用原图，未到达阶段去色）。
  static const homeProgressCoin = 'assets/home/home_progress_coin.png';

  // 个人中心
  static const mineMessage = 'assets/mine/mine_message.png';
  static const mineAvatar = 'assets/mine/mine_avatar.png';
  static const mineOrderCard = 'assets/mine/mine_order_card.png';
  static const orderAll = 'assets/mine/order_all.png';
  static const orderOutstanding = 'assets/mine/order_outstanding.png';
  static const orderSettled = 'assets/mine/order_settled.png';
  static const serviceCustomer = 'assets/mine/service_customer.png';
  static const serviceAbout = 'assets/mine/service_about.png';
  static const servicePrivacy = 'assets/mine/service_privacy.png';
  static const serviceHelp = 'assets/mine/service_help.png';
  static const serviceSettings = 'assets/mine/service_settings.png';

  // 底部导航
  static const tabBarBackground = 'assets/navigation/tab_bar_background.png';
  static const tabHomeActive = 'assets/navigation/tab_home_active.png';
  static const tabHomeInactive = 'assets/navigation/tab_home_inactive.png';
  static const tabStatsActive = 'assets/navigation/tab_stats_active.png';
  static const tabStatsInactive = 'assets/navigation/tab_stats_inactive.png';
  static const tabMineActive = 'assets/navigation/tab_mine_active.png';
  static const tabMineInactive = 'assets/navigation/tab_mine_inactive.png';

  // 登录（蓝湖稿 `01-02 - 登录`）
  /// 整页深色底 + 金色光晕（设计稿「位图 + 编组 2蒙版」，375x812 通栏）。
  static const loginBackground = 'assets/login/login_background.png';

  /// 顶部产品 Logo（设计稿「矩形」，48x48，圆角与白描边已含在切图里）。
  static const loginLogo = 'assets/login/login_logo.png';

  /// 表单卡底图（设计稿「编组 8」，339x333）：半透明玻璃层 + 白色卡身，
  /// 白卡相对底图内缩 10pt，所以卡内 padding 按 22/21/21/22 摆放即可。
  static const loginCard = 'assets/login/login_card.png';

  /// 底部运营 Banner（设计稿「编组 4备份 2」，343x120，文案已含在切图里）。
  static const loginBanner = 'assets/login/login_banner.png';

  /// 协议勾选框：已勾选（柠檬绿底 + 深色对勾）。
  static const loginCheckboxChecked = 'assets/login/login_checkbox_checked.png';

  /// 协议勾选框：未勾选（灰色圆环）。
  static const loginCheckboxUnchecked =
      'assets/login/login_checkbox_unchecked.png';

  // 通用
  static const chevronRight = 'assets/common/chevron_right.png';
}
