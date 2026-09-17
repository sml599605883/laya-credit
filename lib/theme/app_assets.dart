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

  /// 推荐列表（蓝湖稿 `02-01` 的 `group_3`）右侧的整块「Apply Now」按钮，96x130。
  ///
  /// 弧形卡身 + 文案都烘焙在切图里，按后端 `holts`（1 高亮 / 0 正常 / -1 置灰）三态选图：
  /// 柠檬绿 / 品牌红 / 灰，对应设计稿从上到下的三张卡。
  static const homeApplyNowHighlight = 'assets/home/apply_now_highlight.png';
  static const homeApplyNowNormal = 'assets/home/apply_now_normal.png';
  static const homeApplyNowDisabled = 'assets/home/apply_now_disabled.png';

  // 个人中心（蓝湖稿 `07-01 - 个人中心`）
  /// 顶栏头像（设计稿 `label_1`，48x48）。圆角 8 与 1pt 白描边由代码补。
  static const mineAvatar = 'assets/mine/mine_avatar.png';

  /// 订单入口整卡底图（设计稿 `section_2`，319x95）：
  /// 圆角 12/12/0/0 + `rgba(13,72,80)` → `rgba(36,113,52)` 的横向渐变都在这张切图里。
  static const mineOrderCard = 'assets/mine/mine_order_card.png';

  /// 订单入口卡片底部的薄荷色「肩线」（设计稿 `image_2`，375x28）：
  /// 薄荷色斜切块 + 卡片背后那层 `rgba(51,65,65)` 深色衬底都在这一张切图里。
  /// 顶边被订单卡压住 16pt，只露出卡片下方 12pt。
  static const mineOrderCardShoulder = 'assets/mine/order_card_shoulder.png';

  /// 订单入口图标（设计稿 `label_3`，35x35，纯白，直接压在渐变卡上）。
  static const orderAll = 'assets/mine/order_all.png';
  static const orderOutstanding = 'assets/mine/order_outstanding.png';
  static const orderOverdue = 'assets/mine/order_overdue.png';
  static const orderSettled = 'assets/mine/order_settled.png';

  /// 服务入口图标（设计稿 20x20；颜色是切图自带的 `rgba(102,102,102)`，不要再着色）。
  static const serviceCustomer = 'assets/mine/service_customer.png';
  static const serviceWebsite = 'assets/mine/service_website.png';
  static const serviceAppVersion = 'assets/mine/service_app_version.png';
  static const servicePrivacy = 'assets/mine/service_privacy.png';
  static const serviceAccount = 'assets/mine/service_account.png';

  // 底部导航
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
