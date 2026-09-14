import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/home_data.dart';
import '../providers/home_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/remote_image.dart';
import '../widgets/state_views.dart';

/// 首页。
///
/// 接口：`GET /outsulk/connectedly`。后端按模块下发（BANNER / LARGE_CARD /
/// PROCESS_LIST / AD_LIST），这里按模块类型渲染，顺序与内容都由后端控制。
class HomePage extends ConsumerWidget {
  const HomePage({super.key, this.isActive = true});

  /// 是否是当前选中的 Tab。
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = AppLayout.of(context);
    final homeAsync = ref.watch(homeDataProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        children: [
          // 顶部暗色渐变背景（设计稿切图，含金色光晕）。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              AppAssets.homeBackground,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceMint,
              onRefresh: () => ref.read(homeDataProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: layout.edgeInsets(
                  left: AppSpacing.pageHorizontal,
                  top: AppSpacing.xs,
                  right: AppSpacing.pageHorizontal,
                  bottom: AppSpacing.xl,
                ),
                children: [
                  _Header(
                    layout: layout,
                    notices: homeAsync.value?.notices ?? const [],
                  ),
                  SizedBox(height: layout.px(AppSpacing.md)),
                  homeAsync.when(
                    loading: () => SizedBox(
                      height: layout.px(240),
                      child: const LoadingView(onDark: true),
                    ),
                    error: (error, _) => SizedBox(
                      height: layout.px(240),
                      child: ErrorView(
                        onDark: true,
                        message: switch (error) {
                          ApiException(:final message) => message,
                          _ => 'Failed to load, please try again',
                        },
                        onRetry: () =>
                            ref.read(homeDataProvider.notifier).refresh(),
                      ),
                    ),
                    data: (home) => _HomeContent(layout: layout, home: home),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.layout, required this.notices});

  final AppLayout layout;
  final List<String> notices;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Laya Credit',
          style: TextStyle(
            color: AppColors.white,
            fontSize: layout.px(20),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (notices.isNotEmpty) ...[
          SizedBox(width: layout.px(AppSpacing.sm)),
          Expanded(
            child: Text(
              notices.first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.surfaceMint.withValues(alpha: 0.72),
                fontSize: layout.px(11),
              ),
            ),
          ),
        ] else
          const Spacer(),
        Image.asset(
          AppAssets.homeMessage,
          width: layout.px(24),
          height: layout.px(24),
        ),
      ],
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.layout, required this.home});

  final AppLayout layout;
  final HomeData home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Banner(layout: layout, banner: home.banner),
        SizedBox(height: layout.px(AppSpacing.md)),
        if (home.product case final product?) ...[
          _ProductCard(layout: layout, product: product),
          SizedBox(height: layout.px(AppSpacing.md)),
        ],
        if (home.hasOrders)
          for (final order in home.orders) ...[
            _OrderProgressCard(layout: layout, order: order),
            SizedBox(height: layout.px(AppSpacing.md)),
          ]
        else
          _LoanProgressEmpty(layout: layout),
        SizedBox(height: layout.px(AppSpacing.xs)),
        _ApplyButton(layout: layout),
      ],
    );
  }
}

/// 运营横幅。文案与图片都由后端下发。
class _Banner extends ConsumerWidget {
  const _Banner({required this.layout, required this.banner});

  final AppLayout layout;
  final HomeBanner? banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = this.banner;
    return GestureDetector(
      onTap: banner == null ? null : () => _openBanner(ref, banner),
      child: ClipRRect(
        borderRadius: layout.radius(AppSpacing.radiusMd),
        child: banner == null
            ? Image.asset(
                AppAssets.homeBanner,
                width: double.infinity,
                fit: BoxFit.fitWidth,
              )
            : AspectRatio(
                aspectRatio: 343 / 120,
                child: RemoteImage(
                  url: banner.imageUrl,
                  fit: BoxFit.cover,
                  fallbackAsset: AppAssets.homeBanner,
                ),
              ),
      ),
    );
  }

  Future<void> _openBanner(WidgetRef ref, HomeBanner banner) async {
    // 文档场景：有登录态且跳转链接不为空时才上报点击记录。
    if (banner.jumpUrl.isEmpty) return;

    if (ref.read(userSessionProvider).isLoggedIn) {
      try {
        final repository = await ref.read(appRepositoryProvider.future);
        await repository.recordBannerClick(banner.id);
      } catch (error) {
        // 点击上报失败不影响跳转。
        debugPrint('[HomePage] banner 点击上报失败: $error');
      }
    }

    // TODO(页面): banner 跳转目标可能是 H5 或原生路由，等 WebView / 详情页补齐后接入。
    ToastHelper.showMessage('Banner target: ${banner.jumpUrl}');
  }
}

/// 产品大卡（LARGE_CARD）：额度、期限、利率与授信进度。
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.layout, required this.product});

  final AppLayout layout;
  final HomeProductCard product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: layout.edgeInsets(
        left: AppSpacing.sm,
        top: AppSpacing.sm,
        right: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: layout.radius(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RemoteImage(
                url: product.productLogo,
                width: layout.px(32),
                height: layout.px(32),
                fit: BoxFit.contain,
              ),
              SizedBox(width: layout.px(AppSpacing.xs)),
              Expanded(
                child: Text(
                  product.productName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: layout.px(16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: layout.px(AppSpacing.sm)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  layout: layout,
                  value: product.amountRange,
                  label: product.amountRangeDes,
                ),
              ),
              Expanded(
                child: _Metric(
                  layout: layout,
                  value: product.termInfo,
                  label: product.termInfoDes,
                ),
              ),
              Expanded(
                child: _Metric(
                  layout: layout,
                  value: product.loanRate,
                  label: product.loanRateDes,
                ),
              ),
            ],
          ),
          if (product.progressText.isNotEmpty) ...[
            SizedBox(height: layout.px(AppSpacing.sm)),
            Text(
              product.progressText,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: layout.px(12),
              ),
            ),
          ],
          if (product.steps.isNotEmpty) ...[
            SizedBox(height: layout.px(AppSpacing.xs)),
            _ProgressSteps(layout: layout, steps: product.steps),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.layout,
    required this.value,
    required this.label,
  });

  final AppLayout layout;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: layout.px(15),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: layout.px(AppSpacing.xs / 2)),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: layout.px(11),
          ),
        ),
      ],
    );
  }
}

/// 授信/还款进度条（横向步骤）。
class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.layout, required this.steps});

  final AppLayout layout;
  final List<HomeProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, step) in steps.indexed) ...[
          if (index > 0)
            Expanded(
              child: Container(
                height: layout.px(2),
                margin: layout.edgeInsets(left: 4, right: 4),
                color: steps[index - 1].selected
                    ? AppColors.primary
                    : AppColors.divider,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: layout.px(10),
                height: layout.px(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              SizedBox(height: layout.px(AppSpacing.xs / 2)),
              Text(
                step.title,
                style: TextStyle(
                  color: step.selected
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  fontSize: layout.px(10),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 借款进度卡（PROCESS_LIST），展示进行中的订单。
class _OrderProgressCard extends StatelessWidget {
  const _OrderProgressCard({required this.layout, required this.order});

  final AppLayout layout;
  final HomeOrderCard order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: layout.edgeInsets(
        left: AppSpacing.sm,
        top: AppSpacing.sm,
        right: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.orderCardStart, AppColors.orderCardEnd],
        ),
        borderRadius: layout.radius(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.title,
            style: TextStyle(
              color: AppColors.surfaceMint,
              fontSize: layout.px(13),
            ),
          ),
          SizedBox(height: layout.px(AppSpacing.xs)),
          Text(
            order.displayAmount,
            style: TextStyle(
              color: AppColors.surface,
              fontSize: layout.px(28),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: layout.px(AppSpacing.xs)),
          Row(
            children: [
              // 状态与日期文案都由后端下发，长度不可控，必须允许省略。
              Flexible(
                child: Text(
                  order.orderStatusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.surfaceMint,
                    fontSize: layout.px(12),
                  ),
                ),
              ),
              SizedBox(width: layout.px(AppSpacing.sm)),
              Expanded(
                child: Text(
                  '${order.dateText} ${order.date}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.surfaceMint.withValues(alpha: 0.8),
                    fontSize: layout.px(11),
                  ),
                ),
              ),
            ],
          ),
          if (order.progressText.isNotEmpty) ...[
            SizedBox(height: layout.px(AppSpacing.sm)),
            Text(
              order.progressText,
              style: TextStyle(
                color: AppColors.surfaceMint,
                fontSize: layout.px(11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 无进行中订单时的空态（对应蓝湖稿 02-03）。
class _LoanProgressEmpty extends StatelessWidget {
  const _LoanProgressEmpty({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: layout.edgeInsets(
        left: AppSpacing.sm,
        top: AppSpacing.lg,
        right: AppSpacing.sm,
        bottom: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: layout.radius(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          Image.asset(
            AppAssets.homeProgressEmpty,
            width: layout.px(120),
            height: layout.px(102),
          ),
          SizedBox(height: layout.px(AppSpacing.sm)),
          Text(
            'No loan in progress',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: layout.px(16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: layout.px(AppSpacing.xs)),
          Text(
            'Check your limit and submit an application in minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: layout.px(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyButton extends ConsumerWidget {
  const _ApplyButton({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: layout.px(44),
      child: FilledButton(
        key: const Key('home-apply-button'),
        onPressed: () async {
          // TODO(埋点): 「立即申请」点击需要在 Firebase Analytics 上报事件。
          if (!ref.read(userSessionProvider).isLoggedIn) {
            await AppNavigator.toLogin();
            return;
          }
          // TODO(接入): 走点击申请 `/outsulk/weaken` + 产品详情/认证流程。
          ToastHelper.showMessage('Application flow is not wired up yet');
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: layout.radius(AppSpacing.radiusMd),
          ),
        ),
        child: const Text('Apply now'),
      ),
    );
  }
}
