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

  // 通用
  static const chevronRight = 'assets/common/chevron_right.png';
}
