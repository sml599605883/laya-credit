import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/app_deep_link.dart';
import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/home_data.dart';
import '../providers/home_provider.dart';
import '../providers/repository_provider.dart';
import '../theme/theme.dart';
import '../widgets/remote_image.dart';
import '../widgets/state_views.dart';
import '../widgets/tab_bar/app_tab_bar.dart';
import 'loan_confirm_page.dart';

/// 进度列表页（蓝湖稿 `02-03 - 首页-进度`，即底部导航中间的 Tab）。
///
/// 数据源是首页接口的 `Broadtoothed`（`PROCESS_LIST`）模块 —— 也就是
/// [HomeData.orders]，与首页借款进度卡同一份数据，**不是**订单列表接口。
///
/// 页面结构对齐 fund_nexus 的 `ProgressPage`：标题 + 进度卡列表 / 空态 / 错误态，
/// 下拉刷新复用首页数据源；卡片按后端下发的状态（`satin`）切换配色与按钮，
/// 按钮文案与配色取自设计稿 `02-03 - 首页-进度-全部进度分类`。
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = AppLayout.of(context);
    final homeAsync = ref.watch(homeDataProvider);

    return Scaffold(
      // 设计稿 `page` 底色 `rgba(236, 250, 220, 1)`。
      backgroundColor: AppColors.surfaceMint,
      // 标题贴顶，必须让出状态栏 / 刘海：设计稿标题中心距屏幕顶 67pt，
      // 正好等于安全区高度 + 标题块的一半（46 / 2）。
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.read(homeDataProvider.notifier).refresh(),
          child: CustomScrollView(
            key: const Key('progress-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _ProgressTitle(layout: layout)),
              ...homeAsync.when(
                loading: () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingView(),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      message: switch (error) {
                        ApiException(:final message) => message,
                        _ => 'Failed to load, please try again',
                      },
                      onRetry: () =>
                          ref.read(homeDataProvider.notifier).refresh(),
                    ),
                  ),
                ],
                data: (home) => home.orders.isEmpty
                    ? [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ProgressEmptyState(layout: layout),
                        ),
                      ]
                    : [
                        SliverPadding(
                          // 悬浮导航是浮层，底部要让出它的高度，最后一张卡才能滚出遮挡区。
                          padding: EdgeInsets.fromLTRB(
                            layout.px(AppSpacing.pageHorizontal),
                            layout.px(14),
                            layout.px(AppSpacing.pageHorizontal),
                            layout.px(24) + AppTabBar.overlapHeight(context),
                          ),
                          sliver: SliverList.separated(
                            itemCount: home.orders.length,
                            itemBuilder: (context, index) => _ProgressCard(
                              layout: layout,
                              order: home.orders[index],
                              onTap: () =>
                                  _openOrderDetail(home.orders[index].jumpUrl),
                              onAction: (action) => _handleAction(
                                ref,
                                home.orders[index],
                                action,
                              ),
                            ),
                            separatorBuilder: (_, _) =>
                                SizedBox(height: layout.px(12)),
                          ),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡片整体点击：回到后端下发的订单详情地址（`jumpUrl`）。
  Future<void> _openOrderDetail(String target) async {
    final value = target.trim();
    if (value.isEmpty) return;
    await AppNavigator.openDeepLink(
      const AppDeepLinkParser().parse(value),
      onUnhandled: (link) {
        // TODO(页面): 订单详情等目标页面尚未搭建，先提示原始地址。
        ToastHelper.showMessage('Order target: ${link.raw}');
      },
    );
  }

  /// 状态条按钮分发：`Try again` 走原卡重试确认订单，`Change` 进原生换绑页。
  Future<void> _handleAction(
    WidgetRef ref,
    HomeOrderCard order,
    _ProgressAction action,
  ) async {
    switch (action.type) {
      case _ProgressActionType.tryAgain:
        await _retryOrder(ref, order);
      case _ProgressActionType.change:
        await _changeAccount(ref, order);
    }
  }

  /// `Try again`：调「原卡重试确认订单」拿订单详情页地址再打开。
  ///
  /// 与 H5 桥的 `retryOrderDialog` 是同一个接口（`POST /outsulk/resex`，
  /// 返回订单详情页地址 `kopis`）；接口失败只提示，不回落卡片上的 `jumpUrl`，
  /// 口径对齐 fund_nexus 的 `retryProgressOrder`。
  Future<void> _retryOrder(WidgetRef ref, HomeOrderCard order) async {
    final orderNo = order.orderNo.trim();
    if (orderNo.isEmpty) return;

    final target = await _fetchRetryTarget(ref, orderNo);
    if (target == null) return;
    await _openOrderDetail(target);
  }

  /// 拉重试后的订单详情页地址；失败时提示并返回 null。
  ///
  /// Loading 在返回前就关掉：[_openOrderDetail] 会压 WebView 页并等它 pop，
  /// 带着 Loading 进去会把用户挡在外面（`ToastHelper.showLoading` 是
  /// `allowClick: false`）。
  Future<String?> _fetchRetryTarget(WidgetRef ref, String orderNo) async {
    final loading = ToastHelper.showLoading();
    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      final response = await repository.retryOrderConfirm(orderNo: orderNo);
      if (!response.isSuccess) {
        ToastHelper.showError(
          response.message.isNotEmpty ? response.message : _retryFailedMessage,
        );
        return null;
      }
      final target = response.data.trim();
      if (target.isEmpty) {
        ToastHelper.showError(_retryFailedMessage);
        return null;
      }
      return target;
    } on ApiException catch (error) {
      ToastHelper.showError(error.message);
      return null;
    } catch (_) {
      ToastHelper.showError(_retryFailedMessage);
      return null;
    } finally {
      loading();
    }
  }

  Future<void> _changeAccount(WidgetRef ref, HomeOrderCard order) async {
    final productId = order.productId;
    if (productId <= 0 || order.orderNo.isEmpty) return;
    final result = await AppNavigator.pushTopLevelCertification<Object?>(
      AppRoutes.loanConfirm,
      arguments: LoanConfirmPageArguments(
        productId: productId.toString(),
        orderNo: order.orderNo,
      ),
    );
    if (result == null) return;

    // 要新增账户：进绑卡页改卡模式，成功后它会 pop 订单详情页地址。
    if (result is LoanConfirmAddPaymentMethod) {
      final url = await AppNavigator.push<String>(
        AppRoutes.bindCard,
        arguments: BindCardPageArguments(
          productId: productId.toString(),
          orderNo: order.orderNo,
          isAccountChange: true,
        ),
      );
      if (url != null && url.isNotEmpty) await _openOrderDetail(url);
      return;
    }

    if (result is LoanConfirmAccountChanged) {
      await _openOrderDetail(result.url);
      // 换绑会改变订单状态，回到进度页时刷新一次首页数据。
      unawaited(ref.read(homeDataProvider.notifier).refresh());
    }
  }
}

/// 页面标题（设计稿 `text_24`：17pt / 600 / rgba(51,51,51)）。
///
/// 设计稿标题中心距页面顶部 67pt、距第一张卡 104pt，这里把标题块做成 46pt 居中，
/// 列表顶部再留 14pt，落点与设计稿一致。
class _ProgressTitle extends StatelessWidget {
  const _ProgressTitle({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: layout.px(46),
    child: Center(
      child: Text(
        'progress',
        style: TextStyle(
          color: AppColors.progressProductName,
          fontSize: layout.px(17),
          fontWeight: FontWeight.w600,
          height: 24 / 17,
        ),
      ),
    ),
  );
}

/// 空态（蓝湖稿 `02-03 - 首页-进度-无`）：插画 138x102 + `No progress yet`。
class _ProgressEmptyState extends StatelessWidget {
  const _ProgressEmptyState({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.asset(
        AppAssets.homeProgressEmpty,
        key: const Key('progress-empty-image'),
        width: layout.px(138),
        height: layout.px(102),
        fit: BoxFit.contain,
      ),
      SizedBox(height: layout.px(13)),
      Text(
        'No progress yet',
        style: TextStyle(
          color: AppColors.progressStatusDark,
          fontSize: layout.px(14),
          // 设计稿 `text-group_1`：`font-size: 14px; line-height: 18px`。
          height: 18 / 14,
        ),
      ),
    ],
  );
}

/// 单张进度卡。
///
/// 三层结构（与设计稿 `02-03 - 首页-进度-全部进度分类` 一一对应）：
/// 1. 底层深色衬底（343 宽，向下偏移 41pt，圆角 12）—— 左右各露出 12pt；
/// 2. 白色卡身（319 宽，上下圆角 12）：产品行 + 金额 / 日期小表；
/// 3. 底部状态条（343 宽，高 54 / 26）：粉红或柠檬绿，按钮叠在条上。
///
/// 尺寸全部取自设计稿 CSS：白卡 149pt（有按钮）/ 121pt（无按钮），
/// 小表格 140x48、间距 15，卡片之间 12pt。
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.layout,
    required this.order,
    required this.onTap,
    required this.onAction,
  });

  final AppLayout layout;
  final HomeOrderCard order;
  final VoidCallback onTap;
  final ValueChanged<_ProgressAction> onAction;

  /// 底层衬底相对卡顶的下沉量。
  static const _baseTop = 41.0;

  /// 有按钮 / 无按钮两种卡高。
  static const _tallHeight = 149.0;
  static const _compactHeight = 121.0;

  /// 状态条高度：有按钮 54、无按钮 26。
  static const _barTall = 54.0;
  static const _barCompact = 26.0;

  /// 卡片宽度（设计稿 `box_1`：375 - 16x2）。
  static const _width = 343.0;

  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final presentation = _ProgressPresentation.from(order.status);
    final actions = presentation.actions;
    final height = actions.isEmpty ? _compactHeight : _tallHeight;

    return SizedBox(
      key: Key('progress-card-${order.status.name}'),
      width: layout.px(_width),
      height: layout.px(height),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: layout.px(_baseTop),
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: presentation.baseColor,
                borderRadius: layout.radius(_radius),
              ),
            ),
          ),
          Positioned(
            left: layout.px(12),
            right: layout.px(12),
            top: 0,
            height: layout.px(height),
            child: Material(
              color: AppColors.progressCardSurface,
              borderRadius: layout.radius(_radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: _ProgressCardBody(
                  layout: layout,
                  order: order,
                  presentation: presentation,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: layout.px(actions.isEmpty ? _barCompact : _barTall),
            child: _ProgressActionBar(
              layout: layout,
              presentation: presentation,
              actions: actions,
              onAction: onAction,
            ),
          ),
        ],
      ),
    );
  }
}

/// 白卡内容：产品行 + 金额 / 日期小表。
class _ProgressCardBody extends StatelessWidget {
  const _ProgressCardBody({
    required this.layout,
    required this.order,
    required this.presentation,
  });

  final AppLayout layout;
  final HomeOrderCard order;
  final _ProgressPresentation presentation;

  @override
  Widget build(BuildContext context) => Padding(
    // 设计稿 `box_5`：`padding-top: 12px`，左右各 12pt。
    padding: layout.edgeInsets(left: 12, top: 12, right: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: layout.px(16),
          child: Row(
            children: [
              if (order.productLogo.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: layout.radius(2),
                  child: RemoteImage(
                    url: order.productLogo,
                    width: layout.px(12),
                    height: layout.px(12),
                  ),
                ),
                SizedBox(width: layout.px(4)),
              ],
              Expanded(
                child: Text(
                  order.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.progressProductName,
                    fontSize: layout.px(10),
                    // 设计稿 `text_7`：`font-size: 10px; line-height: 16px`。
                    height: 16 / 10,
                  ),
                ),
              ),
              SizedBox(width: layout.px(8)),
              Text(
                order.orderStatusText.isEmpty
                    ? presentation.statusLabel
                    : order.orderStatusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: presentation.statusColor,
                  fontSize: layout.px(12),
                  // 设计稿 `text_8`：`font-size: 12px; line-height: 14px`。
                  height: 14 / 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: layout.px(12)),
        SizedBox(
          height: layout.px(48),
          child: Row(
            children: [
              Expanded(
                child: _ProgressMetric(
                  layout: layout,
                  value: order.displayAmount,
                  label: order.amountText.isEmpty
                      ? presentation.amountLabel
                      : order.amountText,
                ),
              ),
              SizedBox(width: layout.px(15)),
              Expanded(
                child: _ProgressMetric(
                  layout: layout,
                  value: order.date,
                  label: order.dateText.isEmpty
                      ? presentation.dateLabel
                      : order.dateText,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 小表里的一格（设计稿 `text-wrapper_4`：140x48，底色 rgba(247,247,247)）。
class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.layout,
    required this.value,
    required this.label,
  });

  final AppLayout layout;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    // 设计稿 `text-wrapper_4` 是直角灰块，没有圆角。
    color: AppColors.progressMetricSurface,
    child: Padding(
      padding: layout.edgeInsets(top: 8),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.progressMetricValue,
              fontSize: layout.px(14),
              fontWeight: FontWeight.w700,
              // 设计稿 `text_9`：`font-size: 14px; line-height: 17px`。
              height: 17 / 14,
            ),
          ),
          SizedBox(height: layout.px(4)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.progressMetricLabel,
              fontSize: layout.px(10),
              // 设计稿 `text_10`：`font-size: 10px; line-height: 12px`。
              height: 12 / 10,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 底部状态条：粉红（待还款 / 逾期）或柠檬绿（放款中 / 审核中 / 放款失败），
/// 有按钮时高 54、无按钮时高 26。
class _ProgressActionBar extends StatelessWidget {
  const _ProgressActionBar({
    required this.layout,
    required this.presentation,
    required this.actions,
    required this.onAction,
  });

  final AppLayout layout;
  final _ProgressPresentation presentation;
  final List<_ProgressAction> actions;
  final ValueChanged<_ProgressAction> onAction;

  @override
  Widget build(BuildContext context) {
    // 无按钮的卡只露一条状态色（设计稿 `group_24`：上圆角 4 / 下圆角 12）。
    if (actions.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: presentation.barColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(layout.px(4)),
            bottom: Radius.circular(layout.px(12)),
          ),
        ),
      );
    }

    // 有按钮的条：整条 12 圆角，按钮相对白卡左右各溢出 12pt（共 343 宽）。
    final isLime = presentation.barColor == AppColors.actionLime;
    final pillFill = isLime ? AppColors.progressCardBase : AppColors.surface;
    final pillText = isLime ? AppColors.surface : AppColors.progressStatusPink;
    final single = actions.length == 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: presentation.barColor,
        borderRadius: layout.radius(12),
      ),
      child: Padding(
        padding: layout.edgeInsets(left: 24, right: 24),
        child: Center(
          child: SizedBox(
            height: layout.px(32),
            child: single
                ? _ProgressPill(
                    layout: layout,
                    label: actions.single.label,
                    fill: pillFill,
                    textColor: pillText,
                    onTap: () => onAction(actions.single),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _ProgressPill(
                          layout: layout,
                          label: actions[0].label,
                          fill: Colors.transparent,
                          textColor: AppColors.progressCardBase,
                          borderColor: AppColors.progressCardBase,
                          onTap: () => onAction(actions[0]),
                        ),
                      ),
                      SizedBox(width: layout.px(15)),
                      Expanded(
                        child: _ProgressPill(
                          layout: layout,
                          label: actions[1].label,
                          fill: pillFill,
                          textColor: pillText,
                          onTap: () => onAction(actions[1]),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 状态条上的胶囊按钮（设计稿 `text-wrapper_6` / `text-wrapper_9`：
/// 高 32、圆角 16、文案 12pt / 700）。
class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.layout,
    required this.label,
    required this.fill,
    required this.textColor,
    required this.onTap,
    this.borderColor,
  });

  final AppLayout layout;
  final String label;
  final Color fill;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return Material(
      color: fill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: layout.radius(16),
        side: border == null
            ? BorderSide.none
            : BorderSide(color: border, width: layout.px(1)),
      ),
      child: InkWell(
        key: Key('progress-action-$label'),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: layout.px(12),
              fontWeight: FontWeight.w700,
              // 设计稿 `text_31`：`font-size: 12px; line-height: 14px`。
              height: 14 / 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// 状态条上的动作类型。
enum _ProgressActionType {
  /// 重新放款（原卡重试确认订单）。
  tryAgain,

  /// 更换收款账户（原生账户列表页）。
  change,
}

/// `Try again` 失败且后端没给文案时的兜底提示。
const _retryFailedMessage = 'Unable to retry this order';

/// 状态条上的一个动作。
class _ProgressAction {
  const _ProgressAction(this.type, this.label);

  final _ProgressActionType type;
  final String label;
}

/// 进度卡的配色 / 文案 / 按钮分档。
///
/// 状态码来自首页 `PROCESS_LIST` 的 `satin`（见 [HomeOrderCardStatus]），
/// 配色与文案取自设计稿 `02-03 - 首页-进度-全部进度分类` 的六张组件：
/// 放款失败（柠檬绿条 + `Try again` + `Change`）、放款中（柠檬绿条）、
/// 待还款（粉红条 + `Change`）、审核中（柠檬绿条）、已逾期（粉红条 + `Change`）。
class _ProgressPresentation {
  const _ProgressPresentation({
    required this.statusLabel,
    required this.amountLabel,
    required this.dateLabel,
    required this.statusColor,
    required this.baseColor,
    required this.barColor,
    this.actions = const [],
  });

  final String statusLabel;
  final String amountLabel;
  final String dateLabel;
  final Color statusColor;

  /// 底层衬底色：柠檬绿状态条配 `#12180A`，粉红状态条配 `#372529`。
  final Color baseColor;
  final Color barColor;
  final List<_ProgressAction> actions;

  factory _ProgressPresentation.from(HomeOrderCardStatus status) {
    switch (status) {
      case HomeOrderCardStatus.toRepay:
        return _ProgressPresentation(
          statusLabel: 'Repayment Due',
          amountLabel: 'Repayment',
          dateLabel: 'Repayment Date',
          statusColor: AppColors.progressStatusPink,
          baseColor: AppColors.progressCardBaseRose,
          barColor: AppColors.progressStatusPink,
          actions: _changeAction,
        );
      case HomeOrderCardStatus.overdue:
        return _ProgressPresentation(
          statusLabel: 'Past Due',
          amountLabel: 'Repayment',
          dateLabel: 'Repayment Date',
          statusColor: AppColors.progressStatusPink,
          baseColor: AppColors.progressCardBaseRose,
          barColor: AppColors.progressStatusPink,
          actions: _changeAction,
        );
      case HomeOrderCardStatus.disbursing:
        return _ProgressPresentation(
          statusLabel: 'Awaiting Funds',
          amountLabel: 'Loan Amount',
          dateLabel: 'Loan Date',
          statusColor: AppColors.progressStatusDark,
          baseColor: AppColors.progressCardBase,
          barColor: AppColors.actionLime,
        );
      case HomeOrderCardStatus.failed1:
      case HomeOrderCardStatus.failed2:
        return _ProgressPresentation(
          statusLabel: 'Transfer Unsuccessful',
          amountLabel: 'Loan Amount',
          dateLabel: 'Loan Date',
          statusColor: AppColors.progressStatusPink,
          baseColor: AppColors.progressCardBase,
          barColor: AppColors.actionLime,
          actions: _failedActions,
        );
      case HomeOrderCardStatus.reviewed:
      case HomeOrderCardStatus.normal:
        return _ProgressPresentation(
          statusLabel: 'In Review',
          amountLabel: 'Loan Amount',
          dateLabel: 'Loan Date',
          statusColor: AppColors.progressStatusDark,
          baseColor: AppColors.progressCardBase,
          barColor: AppColors.actionLime,
        );
    }
  }

  static const _changeAction = [
    _ProgressAction(_ProgressActionType.change, 'Change'),
  ];

  static const _failedActions = [
    _ProgressAction(_ProgressActionType.tryAgain, 'Try again'),
    _ProgressAction(_ProgressActionType.change, 'Change'),
  ];
}
