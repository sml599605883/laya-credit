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

/// 额度卡底部的橙色提示文案（蓝湖稿 `02-01 - 首页-默认` / `text-wrapper_4`）。
const _applyHint = 'Confirm your loan\uFF0CCash hits fast.';

/// 首页（蓝湖稿 `02-01 - 首页-默认`）。
///
/// 页面分两段，与设计稿一一对应：
/// 1. 深色额度头图（`375x347`，切图 `home_background.png`）：问候语 / 产品名 /
///    可用额度 / 金币 / 额度条 + 白色额度卡（期限、利率、Apply Now）。
/// 2. 浅绿内容区：后端按模块下发的授信进度、BANNER、借款进度卡。
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
      // 设计稿 page 底色 `rgba(236, 250, 220, 1)`。
      backgroundColor: AppColors.surfaceMint,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => ref.read(homeDataProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // 顶部深色头图需要通栏，页面左右边距交给各子块自己控制。
          padding: EdgeInsets.zero,
          children: [
            _Hero(
              layout: layout,
              product: homeAsync.value?.product,
              notices: homeAsync.value?.notices ?? const [],
            ),
            Padding(
              padding: layout.edgeInsets(
                left: AppSpacing.pageHorizontal,
                top: AppSpacing.sm,
                right: AppSpacing.pageHorizontal,
                bottom: AppSpacing.xl,
              ),
              child: homeAsync.when(
                loading: () => SizedBox(
                  height: layout.px(160),
                  child: const LoadingView(),
                ),
                error: (error, _) => SizedBox(
                  height: layout.px(160),
                  child: ErrorView(
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
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部深色额度头图（设计稿 `section_1`）。
///
/// 问候语、产品名走正常流式布局，额度数字 / 金币 / 额度条 / 额度卡按设计稿的
/// 绝对坐标摆放，保证和切图对齐。
class _Hero extends StatelessWidget {
  const _Hero({
    required this.layout,
    required this.product,
    required this.notices,
  });

  final AppLayout layout;

  /// 后端下发的产品大卡（LARGE_CARD）。未下发时只渲染问候语。
  final HomeProductCard? product;

  /// 首页公告（AD_LIST）。
  final List<String> notices;

  /// 设计稿头图总高与状态栏高度（iPhone X 口径）。
  static const _designHeight = 347.0;
  static const _designStatusBar = 44.0;

  /// 公告槽位高度：设计稿里问候语与产品名之间是空白，这里固定占位，
  /// 保证有无公告时产品名 / 额度数字的位置都不变。
  static const _noticeHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    final product = this.product;
    final statusInset = MediaQuery.paddingOf(context).top;
    // 设计稿的 y 坐标都含 44pt 状态栏，真机上按实际状态栏高度平移。
    final shift = statusInset - layout.px(_designStatusBar);

    return SizedBox(
      height: statusInset + layout.px(_designHeight - _designStatusBar),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 深色底 + 顶部金色光晕，底部圆角 12（设计稿「蒙版」）。
          Positioned.fill(
            child: Image.asset(AppAssets.homeBackground, fit: BoxFit.fill),
          ),
          // 额度数字下方的金色闪点（设计稿 y=145 的 `02-01 - 首页-默认` 切图）。
          if (product != null)
            Positioned(
              left: 0,
              right: 0,
              top: shift + layout.px(145),
              child: Image.asset(
                AppAssets.homeHeaderGlow,
                // 切图本体是 375x55，显式给高度避免图片解码前高度为 0。
                width: double.infinity,
                height: layout.px(55),
                fit: BoxFit.fill,
              ),
            ),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              top: statusInset + AppSpacing.xs,
              right: AppSpacing.pageHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Greeting(layout: layout),
                SizedBox(
                  height: layout.px(_noticeHeight),
                  child: notices.isEmpty
                      ? null
                      : Center(
                          child: Text(
                            notices.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.surfaceMint.withValues(
                                alpha: 0.72,
                              ),
                              fontSize: layout.px(11),
                            ),
                          ),
                        ),
                ),
                if (product != null) ...[
                  SizedBox(height: layout.px(AppSpacing.xs)),
                  _ProductTag(layout: layout, product: product),
                  SizedBox(height: layout.px(AppSpacing.xs)),
                  Text(
                    'Available up to',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.heroLabel,
                      fontSize: layout.px(12),
                      // 设计稿行高 14pt。
                      height: 14 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (product != null) ...[
            Positioned(
              left: layout.px(89),
              top: shift + layout.px(136),
              child: _Amount(layout: layout, text: product.amountRange),
            ),
            Positioned(
              right: 0,
              top: shift + layout.px(144),
              child: Image.asset(
                AppAssets.homeMoneyBag,
                width: layout.px(83),
                height: layout.px(58),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: shift + layout.px(197),
              child: _LimitCard(layout: layout, product: product),
            ),
          ],
        ],
      ),
    );
  }
}

/// 头图第一行：居中的问候语 + 右侧消息入口。
class _Greeting extends StatelessWidget {
  const _Greeting({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'Laya Credit',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.white,
            fontSize: layout.px(17),
            fontWeight: FontWeight.w600,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Image.asset(
            AppAssets.homeMessage,
            width: layout.px(24),
            height: layout.px(24),
          ),
        ),
      ],
    );
  }
}

/// 产品标识（设计稿 `block_3`）：产品图标 + 产品名。
class _ProductTag extends StatelessWidget {
  const _ProductTag({required this.layout, required this.product});

  final AppLayout layout;
  final HomeProductCard product;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: layout.px(14),
          height: layout.px(14),
          decoration: BoxDecoration(
            borderRadius: layout.radius(AppSpacing.radiusXxs),
            border: Border.all(color: AppColors.white, width: layout.px(0.3)),
          ),
          child: RemoteImage(
            url: product.productLogo,
            fit: BoxFit.contain,
            width: layout.px(14),
            height: layout.px(14),
          ),
        ),
        SizedBox(width: layout.px(4)),
        Flexible(
          child: Text(
            product.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.white, fontSize: layout.px(10)),
          ),
        ),
      ],
    );
  }
}

/// 可用额度数字（设计稿 `text_6`）。
///
/// 44pt/700、行高 53、字距 2.64，填充是「上白下金」渐变 + 2pt 深色投影。
class _Amount extends StatelessWidget {
  const _Amount({required this.layout, required this.text});

  final AppLayout layout;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontSize: layout.px(44),
        fontWeight: FontWeight.w700,
        letterSpacing: layout.px(2.64),
        height: 53 / 44,
        shadows: [
          Shadow(
            color: AppColors.black.withValues(alpha: 0.5),
            offset: Offset(0, layout.px(2)),
          ),
        ],
        foreground: Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.white, AppColors.amountGradientEnd],
          ).createShader(Rect.fromLTWH(0, 0, 1, layout.px(53))),
      ),
    );
  }
}

/// 额度条 + 白色额度卡（设计稿 `block_6` / `block_7`）。
///
/// 额度卡比额度条左右各内缩 12pt、上下各内缩 7pt，压出「卡片嵌在凹槽里」的效果。
class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.layout, required this.product});

  final AppLayout layout;
  final HomeProductCard product;

  /// 额度条与额度卡的几何关系（设计稿标注值）。
  static const _barHeight = 24.0;
  static const _cardInsetLeft = 28.0;
  static const _cardInsetRight = 28.0;
  static const _cardOffsetTop = 7.0;
  static const _cardPadLeft = 48.0;
  static const _cardPadRight = 42.0;
  static const _cardPadTop = 14.0;
  static const _cardPadBottom = 4.0;
  static const _buttonGap = 16.0;
  static const _buttonPadLeft = 14.0;
  static const _buttonPadRight = 10.0;
  static const _buttonHeight = 40.0;
  static const _stripHeight = 6.0;
  static const _textGroupGap = 4.0;
  static const _dividerHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: layout.edgeInsets(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
          ),
          child: Container(
            height: layout.px(_barHeight),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: layout.radius(AppSpacing.radiusXs),
              border: Border.all(
                color: AppColors.creditBarBorder,
                width: layout.px(1),
              ),
            ),
          ),
        ),
        Padding(
          padding: layout.edgeInsets(
            left: _cardInsetLeft,
            top: _cardOffsetTop,
            right: _cardInsetRight,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(layout.px(AppSpacing.radiusSm)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部渐变条：由深转白，做出凹槽底部的高光。
                Container(
                  height: layout.px(_stripHeight),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.cardStripStart, AppColors.surface],
                    ),
                  ),
                ),
                Padding(
                  padding: layout.edgeInsets(
                    left: _cardPadLeft,
                    top: _cardPadTop,
                    right: _cardPadRight,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _CardMetric(
                            layout: layout,
                            value: product.termInfo,
                            label: product.termInfoDes,
                            gap: _textGroupGap,
                          ),
                        ),
                      ),
                      Container(
                        width: layout.px(1),
                        height: layout.px(_dividerHeight),
                        color: AppColors.cardDivider,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _CardMetric(
                            layout: layout,
                            value: product.loanRate,
                            label: product.loanRateDes,
                            gap: _textGroupGap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: layout.edgeInsets(
                    left: _buttonPadLeft,
                    top: _buttonGap,
                    right: _buttonPadRight,
                  ),
                  child: SizedBox(
                    height: layout.px(_buttonHeight),
                    child: _ApplyButton(
                      layout: layout,
                      label: product.buttonText,
                    ),
                  ),
                ),
                Padding(
                  padding: layout.edgeInsets(
                    top: _textGroupGap,
                    bottom: _cardPadBottom,
                  ),
                  child: Text(
                    _applyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.hintOrange,
                      fontSize: layout.px(10),
                      // 设计稿提示文案盒子高 14pt。
                      height: 14 / 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 额度卡里的一组「数值 + 说明」（设计稿 `text-group_1` / `text-group_2`）。
class _CardMetric extends StatelessWidget {
  const _CardMetric({
    required this.layout,
    required this.value,
    required this.label,
    required this.gap,
  });

  final AppLayout layout;
  final String value;
  final String label;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.cardValue,
            fontSize: layout.px(14),
            // 设计稿行高 17pt。
            height: 17 / 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: layout.px(gap)),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.cardLabel,
            fontSize: layout.px(10),
            // 设计稿行高 12pt。
            height: 12 / 10,
          ),
        ),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.layout, required this.home});

  final AppLayout layout;
  final HomeData home;

  @override
  Widget build(BuildContext context) {
    final product = home.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 授信进度（设计稿 02-02「Credit activation progress」）。
        if (product != null && product.steps.isNotEmpty) ...[
          _ProductProgress(layout: layout, product: product),
          SizedBox(height: layout.px(AppSpacing.sm)),
        ],
        _Banner(layout: layout, banner: home.banner),
        SizedBox(height: layout.px(AppSpacing.sm)),
        if (home.hasOrders)
          for (final order in home.orders) ...[
            _OrderProgressCard(layout: layout, order: order),
            SizedBox(height: layout.px(AppSpacing.sm)),
          ]
        else
          _LoanProgressEmpty(layout: layout),
        // 后端没下发产品大卡时，额度卡里的申请入口不存在，这里补一个兜底入口。
        if (product == null) ...[
          SizedBox(height: layout.px(AppSpacing.sm)),
          _ApplyButton(layout: layout, label: ''),
        ],
      ],
    );
  }
}

/// 授信进度卡（设计稿 `02-02 - 首页-有进度`）。
class _ProductProgress extends StatelessWidget {
  const _ProductProgress({required this.layout, required this.product});

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
        borderRadius: layout.radius(AppSpacing.radiusBanner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (product.progressText.isNotEmpty) ...[
            Text(
              product.progressText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: layout.px(16),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: layout.px(AppSpacing.sm)),
          ],
          _ProgressSteps(layout: layout, steps: product.steps),
        ],
      ),
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
        borderRadius: layout.radius(AppSpacing.radiusBanner),
        // 设计稿 343x120，写死比例避免图片解码前后高度跳变。
        child: AspectRatio(
          aspectRatio: 343 / 120,
          child: banner == null
              ? Image.asset(AppAssets.homeBanner, fit: BoxFit.cover)
              : RemoteImage(
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

/// 额度卡里的主行动按钮（设计稿 `text-wrapper_3`：柠檬绿胶囊）。
class _ApplyButton extends ConsumerWidget {
  const _ApplyButton({required this.layout, required this.label});

  final AppLayout layout;

  /// 后端下发的按钮文案，为空时回落到设计稿文案。
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton(
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
        backgroundColor: AppColors.actionLime,
        foregroundColor: AppColors.cardValue,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: layout.radius(AppSpacing.radiusPill),
        ),
      ),
      child: Text(
        label.isEmpty ? 'Apply Now' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.cardValue,
          fontSize: layout.px(17),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
