import 'package:flutter/material.dart';

/// 设计令牌：颜色。
///
/// 数值取自蓝湖导出切图（`assets/`）的取色结果，代码中禁止再出现硬编码 Hex，
/// 一律引用这里的常量。新增颜色请按「用途」命名，而不是按色值命名。
abstract final class AppColors {
  /// 品牌主色（深墨绿--青绿渐变卡片的中间色）。
  static const primary = Color(0xFF195D42);

  /// 页面浅色底（个人中心、Tab 栏底色）。
  static const surfaceMint = Color(0xFFECFADC);

  /// 深色底（首页往上滚动区域）。
  static const surfaceDark = Color(0xFF191F1F);

  /// 深色高光（首页顶部金色光晕）。
  static const darkGlow = Color(0xFF59542A);

  /// 抽屉/纯白底。
  static const surface = Color(0xFFFFFFFF);

  /// 主文字色。
  static const textPrimary = Color(0xFF334141);

  /// 次级文字色。
  static const textSecondary = Color(0xFF606060);

  /// 提示性文字/图标（箭头）。
  static const textHint = Color(0xFF989898);

  /// 深色图标（浅色底上的选中态）。
  static const iconDark = Color(0xFF101010);

  /// 底部导航悬浮胶囊底色。
  static const tabBarPill = Color(0xFF131313);

  /// 底部导航未选中项的圆形托底色。
  static const tabItemTrack = Color(0xFF2A2A2A);

  /// 首页运营位渐变（左 -> 右）。
  static const bannerStart = Color(0xFFEA3B26);
  static const bannerEnd = Color(0xFFDA202D);

  /// 订单卡片渐变（左 -> 右）。
  static const orderCardStart = Color(0xFF0E494F);
  static const orderCardEnd = Color(0xFF237035);

  // ---------- 首页额度头图（蓝湖稿 02-01 - 首页-默认） ----------

  /// 可用额度数字的渐变色终点（渐变由 `white` 向下过渡到该金色）。
  static const amountGradientEnd = Color(0xFFFFD200);

  /// 额度数字上方的「Available up to」提示色。
  static const heroLabel = Color(0xFFFFE04C);

  /// 额度条（头像凹槽）描边色。
  static const creditBarBorder = Color(0xFFF0ECD8);

  /// 额度卡顶部渐变条的起始色（由深转白，做出凹槽感）。
  static const cardStripStart = Color(0xFF181E1E);

  /// 额度卡内主数值文字色。
  static const cardValue = Color(0xFF12180A);

  /// 额度卡内字段标签文字色。
  static const cardLabel = Color(0xFFAFAFAF);

  /// 额度卡内分隔线。
  static const cardDivider = Color(0xFFEEEEEE);

  /// 主行动按钮（Apply Now）底色。
  static const actionLime = Color(0xFFC3E760);

  /// 额度卡底部橙色提示文案。
  static const hintOrange = Color(0xFFFF660E);

  // ---------- 首页授信进度卡（蓝湖稿 02-02 - 首页-有进度） ----------

  /// 进度条底槽色。
  static const creditProgressTrack = Color(0xFFFFFFFF);

  /// 已完成进度条的填充色。
  static const creditProgressFill = Color(0xFFFADD25);

  /// 当前阶段的金额文字色。
  static const creditProgressAmountCurrent = Color(0xFFFE295C);

  /// 未到达阶段的金额文字色。
  static const creditProgressAmount = Color(0xFF333333);

  // ---------- 首页推荐列表（蓝湖稿 `02-01` 的 `group_3`，后端模块 PRODUCT_LIST） ----------

  /// 推荐卡的深色外框底色（设计稿 `list-items_1` rgba(18,24,10)）。
  static const productCardBackground = Color(0xFF12180A);

  /// 推荐卡内产品名文字色（设计稿 `text_16`）。
  static const productCardTitle = Color(0xFF333333);

  /// 推荐卡内「利率 / 期限」小表底底色（设计稿 `box_11` rgba(247,247,247)）。
  static const productCardMetricBackground = Color(0xFFF7F7F7);

  /// 推荐卡底部提示文案色（设计稿 `text_24`）。
  static const productCardTip = Color(0xFFFE295C);

  // ---------- 证件选择页（蓝湖稿 `03 - 认证流程模块`） ----------

  /// 页面底色（设计稿 `page` rgba(245,245,245)）。
  static const idVerifyBackground = Color(0xFFF5F5F5);

  /// 证件类型行文案色（设计稿 `text_7` 等 rgba(38,65,7)）。
  static const idVerifyRowText = Color(0xFF264107);

  /// 证件类型行之间的虚线分隔色（设计稿「路径 4」rgba(189,189,162)）。
  static const idVerifyDashedDivider = Color(0xFFBDBDA2);

  /// 卡片标题与证件列表之间的 1pt 分隔线（设计稿 `box_1` / `section_5` rgba(238,238,238)）。
  static const idVerifyDivider = Color(0xFFEEEEEE);

  /// 证件上传页头图上的引导段落文案色（设计稿 `text_4` rgba(12,14,2)）。
  static const idVerifyHeaderText = Color(0xFF0C0E02);

  /// 证件上传页 `Upload` 主按钮的文案色（设计稿 `text_6` rgba(19,19,19)）。
  static const idVerifyUploadButtonText = Color(0xFF131313);

  // ---------- 证件信息确认页（蓝湖稿 `03-01 - 身份认证-上传成功`） ----------

  /// 识别信息行的底色（设计稿 `text-wrapper_4` rgba(248,248,248)）。
  static const idVerifyFieldBackground = Color(0xFFF8F8F8);

  /// 识别信息行的字段名文字色（设计稿 `text_6` rgba(153,153,153)）。
  static const idVerifyFieldLabel = Color(0xFF999999);

  /// 识别信息行的字段值文字色（设计稿 `text_7` rgba(51,51,51)）。
  static const idVerifyFieldValue = Color(0xFF333333);

  // ---------- 生日选择面板（蓝湖稿 `03-02 - 个人信息-日期选择`） ----------

  /// 面板遮罩（设计稿 `page` 底色 rgba(96,96,96,1)，按 60% 透明压暗底页）。
  static const idVerifyPickerBarrier = Color(0x99606060);

  /// 滚轮选中行两侧一格的文字色（设计稿 `text_5` rgba(102,102,102)）。
  static const idVerifyPickerTextNear = Color(0xFF666666);

  /// 滚轮选中行的文字色（设计稿 `text_8` rgba(13,27,23)）。
  static const idVerifyPickerTextSelected = Color(0xFF0D1B17);

  // ---------- 个人中心（蓝湖稿 `07-01 - 个人中心`） ----------

  /// 个人中心顶部深色头图底色（设计稿 `box_1`）。
  static const mineHeader = Color(0xFF0B2928);

  /// 标题文字（个人中心的 Customer Service / About Us、证件选择页的分组标题与
  /// 导航标题，设计稿 `text_4` / `text_5` / `text_3`）。
  static const sectionTitle = Color(0xFF333333);

  /// 列表项主文案（设计稿 `text-group_3/4/6`）。
  static const listItemTitle = Color(0xFF080B15);

  /// 列表项右侧说明文案（官网域名 / 版本号，设计稿 `text-group_5` / `text_6`）。
  static const listItemValue = Color(0xFF5A5A5A);

  /// 「Account」底部操作面板的分隔线（设计稿 `07-01 - 个人中心-退出`）。
  static const actionSheetDivider = Color(0xFFF1F1F2);

  /// 「Account」底部操作面板里分组之间的间隔带。
  static const actionSheetGap = Color(0xFFF4F4F4);

  /// 操作面板主行动文案（Log out / Delete Account）。
  static const actionSheetText = Color(0xFF031A03);

  /// 操作面板次要行动文案（Quit）。
  static const actionSheetTextSecondary = Color(0xFF5A5A5A);

  // ---------- 登录页（蓝湖稿 `01-02 - 登录`） ----------

  /// 卡片内字段标题文字色（Please enter mobile number / Verify with SMS Code）。
  static const loginLabel = Color(0xFF031A03);

  /// 输入框描边色。
  static const fieldBorder = Color(0xFFEBF0F7);

  /// 输入框占位文字色。
  static const fieldHint = Color(0xFFCCCCCC);

  /// 输入框正文色（含 `+63` 前缀）。
  static const fieldText = Color(0xFF333333);

  /// 协议文案颜色。
  static const agreementText = Color(0xFF666666);

  /// 协议里的可点击链接色（Privacy Policy）。
  static const agreementLink = Color(0xFF131313);

  /// 未勾选协议时的提示条底色（设计稿 `形状结合` rgba(0,0,0,0.7)）。
  static const warningBar = Color(0xB3000000);

  /// 弹窗遮罩。
  static const dialogBarrier = Color(0x73000000);

  /// 分割线。
  static const divider = Color(0xFFE6E6E6);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
}
