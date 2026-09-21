import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_environment.dart';
import '../core/navigation/app_deep_link.dart';
import '../core/navigation/app_navigator.dart';
import '../core/ui/toast_helper.dart';
import '../providers/login_provider.dart';
import '../providers/network_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/tab_bar/app_tab_bar.dart';
import 'widgets/account_retention_dialog.dart';

/// 「Customer Service」分组标题（设计稿 `text_4`）。
const _customerServiceTitle = 'Customer Service';

/// 「Customer Service」分组里的唯一入口（设计稿 `box_3`，页面右箭头跳客服中心）。
const _customerServiceEntry = 'Smart customer service';

/// 「About Us」分组标题（设计稿 `text_5`）。
const _aboutUsTitle = 'About Us';

/// 个人中心（蓝湖稿 `07-01 - 个人中心`）。
///
/// 页面分两段，与设计稿一一对应：
/// 1. 深色头图（`box_1`）：标题 / 头像 + 脱敏手机号 / 订单入口渐变卡
///    （`section_2`），卡片底部压一张薄荷色斜切「肩线」切图（`image_2`）
///    过渡到内容区。
/// 2. 浅色内容区（`block_2`）：Customer Service 与 About Us 两组入口。
///    卡片之外的页面底色是 `rgba(236, 250, 220, 1)`。
///
/// 页面内容全部是客户端固定的（文案与顺序来自设计稿），不请求接口：
/// 手机号取本地登录态，`APP Version` 取安装包版本。
class MinePage extends ConsumerWidget {
  const MinePage({super.key, this.isActive = true});

  /// 是否是当前选中的 Tab。
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = AppLayout.of(context);
    final session = ref.watch(userSessionProvider);

    return Scaffold(
      // 设计稿 page 底色 `rgba(236, 250, 220, 1)`。
      backgroundColor: AppColors.surfaceMint,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // 顶部深色头图要通栏，页面左右边距交给内容块自己控制；
        // 悬浮导航是浮层，让出它的高度，最后一条内容才能滚到胶囊上方。
        padding: EdgeInsets.only(bottom: AppTabBar.overlapHeight(context)),
        children: [
          _MineHeader(
            layout: layout,
            phone: session.phone,
            isLoggedIn: session.isLoggedIn,
          ),
          Padding(
            // 设计稿 `block_2`：`padding: 12px 16px 10px 16px`。
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              top: 12,
              right: AppSpacing.pageHorizontal,
              bottom: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._customerServiceSection(layout),
                _SectionTitle(layout: layout, text: _aboutUsTitle),
                SizedBox(height: layout.px(17)),
                _AboutUsCard(layout: layout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Customer Service 分组。
  ///
  /// 设计稿 `box_3` 里只有一行 `Smart customer service`，内容是固定的，
  /// 不依赖后端下发（产品确认个人中心不需要请求接口）。
  List<Widget> _customerServiceSection(AppLayout layout) {
    return [
      _SectionTitle(layout: layout, text: _customerServiceTitle),
      SizedBox(height: layout.px(12)),
      _Card(
        layout: layout,
        child: _EntryRow(
          layout: layout,
          leading: Image.asset(
            AppAssets.serviceCustomer,
            width: layout.px(_EntryRow.iconSize),
            height: layout.px(_EntryRow.iconSize),
          ),
          title: _customerServiceEntry,
          trailing: _Chevron(layout: layout),
          onTap: () => AppNavigator.toWebPath<void>(
            path: AppNavigator.customerServicePath,
            title: _customerServiceEntry,
          ),
        ),
      ),
      SizedBox(height: layout.px(16)),
    ];
  }
}

/// 手机号脱敏（设计稿 `962 **** 1300`）：只保留前 3 位与后 4 位。
String _maskPhone(String phone) {
  final value = phone.trim();
  if (value.length < 8) return value;
  return '${value.substring(0, 3)} **** ${value.substring(value.length - 4)}';
}

/// 顶部深色头图（设计稿 `box_1` + `image_2`）。
class _MineHeader extends StatelessWidget {
  const _MineHeader({
    required this.layout,
    required this.phone,
    required this.isLoggedIn,
  });

  final AppLayout layout;
  final String? phone;
  final bool isLoggedIn;

  /// 设计稿 375pt 基准下的标题行高（`text_9`：`line-height: 24px`）。
  static const _titleHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    // 设计稿状态栏高 44pt，真机上按实际安全区高度平移整块内容。
    final statusInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.mineHeader,
      child: Column(
        children: [
          SizedBox(height: statusInset),
          // 设计稿 `text_9`：`margin-top: 21px`，去掉状态栏内部那 17pt 后留 10pt。
          SizedBox(height: layout.px(10)),
          Text(
            'Mine',
            style: TextStyle(
              color: AppColors.white,
              fontSize: layout.px(17),
              fontWeight: FontWeight.w600,
              height: _titleHeight / 17,
            ),
          ),
          // 设计稿 `image-text_7`：`margin-top: 26px`。
          SizedBox(height: layout.px(26)),
          _ProfileRow(layout: layout, phone: phone, isLoggedIn: isLoggedIn),
          // 设计稿：头像行到订单卡 `margin-top: 16px`。
          SizedBox(height: layout.px(16)),
          _OrderCard(layout: layout),
        ],
      ),
    );
  }
}

/// 头像 + 手机号（设计稿 `image-text_7`：左右 23/146，整体宽 206）。
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.layout,
    required this.phone,
    required this.isLoggedIn,
  });

  final AppLayout layout;
  final String? phone;
  final bool isLoggedIn;

  /// 设计稿 `label_1`：48x48，圆角 8，1pt 白描边。
  static const _avatarSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final phone = this.phone;
    final display = isLoggedIn && phone != null && phone.isNotEmpty
        ? _maskPhone(phone)
        : 'Log in to continue';

    return Padding(
      padding: layout.edgeInsets(left: 23, right: 23),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: layout.radius(AppSpacing.radiusSm),
            child: Container(
              width: layout.px(_avatarSize),
              height: layout.px(_avatarSize),
              decoration: BoxDecoration(
                borderRadius: layout.radius(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.white, width: layout.px(1)),
              ),
              child: Image.asset(
                AppAssets.mineAvatar,
                fit: BoxFit.cover,
                // 切图是深色剪影，压在深色头图上必须反白才看得见。
                color: AppColors.white,
              ),
            ),
          ),
          SizedBox(width: layout.px(14)),
          Flexible(
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.white,
                fontSize: layout.px(24),
                fontWeight: FontWeight.w700,
                // 设计稿 `text-group_1`：`font-size: 24px; line-height: 29px`。
                height: 29 / 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 订单入口卡片（设计稿 `section_2`）。
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.layout});

  final AppLayout layout;

  /// 设计稿 `section_2`：宽 319、高 95，页面左右各留 28。
  static const _designInset = 28.0;
  static const _designHeight = 95.0;

  /// 设计稿 `image_2`（375x28）：订单卡底部的薄荷色「肩线」切图。
  /// 它顶边在 y=247，卡片底边在 y=263，所以有 16pt 压在卡片下面、只露出 12pt；
  /// 卡片左右两侧各露出一角切图自带的 `rgba(51,65,65)` 深色衬底。
  static const _shoulderHeight = 28.0;
  static const _shoulderOverlap = 16.0;

  /// 卡片本体 + 卡片下方露出的那段肩线，共 107。
  static const _designTotalHeight =
      _designHeight + _shoulderHeight - _shoulderOverlap;

  /// 设计稿 `list_3` 的四个筛选项。
  ///
  /// TODO(接口): 订单筛选状态文档里只有 4 全部 / 7 进行中 / 6 待还款 / 5 已结清，
  /// 设计稿的 `Overdue` 没有对应取值，等后端确认后再补。
  static const _entries = <(String, String, OrderFilterStatus?)>[
    ('All', AppAssets.orderAll, OrderFilterStatus.all),
    ('Outstanding', AppAssets.orderOutstanding, OrderFilterStatus.toRepay),
    ('Overdue', AppAssets.orderOverdue, null),
    ('Settled', AppAssets.orderSettled, OrderFilterStatus.settled),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.edgeInsets(left: _designInset, right: _designInset),
      child: SizedBox(
        height: layout.px(_designTotalHeight),
        child: Stack(
          // 肩线切图是 375 通栏，比卡片宽出左右各 28pt，不要裁掉。
          clipBehavior: Clip.none,
          children: [
            // 肩线切图：通栏 375，顶边压进卡片底部 16pt（被卡片盖住），
            // 露出卡片下方 12pt 薄荷色 + 卡片左右各一角深色衬底。
            Positioned(
              left: -layout.px(_designInset),
              right: -layout.px(_designInset),
              top: layout.px(_designHeight - _shoulderOverlap),
              height: layout.px(_shoulderHeight),
              child: Image.asset(
                AppAssets.mineOrderCardShoulder,
                fit: BoxFit.fill,
              ),
            ),
            // 整卡底图（圆角 12/12/0/0 + 横向渐变都在切图里）。
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: layout.px(_designHeight),
              child: Image.asset(AppAssets.mineOrderCard, fit: BoxFit.fill),
            ),
            Padding(
              // 设计稿 `section_2`：`padding: 18px 12px 16px 14px`。
              padding: layout.edgeInsets(
                left: 14,
                top: 18,
                right: 12,
                bottom: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (label, icon, status) in _entries)
                    _OrderEntry(
                      layout: layout,
                      label: label,
                      icon: icon,
                      onTap: () => ToastHelper.showMessage(
                        'Orders: $label${status == null ? '' : ' (${status.value})'}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 订单入口的单个图标 + 文案。
class _OrderEntry extends StatelessWidget {
  const _OrderEntry({
    required this.layout,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final AppLayout layout;
  final String label;
  final String icon;
  final VoidCallback onTap;

  /// 设计稿 `label_3`：35x35。
  static const _iconSize = 35.0;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            width: layout.px(_iconSize),
            height: layout.px(_iconSize),
          ),
          // 设计稿 `text-group_2`：`margin: 8px 11px 0 10px`，取 8pt 上边距。
          SizedBox(height: layout.px(AppSpacing.xs)),
          // 文案比图标宽（Outstanding 约 63pt）。设计稿里 4 个图标是「两端顶格 +
          // 等距」分布，所以图标列宽必须锁死在 35pt，文案用 OverflowBox 溢出居中。
          SizedBox(
            width: layout.px(_iconSize),
            height: layout.px(18),
            child: OverflowBox(
              maxWidth: layout.px(96),
              // 高度必须一起锁死：Column 给的是无界高度，只约束宽度会让
              // OverflowBox 拿到 Size(width, Infinity) 直接断言失败。
              maxHeight: layout.px(18),
              alignment: Alignment.topCenter,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                softWrap: false,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: layout.px(12),
                  // 设计稿 `text-group_2`：`font-size: 12px; line-height: 18px`。
                  height: 18 / 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组标题（设计稿 `text_4` / `text_5`）。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.layout, required this.text});

  final AppLayout layout;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.sectionTitle,
        fontSize: layout.px(16),
        fontWeight: FontWeight.w700,
        // 设计稿：`font-size: 16px; line-height: 19px`。
        height: 19 / 16,
      ),
    );
  }
}

/// 白色分组卡片（设计稿 `box_3` / `box_4` + `list-items_1`，圆角 8）。
class _Card extends StatelessWidget {
  const _Card({required this.layout, required this.child});

  final AppLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: layout.radius(AppSpacing.radiusSm),
      ),
      child: child,
    );
  }
}

/// 列表项（设计稿 `box_3` / `list-items_1`：高 56，左右内边距 14/12）。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.layout,
    required this.leading,
    required this.title,
    this.trailing,
    this.onTap,
    super.key,
  });

  final AppLayout layout;

  /// 左侧图标，20x20。
  final Widget leading;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 设计稿 `list-items_1`：高 56、图标 20x20。
  static const designHeight = 56.0;
  static const iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.px(designHeight),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: layout.edgeInsets(left: 14, right: 12),
          child: Row(
            children: [
              leading,
              SizedBox(width: layout.px(AppSpacing.xs)),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.listItemTitle,
                    fontSize: layout.px(14),
                    // 设计稿 `text-group_3/4/6`：`font-size: 14px; line-height: 20px`。
                    height: 20 / 14,
                  ),
                ),
              ),
              if (trailing case final trailing?) ...[
                SizedBox(width: layout.px(AppSpacing.xs)),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 右侧箭头（设计稿 `thumbnail_4` / `thumbnail_8`，6x10）。
class _Chevron extends StatelessWidget {
  const _Chevron({required this.layout});

  final AppLayout layout;

  static const _width = 7.0;
  static const _height = 11.0;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.chevronRight,
      width: layout.px(_width),
      height: layout.px(_height),
    );
  }
}

/// 右侧说明文案（设计稿 `text-group_5` / `text_6`）。
class _TrailingText extends StatelessWidget {
  const _TrailingText({required this.layout, required this.text});

  final AppLayout layout;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.listItemValue,
        fontSize: layout.px(12),
        // 设计稿：`font-size: 12px; line-height: 17px`。
        height: 17 / 12,
      ),
    );
  }
}

/// About Us 分组（设计稿 `box_4` + `list_4`）。
class _AboutUsCard extends ConsumerWidget {
  const _AboutUsCard({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 官网地址：设计稿是占位文案，这里用配置里的 H5 站点域名。
    // TODO(产品): 官网正式域名确认后换成独立配置项。
    final website = Uri.tryParse(ApiEnvironment.h5Base)?.host ?? '';
    // 版本号取安装包真实版本，设计稿的 `v1.00` 是占位。
    final version = ref.watch(deviceParamsProvider).value?.appVersion ?? '';

    return _Card(
      layout: layout,
      child: Column(
        children: [
          _EntryRow(
            layout: layout,
            leading: _icon(AppAssets.serviceWebsite),
            title: 'Website',
            trailing: _TrailingText(layout: layout, text: website),
            onTap: () => _copyWebsite(website),
          ),
          _EntryRow(
            layout: layout,
            leading: _icon(AppAssets.serviceAppVersion),
            title: 'APP Version',
            trailing: version.isEmpty
                ? null
                : _TrailingText(layout: layout, text: 'v$version'),
          ),
          _EntryRow(
            layout: layout,
            leading: _icon(AppAssets.servicePrivacy),
            title: 'Privacy Agreement',
            trailing: _Chevron(layout: layout),
            onTap: () => AppNavigator.toWebPath<void>(
              path: AppNavigator.privacyAgreementPath,
              title: 'Privacy Agreement',
            ),
          ),
          _EntryRow(
            key: const Key('mine-account-row'),
            layout: layout,
            leading: _icon(AppAssets.serviceAccount),
            title: 'Account',
            trailing: _Chevron(layout: layout),
            onTap: () => _showAccountActions(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _icon(String asset) => Image.asset(
    asset,
    width: layout.px(_EntryRow.iconSize),
    height: layout.px(_EntryRow.iconSize),
  );

  Future<void> _copyWebsite(String website) async {
    if (website.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: website));
    ToastHelper.showMessage('$website copied');
  }

  /// 「Account」底部操作面板（设计稿 `07-01 - 个人中心-退出`）。
  ///
  /// Log out / Delete Account 都要先过一次挽留弹窗（设计稿
  /// `07-01 - 个人中心-退出挽留弹窗` / `07-01 - 个人中心-注销挽留弹窗`），
  /// 只有点了弹窗里的次要行动才真正退出 / 注销。
  Future<void> _showAccountActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_AccountAction>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.dialogBarrier,
      elevation: 0,
      // 设计稿的面板顶部是直角。
      shape: const RoundedRectangleBorder(),
      builder: (context) => _AccountActionSheet(layout: layout),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _AccountAction.logout:
        await showAccountRetentionDialog(
          context: context,
          action: AccountRetentionAction.logout,
          onExit: () async {
            // TODO(埋点): 退出登录需要上报埋点。
            await ref.read(logoutProvider)();
            return true;
          },
        );
      case _AccountAction.deleteAccount:
        await showAccountRetentionDialog(
          context: context,
          action: AccountRetentionAction.deleteAccount,
          onExit: () async {
            // TODO(埋点): 注销账号需要上报埋点。
            final succeeded = await ref.read(deleteAccountProvider)();
            if (!succeeded) {
              ToastHelper.showError('Delete Account failed, please try again');
            }
            return succeeded;
          },
        );
      case _AccountAction.quit:
        // 设计稿里 Quit 是次要行动（灰色），按「关掉面板」处理。
        break;
    }
  }
}

/// 「Account」面板里的行动项。
enum _AccountAction {
  logout('Log out', primary: true),
  deleteAccount('Delete Account', primary: true),
  quit('Quit', primary: false);

  const _AccountAction(this.label, {required this.primary});

  final String label;

  /// 主行动用深色文案，次要行动用灰色（设计稿 `07-01 - 个人中心-退出`）。
  final bool primary;
}

/// 「Account」底部操作面板。
class _AccountActionSheet extends StatelessWidget {
  const _AccountActionSheet({required this.layout});

  final AppLayout layout;

  /// 设计稿：条目高 57.5、分组间隔带 7。
  static const _itemHeight = 57.5;
  static const _groupGap = 7.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 设计稿的面板按 812pt 通栏画到底、没留手势条位置（`section_3` 底边到 812），
      // 真机上必须自己让开：`top: false` 只补底部，面板顶部仍贴着设计稿的位置。
      // showModalBottomSheet 默认 `useSafeArea: false`，它只 removePadding(removeTop: true)，
      // 底部 inset 还在，所以这里能拿到真实的手势条高度。
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _item(context, _AccountAction.logout),
          Divider(
            height: layout.px(1),
            thickness: layout.px(1),
            color: AppColors.actionSheetDivider,
          ),
          _item(context, _AccountAction.deleteAccount),
          SizedBox(
            height: layout.px(_groupGap),
            child: const ColoredBox(color: AppColors.actionSheetGap),
          ),
          _item(context, _AccountAction.quit),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, _AccountAction action) {
    return SizedBox(
      height: layout.px(_itemHeight),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
        child: Center(
          child: Text(
            action.label,
            style: TextStyle(
              color: action.primary
                  ? AppColors.actionSheetText
                  : AppColors.actionSheetTextSecondary,
              fontSize: layout.px(14),
            ),
          ),
        ),
      ),
    );
  }
}
