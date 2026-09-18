import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/home_data.dart';
import '../providers/home_provider.dart';
import '../providers/product_flow_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/remote_image.dart';
import '../widgets/tab_bar/app_tab_bar.dart';
import '../widgets/state_views.dart';

/// 额度卡底部的橙色提示文案（蓝湖稿 `02-01 - 首页-默认` / `text-wrapper_4`）。
const _applyHint = 'Confirm your loan\uFF0CCash hits fast.';

/// 推荐列表区块标题（蓝湖稿 `02-01` 的 `text_14`）。
///
/// 设计稿右侧还有「More + 箭头」，产品确认不要，这里只保留标题。
const _recommendationTitle = 'Recommendation';

/// 推荐卡底部多段提示文案的分隔符（设计稿 `text_24`：`Low interest rates / ...`）。
const _tipSeparator = ' / ';

/// 首页（蓝湖稿 `02-01 - 首页-默认`）。
///
/// 页面分两段，与设计稿一一对应：
/// 1. 深色额度头图（`375x347`，切图 `home_background.png`）：问候语 / 产品名 /
///    可用额度 / 金币 / 额度条 + 白色额度卡（期限、利率、Apply Now）。
/// 2. 浅绿内容区：后端按模块下发的授信进度、BANNER、推荐列表、借款进度卡。
///
/// 接口：`GET /outsulk/connectedly`。后端按模块下发（BANNER / LARGE_CARD /
/// PROCESS_LIST / AD_LIST / PRODUCT_LIST），这里按模块类型渲染，顺序与内容都由后端控制。
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
            _Hero(layout: layout, product: homeAsync.value?.product),
            Padding(
              padding: layout
                  .edgeInsets(
                    left: AppSpacing.pageHorizontal,
                    top: AppSpacing.sm,
                    right: AppSpacing.pageHorizontal,
                    bottom: AppSpacing.xl,
                  )
                  // 悬浮导航是浮层，让出它的高度，最后一条内容才能滚到胶囊上方。
                  .add(
                    EdgeInsets.only(bottom: AppTabBar.overlapHeight(context)),
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
                data: (home) => _HomeContent(
                  layout: layout,
                  home: home,
                  isActive: isActive,
                ),
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
  const _Hero({required this.layout, required this.product});

  final AppLayout layout;

  /// 后端下发的产品大卡（LARGE_CARD）。未下发时只渲染问候语。
  final HomeProductCard? product;

  /// 设计稿头图总高与状态栏高度（iPhone X 口径）。
  static const _designHeight = 347.0;
  static const _designStatusBar = 44.0;

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
                if (product != null) ...[
                  // 设计稿 `box_4` 与问候语之间是 22pt 空白，取 8 的整数倍。
                  SizedBox(height: layout.px(AppSpacing.md)),
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
        ClipRRect(
          borderRadius: layout.radius(AppSpacing.radiusXxs),
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
class _LimitCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // 整张大卡都可点击：点卡片空白处同样进入申请流程；按钮仍是独立热区。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openApply(ref, product.id),
      child: _card(),
    );
  }

  Widget _card() {
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
                      productId: product.id,
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
  const _HomeContent({
    required this.layout,
    required this.home,
    required this.isActive,
  });

  final AppLayout layout;
  final HomeData home;

  /// 当前 Tab 是否为前台，透传给轮播控制自动播放。
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final product = home.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 授信进度卡（设计稿 02-02 - 首页-有进度）。
        // 后端没下发阶段数据时设计稿上这一块不存在，整卡不渲染。
        if (product != null && product.steps.isNotEmpty) ...[
          _ProductProgress(layout: layout, product: product),
          SizedBox(height: layout.px(AppSpacing.sm)),
        ],
        // 运营位（设计稿 02-01 / 02-02 的第二块）。
        _Banner(layout: layout, banners: home.banners, isActive: isActive),
        // 推荐列表（设计稿 02-01 的 `group_3`）：后端没下发时整块不渲染。
        if (home.productList.isNotEmpty)
          _Recommendation(layout: layout, cards: home.productList),
        // 进行中的借款订单：设计稿没给位置，只在后端真的下发时追加在最下面。
        if (home.hasOrders) ...[
          SizedBox(height: layout.px(AppSpacing.sm)),
          for (final order in home.orders) ...[
            _OrderProgressCard(layout: layout, order: order),
            SizedBox(height: layout.px(AppSpacing.sm)),
          ],
        ],
      ],
    );
  }
}

/// 授信进度卡（设计稿 `02-02 - 首页-有进度`）。
///
/// 整卡视觉（白描边 / 深色标题条 / 左侧金币 / 金色光晕 / 标题文字 / 柠檬绿卡身）
/// 都用设计稿导出的整卡底图 [AppAssets.homeProgressCard]，页面只在卡身上叠三行内容：
/// 金额行 / 进度槽 / 阶段文案行；进度槽上的阶段金币用 [AppAssets.homeProgressCoin]。
///
/// 阶段文案、金额、选中态都由后端下发，长度不可控，文本行按容器等比缩小。
class _ProductProgress extends StatelessWidget {
  const _ProductProgress({required this.layout, required this.product});

  final AppLayout layout;
  final HomeProductCard product;

  // 卡片几何（设计稿 375pt 基准，坐标都相对卡片左上角）。
  static const _cardWidth = 343.0;
  static const _cardHeight = 119.0;

  /// 金额行纵向位置（设计稿 `text-wrapper_6` margin-top: 18px）；横向居中在对应阶段金币上。
  static const _amountTop = 49.0;
  static const _amountFontSize = 10.0;
  static const _amountLineHeight = 12.0;

  /// 进度槽（设计稿 `group_3`：白槽 6pt，金色填充上下各内缩 1pt）。
  static const _trackTop = 77.0;
  static const _trackLeft = 13.0;
  static const _trackRight = 12.0;
  static const _trackHeight = 6.0;
  static const _trackInset = 1.0;

  /// 阶段文案行纵向位置（设计稿 `text-wrapper_13` margin-top: 16px）。
  static const _labelTop = 99.0;
  static const _labelFontSize = 8.0;
  static const _labelLineHeight = 10.0;

  /// 进度槽上的阶段金币（设计稿实测：第一枚距卡左边缘 24pt，间距 90.5pt）。
  static const _coinTop = 72.0;
  static const _coinWidth = 21.7;
  static const _coinHeight = 16.0;
  static const _coinLeft = 24.0;
  static const _coinStride = 90.5;

  /// 进度槽净宽（343 - 13 - 12）。
  static const _trackWidth = _cardWidth - _trackLeft - _trackRight;

  /// 未到达阶段的金币：同一张切图按亮度去色，与设计稿的银币一致。
  static const _silverFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final steps = product.steps;
    final currentIndex = _currentStepIndex(steps);
    final coinStride = _coinStrideFor(steps.length);
    return AspectRatio(
      key: const Key('home-progress-card'),
      aspectRatio: _cardWidth / _cardHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 卡内坐标按卡片实际宽度等比换算（设计稿基准宽 343pt）。
          final factor = constraints.maxWidth / _cardWidth;
          double at(num value) => value * factor;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  AppAssets.homeProgressCard,
                  fit: BoxFit.fill,
                ),
              ),
              // 金额行 / 文案行都按等宽阶段列均分（每列居中），阶段中心也就是进度槽金币中心。
              _stageRow(
                factor: factor,
                stride: coinStride,
                total: steps.length,
                top: _amountTop,
                lineHeight: _amountLineHeight,
                children: [
                  for (final (index, step) in steps.indexed)
                    Text(
                      step.amount,
                      maxLines: 1,
                      softWrap: false,
                      style: _amountStyle(index, currentIndex),
                    ),
                ],
              ),
              Positioned(
                left: at(_trackLeft),
                top: at(_trackTop),
                right: at(_trackRight),
                height: at(_trackHeight),
                child: _buildTrack(steps, currentIndex, factor, coinStride),
              ),
              _stageRow(
                factor: factor,
                stride: coinStride,
                total: steps.length,
                top: _labelTop,
                lineHeight: _labelLineHeight,
                children: [
                  for (final step in steps)
                    Text(
                      step.title,
                      maxLines: 1,
                      softWrap: false,
                      style: _labelStyle(),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _amountStyle(int index, int currentIndex) {
    return TextStyle(
      color: index == currentIndex
          ? AppColors.creditProgressAmountCurrent
          : AppColors.creditProgressAmount,
      fontSize: layout.px(_amountFontSize),
      fontWeight: FontWeight.w700,
      // 设计稿行高 12pt。
      height: 12 / 10,
    );
  }

  TextStyle _labelStyle() {
    return TextStyle(
      color: AppColors.cardValue,
      fontSize: layout.px(_labelFontSize),
      // 设计稿行高 10pt。
      height: 10 / 8,
    );
  }

  /// 金币实际间距（设计稿 4 档固定 [ _coinStride ]；档位更多时压缩到进度槽内）。
  double _coinStrideFor(int total) {
    if (total <= 1) return _coinStride;
    final evenStride = (_trackWidth - _coinWidth * 2) / (total - 1);
    return evenStride < _coinStride ? evenStride : _coinStride;
  }

  /// 一行等宽阶段列：每列宽度 = [stride]，内容居中，所以列中心正好压在进度槽金币上。
  ///
  /// 首列中心 = [_coinLeft] + [_coinWidth] / 2，之后每列 + [stride]，与金币位置一致。
  /// 行宽可能比卡片略宽（首尾列各探出一点），但文字居中仍落在卡内，由外层卡片裁掉空白。
  Widget _stageRow({
    required double factor,
    required double stride,
    required int total,
    required double top,
    required double lineHeight,
    required List<Widget> children,
  }) {
    final left = _coinLeft + _coinWidth / 2 - stride / 2;
    return Positioned(
      left: left * factor,
      top: top * factor,
      width: stride * total * factor,
      height: lineHeight * factor,
      child: Row(
        children: [
          for (final child in children)
            Expanded(
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
        ],
      ),
    );
  }

  /// 进度槽：白色底槽 + 已完成阶段的金色填充，各阶段金币压在槽上。
  Widget _buildTrack(
    List<HomeProgressStep> steps,
    int currentIndex,
    double factor,
    double coinStride,
  ) {
    final total = steps.length;
    final filled = total == 0 ? 0 : currentIndex + 1;
    double at(num value) => value * factor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        return Stack(
          // 金币比进度槽高，允许溢出绘制。
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.creditProgressTrack,
                  borderRadius: layout.radius(_trackHeight / 2),
                ),
              ),
            ),
            if (total > 0)
              Positioned(
                left: 0,
                top: at(_trackInset),
                bottom: at(_trackInset),
                width: trackWidth * filled / total,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.creditProgressFill,
                    borderRadius: layout.radius(_trackHeight / 2),
                  ),
                ),
              ),
            for (final (index, _) in steps.indexed)
              Positioned(
                left: at(_coinLeft + index * coinStride - _trackLeft),
                top: at(_coinTop - _trackTop),
                child: _buildCoin(
                  reached: index <= currentIndex,
                  factor: factor,
                ),
              ),
          ],
        );
      },
    );
  }

  /// 阶段金币：已到达用金色原图，未到达用同一张图去色（设计稿的银币）。
  Widget _buildCoin({required bool reached, required double factor}) {
    final coin = Image.asset(
      AppAssets.homeProgressCoin,
      width: _coinWidth * factor,
      height: _coinHeight * factor,
      fit: BoxFit.fill,
    );
    return reached
        ? coin
        : ColorFiltered(colorFilter: _silverFilter, child: coin);
  }

  /// 当前阶段下标：后端没标选中态时按第一个阶段处理。
  int _currentStepIndex(List<HomeProgressStep> steps) {
    final index = steps.indexWhere((step) => step.selected);
    return index < 0 ? 0 : index;
  }
}

/// 运营横幅。图片与跳转链接都由后端下发，多条时轮播（参考 peso_shield）。
///
/// 轮播规则：
/// - 每 3 秒自动切到下一条并循环；
/// - 只有一条 / 空列表时不轮播；
/// - 用户正在滑动时跳过这一拍，不争抢手势；
/// - App 退到后台或当前 Tab 不在前台（[isActive] 为 false）时暂停。
class _Banner extends ConsumerStatefulWidget {
  const _Banner({
    required this.layout,
    required this.banners,
    required this.isActive,
  });

  final AppLayout layout;
  final List<HomeBanner> banners;
  final bool isActive;

  @override
  ConsumerState<_Banner> createState() => _BannerState();
}

class _BannerState extends ConsumerState<_Banner> with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 3);
  static const _scrollDuration = Duration(milliseconds: 300);

  final _controller = PageController();
  Timer? _timer;
  int _page = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _syncTimer();
  }

  @override
  void didUpdateWidget(_Banner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 条数变化（下拉刷新）后回到第一条，避免停在一个已不存在的页码。
    if (oldWidget.banners.length != widget.banners.length &&
        _controller.hasClients) {
      _page = 0;
      _controller.jumpToPage(0);
    }
    // 条数或前台状态变化都要重算：1 条 -> 多条要起定时器，反过来要停。
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    final count = widget.banners.length;
    if (!widget.isActive || !_foreground || count < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted ||
          !_controller.hasClients ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      unawaited(
        _controller.animateToPage(
          (_page + 1) % count,
          duration: _scrollDuration,
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    // 设计稿 343x120，写死比例避免图片解码前后高度跳变。
    return AspectRatio(
      key: const Key('home-banner'),
      aspectRatio: 343 / 120,
      child: ClipRRect(
        borderRadius: widget.layout.radius(AppSpacing.radiusBanner),
        child: banners.isEmpty
            ? Image.asset(AppAssets.homeBanner, fit: BoxFit.cover)
            : banners.length == 1
            ? _item(banners.single)
            : PageView.builder(
                controller: _controller,
                itemCount: banners.length,
                onPageChanged: (page) => _page = page,
                itemBuilder: (_, index) => _item(banners[index]),
              ),
      ),
    );
  }

  Widget _item(HomeBanner banner) => GestureDetector(
    key: ValueKey('home-banner-${banner.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: () => _openBanner(banner),
    child: RemoteImage(
      url: banner.imageUrl,
      fit: BoxFit.cover,
      fallbackAsset: AppAssets.homeBanner,
    ),
  );

  Future<void> _openBanner(HomeBanner banner) async {
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

/// 额度卡里的主行动按钮（设计稿 `text-wrapper_3`：柠檬绿胶囊）。
class _ApplyButton extends ConsumerWidget {
  const _ApplyButton({
    required this.layout,
    required this.label,
    required this.productId,
  });

  final AppLayout layout;

  /// 后端下发的按钮文案，为空时回落到设计稿文案。
  final String label;

  /// 点击申请 `tartarizing` 传的产品 id。
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton(
      key: const Key('home-apply-button'),
      onPressed: () => _openApply(ref, productId),
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

/// 首页推荐列表（设计稿 `02-01` 的 `group_3`，后端模块 PRODUCT_LIST）。
///
/// 区块标题 + 若干张推荐卡；设计稿右侧的「More + 箭头」不要。
class _Recommendation extends StatelessWidget {
  const _Recommendation({required this.layout, required this.cards});

  final AppLayout layout;
  final List<HomeProductListCard> cards;

  /// 标题与第一张卡之间、以及相邻卡片之间都是 12pt（设计稿 `list_2` 的 margin）。
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 运营位与标题之间的间距（设计稿 `box_15` 的 margin-top 16）。
        SizedBox(height: layout.px(AppSpacing.sm)),
        Text(
          _recommendationTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.cardValue,
            fontSize: layout.px(16),
            fontWeight: FontWeight.w700,
            // 设计稿行高 19pt。
            height: 19 / 16,
          ),
        ),
        SizedBox(height: layout.px(_gap)),
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) SizedBox(height: layout.px(_gap)),
          _RecommendationCard(layout: layout, card: cards[index]),
        ],
      ],
    );
  }
}

/// 一张推荐卡（设计稿 `list-items_1`）：
/// 深色外框里套白卡，右侧压一张 96x130 的「Apply Now」整块按钮切图。
class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard({required this.layout, required this.card});

  final AppLayout layout;
  final HomeProductListCard card;

  /// 深色外框与白卡之间的留白（设计稿 `list-items_1` padding 8）。
  static const _framePadding = 8.0;

  /// 白卡内边距：右侧 74pt 是留给按钮的（设计稿 `box_8` padding）。
  static const _cardPadTop = 12.0;
  static const _cardPadLeft = 8.0;
  static const _cardPadRight = 74.0;
  static const _cardPadBottom = 8.0;

  /// 产品 Logo（设计稿 14x14，圆角 2）。
  static const _logoSize = 14.0;
  static const _logoGap = 4.0;

  /// 金额与额度说明之间的间距（设计稿都是 margin-top 4）。
  static const _amountGap = 4.0;

  /// 「利率 / 期限」小表（设计稿 `box_11`：宽 130 + 左右 padding 8）。
  static const _metricWidth = 146.0;
  static const _metricPadVertical = 12.0;
  static const _metricPadHorizontal = 8.0;
  static const _metricGap = 12.0;

  /// 底部提示文案与上方的间距（设计稿 `text_24` margin-top 15）。
  static const _tipGap = 15.0;
  static const _tipPadRight = 24.0;

  /// 按钮切图尺寸（设计稿 `text-wrapper_10`：96x130）。
  static const _buttonWidth = 96.0;

  /// 按钮切图按后端下发的配色选：高亮 / 正常 / 置灰。
  String get _buttonAsset => switch (card.buttonStyle) {
    HomeProductCardButtonStyle.highlighted => AppAssets.homeApplyNowHighlight,
    HomeProductCardButtonStyle.normal => AppAssets.homeApplyNowNormal,
    HomeProductCardButtonStyle.grayed => AppAssets.homeApplyNowDisabled,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: '${card.productName} ${card.amountRange}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 整张卡都可点击，热区行为与额度大卡一致。
        onTap: () => _openApply(ref, card.id),
        child: Stack(
          // 按钮切图比白卡高 8pt，靠外框的 8pt 留白找平，不要被 Stack 裁掉。
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: layout.edgeInsets(
                left: _framePadding,
                top: _framePadding,
                right: _framePadding,
                bottom: _framePadding,
              ),
              decoration: BoxDecoration(
                color: AppColors.productCardBackground,
                borderRadius: layout.radius(AppSpacing.radiusBanner),
              ),
              child: Container(
                padding: layout.edgeInsets(
                  left: _cardPadLeft,
                  top: _cardPadTop,
                  right: _cardPadRight,
                  bottom: _cardPadBottom,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: layout.radius(AppSpacing.radiusBanner),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      // 左侧内容 67pt 高、小表 60pt 高，小表在整行里垂直居中。
                      children: [
                        Expanded(child: _product()),
                        SizedBox(
                          width: layout.px(_metricWidth),
                          child: _metrics(),
                        ),
                      ],
                    ),
                    if (card.tips.isNotEmpty)
                      Padding(
                        padding: layout.edgeInsets(
                          top: _tipGap,
                          right: _tipPadRight,
                        ),
                        // 提示文案由后端拼装、长度不可控，放不下时整行等比缩小，
                        // 而不是把「... can borrow」截掉。
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            card.tips.join(_tipSeparator),
                            maxLines: 1,
                            style: TextStyle(
                              color: AppColors.productCardTip,
                              fontSize: layout.px(9),
                              // 设计稿行高 11pt。
                              height: 11 / 9,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 整块按钮切图（弧形卡身 + 文案都烘焙在图里），上下与外框找平。
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: layout.px(_buttonWidth),
              child: Image.asset(
                _buttonAsset,
                key: ValueKey('home-recommendation-apply-${card.id}'),
                fit: BoxFit.fill,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 左侧一列：产品 Logo + 名称 / 额度 / 额度说明。
  Widget _product() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: layout.radius(AppSpacing.radiusXxs),
              child: RemoteImage(
                url: card.productLogo,
                fit: BoxFit.contain,
                width: layout.px(_logoSize),
                height: layout.px(_logoSize),
              ),
            ),
            SizedBox(width: layout.px(_logoGap)),
            Expanded(
              child: Text(
                card.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.productCardTitle,
                  fontSize: layout.px(10),
                  // 设计稿行高 16pt。
                  height: 16 / 10,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: layout.edgeInsets(top: _amountGap),
          // 额度长度由后端决定，容器放不下时等比缩小而不是截断金额。
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              card.amountRange,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.cardValue,
                fontSize: layout.px(24),
                fontWeight: FontWeight.w700,
                // 设计稿行高 29pt。
                height: 29 / 24,
              ),
            ),
          ),
        ),
        Padding(
          padding: layout.edgeInsets(top: _amountGap),
          child: Text(
            card.amountRangeDes,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.cardLabel,
              fontSize: layout.px(12),
              // 设计稿行高 14pt。
              height: 14 / 12,
            ),
          ),
        ),
      ],
    );
  }

  /// 右侧「利率 / 期限」小表。
  Widget _metrics() {
    return Container(
      padding: layout.edgeInsets(
        left: _metricPadHorizontal,
        top: _metricPadVertical,
        right: _metricPadHorizontal,
        bottom: _metricPadVertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.productCardMetricBackground,
        borderRadius: layout.radius(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _metricRow(card.loanRateDes, card.loanRate),
          SizedBox(height: layout.px(_metricGap)),
          _metricRow(card.termInfoText, card.termInfo),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.cardLabel,
              fontSize: layout.px(10),
              // 设计稿行高 12pt。
              height: 12 / 10,
            ),
          ),
        ),
        // 数值比标签重要，宽度不够时优先保住数值。
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.productCardTitle,
              fontSize: layout.px(10),
              height: 12 / 10,
            ),
          ),
        ),
      ],
    );
  }
}

/// 「立即申请」入口：未登录先跳登录页，已登录走产品申请流程。
///
/// 额度卡整块、卡内按钮与推荐卡共用这一处逻辑，避免多套热区行为不一致。
/// 准入 / 产品详情 / 借款确认跳转统一由 `ProductApplicationFlow` 处理。
Future<void> _openApply(WidgetRef ref, String productId) async {
  // TODO(埋点): 「立即申请」点击需要在 Firebase Analytics 上报事件。
  if (!ref.read(userSessionProvider).isLoggedIn) {
    await AppNavigator.toLogin();
    return;
  }
  // 产品 id 来自首页模块的 `cussedly`，缺失时无法发起准入。
  if (productId.isEmpty) {
    ToastHelper.showError('Product is unavailable');
    return;
  }
  final flow = await ref.read(productApplicationFlowProvider.future);
  await flow.applyProduct(productId: productId);
}
