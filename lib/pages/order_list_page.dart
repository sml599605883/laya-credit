import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/app_deep_link.dart';
import '../core/navigation/app_navigator.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/order_list_data.dart';
import '../providers/order_list_provider.dart';
import '../theme/theme.dart';
import '../widgets/back_nav_bar.dart';
import '../widgets/remote_image.dart';
import '../widgets/state_views.dart';

/// 订单列表页（蓝湖稿 `05-01 - 订单列表-有订单` / `05-01 - 订单列表-无订单`）。
///
/// 个人中心订单入口卡片（`07-01` 的 `section_2`）的四个图标分别带筛选状态进来；
/// 页面顶部四个筛选项与接口 `POST /outsulk/gundy` 的 `butterpaste` 一一对应。
class OrderListPage extends ConsumerStatefulWidget {
  const OrderListPage({super.key, this.initialStatus = OrderFilterStatus.all});

  /// 进入页面时默认选中的筛选状态。
  final OrderFilterStatus initialStatus;

  @override
  ConsumerState<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends ConsumerState<OrderListPage> {
  late OrderFilterStatus _status = widget.initialStatus;

  /// 用 [ScrollController] 而不是 `NotificationListener`：滚动监听在 layout 阶段
  /// 之外触发，触底时改 provider 状态不会撞上「build 期间改状态」。
  final _scrollController = ScrollController();

  /// 距列表底部还剩这么多像素时预取下一页（约半屏）。
  static const _loadMoreThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > _loadMoreThreshold) return;
    // 没有下一页 / 在途时 loadMore 自己会忽略，这里不必再判一次。
    ref.read(orderListProvider(_status.value).notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final provider = orderListProvider(_status.value);
    final orders = ref.watch(provider);

    return Scaffold(
      // 设计稿 `page` 底色 `rgba(236, 250, 220, 1)`。
      backgroundColor: AppColors.surfaceMint,
      body: Column(
        children: [
          BackNavBar(
            layout: layout,
            title: 'Loan List',
            onBack: () => AppNavigator.pop<void>(),
          ),
          Padding(
            // 设计稿 `block_3`：`margin: 22px 30px 0 0`。
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              top: 22,
              right: AppSpacing.pageHorizontal,
            ),
            child: _OrderTabs(
              layout: layout,
              selected: _status,
              onSelected: _selectStatus,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: ListView(
                key: const Key('order-list-scroll'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: layout.edgeInsets(bottom: 24),
                children: [
                  orders.when(
                    data: (data) => data.isEmpty
                        ? _OrderEmpty(layout: layout)
                        : Padding(
                            // 设计稿 `list_1`：距筛选项 `margin-top: 20px`。
                            padding: layout.edgeInsets(top: 20),
                            child: Column(
                              children: [
                                for (final item in data.items)
                                  Padding(
                                    padding: layout.edgeInsets(
                                      left: AppSpacing.pageHorizontal,
                                      right: AppSpacing.pageHorizontal,
                                      bottom: 12,
                                    ),
                                    child: _OrderCard(
                                      layout: layout,
                                      item: item,
                                      onTap: () =>
                                          _openTarget(item.detailTarget),
                                      onAction: () =>
                                          _openTarget(item.actionTarget),
                                    ),
                                  ),
                                if (data.isLoadingMore || data.loadMoreFailed)
                                  _LoadMoreFooter(
                                    layout: layout,
                                    failed: data.loadMoreFailed,
                                    onRetry: () =>
                                        ref.read(provider.notifier).loadMore(),
                                  ),
                              ],
                            ),
                          ),
                    loading: () => SizedBox(
                      height: layout.px(300),
                      child: const LoadingView(),
                    ),
                    error: (error, _) => SizedBox(
                      height: layout.px(300),
                      child: ErrorView(
                        message: error is ApiException
                            ? error.message
                            : 'Unable to load orders.',
                        onRetry: () => ref.invalidate(provider),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 切换筛选项：回到列表顶部，否则新列表会停在上一个筛选的滚动位置。
  void _selectStatus(OrderFilterStatus status) {
    setState(() => _status = status);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _refresh() async {
    final provider = orderListProvider(_status.value);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // 失败态由页面上的 ErrorView 兜底，下拉手势这里只需结束。
    }
  }

  /// 打开后端下发的跳转地址：绝对地址直接进 WebView，相对地址拼 H5 站点根地址。
  Future<void> _openTarget(String target) async {
    final value = target.trim();
    if (value.isEmpty) return;

    final uri = AppNavigator.webViewUri(value);
    if (uri != null) {
      await AppNavigator.toWebView<void>(url: uri.toString());
      return;
    }
    if (value.startsWith('/')) {
      await AppNavigator.toWebPath<void>(path: value);
      return;
    }
    ToastHelper.showMessage('Order target: $value');
  }
}

/// 顶部筛选项（设计稿 `block_3`：`View All` 选中胶囊 + `Unpaid` / `Late` / `Paid`）。
///
/// 四项等分整行宽度（与设计稿四个文案的中心位置一致）；选中项是柠檬绿胶囊，
/// 文案 16/700，未选中 12/400，靠上下各 7pt 内边距对齐到与胶囊同高。
class _OrderTabs extends StatelessWidget {
  const _OrderTabs({
    required this.layout,
    required this.selected,
    required this.onSelected,
  });

  final AppLayout layout;
  final OrderFilterStatus selected;
  final ValueChanged<OrderFilterStatus> onSelected;

  /// 筛选项与接口状态码的对应关系（`butterpaste`：4/7/6/5）。
  static const _tabs = <(OrderFilterStatus, String)>[
    (OrderFilterStatus.all, 'View All'),
    (OrderFilterStatus.inProgress, 'Unpaid'),
    (OrderFilterStatus.toRepay, 'Late'),
    (OrderFilterStatus.settled, 'Paid'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (status, label) in _tabs)
          Expanded(
            child: InkWell(
              key: ValueKey('order-tab-${status.value}'),
              onTap: () => onSelected(status),
              child: Center(
                child: status == selected
                    ? _Pill(layout: layout, label: label)
                    : Padding(
                        padding: layout.edgeInsets(top: 7, bottom: 7),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppColors.orderTabText,
                            fontSize: layout.px(12),
                            // 设计稿 `text_5`：`font-size: 12px; line-height: 14px`。
                            height: 14 / 12,
                          ),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 选中的筛选胶囊（设计稿 `text-wrapper_2`，圆角 22、柠檬绿底）。
class _Pill extends StatelessWidget {
  const _Pill({required this.layout, required this.label});

  final AppLayout layout;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: layout.edgeInsets(left: 8, top: 5, right: 8, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.orderTabActiveBackground,
        borderRadius: layout.radius(22),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.orderTabActiveText,
          fontSize: layout.px(16),
          fontWeight: FontWeight.w700,
          // 设计稿 `text_4`：`font-size: 16px; line-height: 19px`。
          height: 19 / 16,
        ),
      ),
    );
  }
}

/// 订单卡（设计稿 `list-items_1-0`：白底、圆角 8、内边距 12）。
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.layout,
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  final AppLayout layout;
  final OrderListItem item;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: layout.radius(AppSpacing.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: layout.edgeInsets(left: 12, top: 12, right: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              SizedBox(height: layout.px(12)),
              _metrics(),
              if (item.hasAction) ...[
                SizedBox(height: layout.px(12)),
                _actionButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 产品 Logo + 名称 + 右侧状态文案（设计稿 `section_1-0`）。
  Widget _header(BuildContext context) {
    return Row(
      children: [
        if (item.productLogo.isNotEmpty) ...[
          ClipRRect(
            borderRadius: layout.radius(AppSpacing.radiusXxs),
            child: RemoteImage(
              url: item.productLogo,
              width: layout.px(14),
              height: layout.px(14),
            ),
          ),
          SizedBox(width: layout.px(6)),
        ],
        Expanded(
          child: Text(
            item.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.orderProductName,
              fontSize: layout.px(14),
              fontWeight: FontWeight.w500,
              // 设计稿 `text-group_1`：`font-size: 14px; line-height: 16px`。
              height: 16 / 14,
            ),
          ),
        ),
        SizedBox(width: layout.px(8)),
        Text(
          item.statusText,
          style: TextStyle(
            color: _statusColor(item.statusTone),
            fontSize: layout.px(12),
            // 设计稿 `text_8`：`font-size: 12px; line-height: 14px`。
            height: 14 / 12,
          ),
        ),
      ],
    );
  }

  /// 金额 / 日期小表（设计稿 `section_2-0`，浅灰底 + 中间 1pt 竖线）。
  Widget _metrics() {
    return Container(
      padding: layout.edgeInsets(top: 16, bottom: 15),
      decoration: BoxDecoration(
        color: AppColors.orderMetricBackground,
        borderRadius: layout.radius(AppSpacing.radiusXs),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              layout: layout,
              label: item.amountLabel,
              value: item.amountText,
            ),
          ),
          Container(
            width: layout.px(1),
            height: layout.px(25),
            color: AppColors.orderMetricDivider,
          ),
          Expanded(
            child: _Metric(
              layout: layout,
              label: item.dateLabel,
              value: item.dateValue,
            ),
          ),
        ],
      ),
    );
  }

  /// 主按钮（设计稿 `text-wrapper_3-0`，满宽 38pt 柠檬绿胶囊，文案来自后端）。
  Widget _actionButton() {
    return SizedBox(
      height: layout.px(38),
      child: Material(
        color: AppColors.orderTabActiveBackground,
        borderRadius: layout.radius(AppSpacing.radiusPill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAction,
          child: Center(
            child: Text(
              item.actionText,
              style: TextStyle(
                color: AppColors.orderTabActiveText,
                fontSize: layout.px(14),
                fontWeight: FontWeight.w700,
                // 设计稿 `text_13`：`font-size: 14px; line-height: 17px`。
                height: 17 / 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(OrderStatusTone tone) => switch (tone) {
    OrderStatusTone.overdue => AppColors.orderStatusOverdue,
    OrderStatusTone.active => AppColors.orderStatusActive,
    OrderStatusTone.neutral => AppColors.orderStatusNeutral,
  };
}

/// 小表里的一格：主数值 + 字段名（设计稿 `text-group_2-0`）。
class _Metric extends StatelessWidget {
  const _Metric({
    required this.layout,
    required this.label,
    required this.value,
  });

  final AppLayout layout;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.orderMetricValue,
            fontSize: layout.px(14),
            // 设计稿 `text_9`：`font-size: 14px; line-height: 17px`。
            height: 17 / 14,
          ),
        ),
        SizedBox(height: layout.px(8)),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.orderMetricLabel,
            fontSize: layout.px(12),
            // 设计稿 `text_10`：`font-size: 12px; line-height: 14px`。
            height: 14 / 12,
          ),
        ),
      ],
    );
  }
}

/// 列表底部的翻页状态（设计稿没有这一块，样式沿用页面字号与主色）：
/// 加载中转圈；失败时给一个重试入口，已加载的订单不会因为翻页失败被清掉。
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.layout,
    required this.failed,
    required this.onRetry,
  });

  final AppLayout layout;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.edgeInsets(top: 12, bottom: 12),
      child: Center(
        child: failed
            ? TextButton(
                key: const Key('order-list-load-more-retry'),
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: Text(
                  'Unable to load more, tap to retry',
                  style: TextStyle(fontSize: layout.px(12)),
                ),
              )
            : SizedBox(
                key: const Key('order-list-load-more'),
                width: layout.px(20),
                height: layout.px(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
      ),
    );
  }
}

/// 无订单空态（蓝湖稿 `05-01 - 订单列表-无订单` 的 `block_4`）。
///
/// 设计稿里空态距筛选项 248pt（不是垂直居中），插画 138x102、文案 14/18。
class _OrderEmpty extends StatelessWidget {
  const _OrderEmpty({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.edgeInsets(top: 248),
      child: Column(
        children: [
          Image.asset(
            AppAssets.orderListEmpty,
            key: const Key('order-list-empty-image'),
            width: layout.px(138),
            height: layout.px(102),
            fit: BoxFit.contain,
          ),
          SizedBox(height: layout.px(12)),
          Text(
            'No information available',
            style: TextStyle(
              color: AppColors.orderEmptyText,
              fontSize: layout.px(14),
              // 设计稿 `text-group_1`：`font-size: 14px; line-height: 18px`。
              height: 18 / 14,
            ),
          ),
        ],
      ),
    );
  }
}
