import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/report/report.dart';
import '../data/models/id_verification_data.dart';
import '../providers/id_verification_provider.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';

/// 顶部导航标题（设计稿 `text_3`）。
const _navTitle = 'ID Verification';

/// 推荐证件分组标题（设计稿 `text_6`）。
const _recommendedTitle = 'Recommended ID Type';

/// 其他证件分组标题（设计稿 `text_5`）。
const _otherOptionsTitle = 'Other Options';

/// 头图高度（设计稿 `section_1`，375x213）。
const _headerHeight = 213.0;

/// 卡片比头图底边高出的部分（设计稿 `text-wrapper_4` 的 `top: -19`）：
/// 白色标题块压在头图下沿上，让头图不被生硬截断。
const _cardOverlap = 19.0;

/// 两张卡片之间的间距（设计稿 `section_3` 底边 483 -> `text-wrapper_4` 顶边 495）。
const _groupGap = 12.0;

/// 页面底部留白（设计稿卡片底边 784 -> 页面底边 812）。
const _pageBottom = 28.0;

/// Loading / Error / Empty 态的高度（头图下方那块内容区，避免状态视图撑不满）。
const _stateHeight = 160.0;

/// 证件选择页（蓝湖稿 `03 - 认证流程模块`），认证流程第一步。
///
/// 页面分三段，与设计稿一一对应：
/// 1. 通栏头图（`section_1`）：绿色渐变 + 「ID Verification」大标题 + 吉祥物，
///    全部烘焙在切图 `id_verify_header.png` 里；返回按钮与导航标题浮在头图上。
/// 2. `Recommended ID Type` 卡片（`section_3`）：后端下发的推荐证件。
/// 3. `Other Options` 卡片（`section_4`）：后端下发的备选证件。
///
/// 证件类型不是客户端写死的：进页面用 [productId] 拉 `GET /outsulk/gaonate`
/// （认证第一项），后端按产品下发两组卡片（响应里的 `magisterial`）；
/// 没下发（低版本 / 未灰度用户）时走空态。选中证件后的上传页尚未搭建，点击先给占位提示。
class IdVerificationPage extends ConsumerStatefulWidget {
  const IdVerificationPage({super.key, required this.productId});

  /// 产品 id：证件类型按产品下发，对应接口的 `tartarizing`。
  final String productId;

  @override
  ConsumerState<IdVerificationPage> createState() => _IdVerificationPageState();
}

class _IdVerificationPageState extends ConsumerState<IdVerificationPage> {
  /// 风控埋点场景 2（认证选择）的开始时间：进入本页时记录。
  late final int _sceneStartSeconds;

  @override
  void initState() {
    super.initState();
    _sceneStartSeconds = ReportService.nowSeconds();
  }

  /// 选中证件类型后进上传页。
  ///
  /// 卡类型原样带下去（就是这里的文案，也是保存接口 `heterological` 的取值）。
  void _onIdTypeSelected(String idType) {
    // 风控埋点场景 2：结束时间就是「选择完成」这一刻。
    unawaited(
      ReportService.current?.reportRisk(
            productId: widget.productId,
            scene: '2',
            startedAtSeconds: _sceneStartSeconds,
          ) ??
          Future<void>.value(),
    );
    AppNavigator.push(
      AppRoutes.idUpload,
      arguments: IdUploadPageArguments(
        productId: widget.productId,
        cardType: idType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productId = widget.productId;
    final layout = AppLayout.of(context);
    final idVerification = ref.watch(idVerificationProvider(productId));

    return CertificationScaffold(
      navTitle: _navTitle,
      // 这张稿的头图自带「ID Verification」标题，页面不再叠引导段落。
      headerAsset: AppAssets.idVerifyHeader,
      headerHeight: _headerHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 卡片顶边比头图底边高 19pt，两块内容由 Stack 叠出来。
          SizedBox(height: layout.px(_headerHeight - _cardOverlap)),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              bottom: _pageBottom,
            ),
            child: idVerification.when(
              loading: () => SizedBox(
                height: layout.px(_stateHeight),
                child: const LoadingView(),
              ),
              error: (error, _) => SizedBox(
                height: layout.px(_stateHeight),
                child: ErrorView(
                  message: switch (error) {
                    ApiException(:final message) => message,
                    _ => 'Failed to load, please try again',
                  },
                  onRetry: () =>
                      ref.invalidate(idVerificationProvider(productId)),
                ),
              ),
              data: (data) => _IdTypeGroups(
                layout: layout,
                data: data,
                onSelected: _onIdTypeSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 接口下发的两组证件类型。
///
/// 后端只下发一组（或其中一组为空）时，只渲染有内容的那张卡；
/// 两组都空时给空态文案，而不是画两张空卡片。
class _IdTypeGroups extends StatelessWidget {
  const _IdTypeGroups({
    required this.layout,
    required this.data,
    required this.onSelected,
  });

  final AppLayout layout;
  final IdVerificationData data;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final groups = <Widget>[
      if (data.recommended.isNotEmpty)
        _IdTypeGroup(
          layout: layout,
          title: _recommendedTitle,
          types: data.recommended,
          onSelected: onSelected,
        ),
      if (data.other.isNotEmpty)
        _IdTypeGroup(
          layout: layout,
          title: _otherOptionsTitle,
          types: data.other,
          onSelected: onSelected,
        ),
    ];

    if (groups.isEmpty) {
      return SizedBox(
        height: layout.px(_stateHeight),
        child: Center(
          child: Text(
            'No ID types available yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: layout.px(14),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) SizedBox(height: layout.px(_groupGap)),
          groups[i],
        ],
      ],
    );
  }
}

/// 一组证件类型：白色标题块 + 卡片本体（设计稿 `text-wrapper_4` + `section_3`）。
///
/// 设计稿把标题块和卡片拆成两个绝对定位元素，标题块底边压在卡片顶边上，
/// 卡片自己的顶边不圆角（`border-radius: 0 0 12 12`）。这里按同样的顺序竖排，
/// 视觉结果一致且不需要绝对定位。
class _IdTypeGroup extends StatelessWidget {
  const _IdTypeGroup({
    required this.layout,
    required this.title,
    required this.types,
    required this.onSelected,
  });

  final AppLayout layout;
  final String title;

  /// 后端 `magisterial` 下发的证件文案，顺序照抄。
  final List<String> types;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 设计稿 `text-wrapper_3` / `text-wrapper_4`：白底圆角 12，
        // `padding: 12px 221px 36px 14px`，标题 16pt/700。
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(layout.px(AppSpacing.radiusBanner)),
            ),
          ),
          child: Padding(
            padding: layout.edgeInsets(
              left: 14,
              top: 12,
              right: 14,
              bottom: 12,
            ),
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.sectionTitle,
                fontSize: layout.px(16),
                fontWeight: FontWeight.w700,
                // 设计稿：`font-size: 16px; line-height: 19px`。
                height: 19 / 16,
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(layout.px(AppSpacing.radiusBanner)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 设计稿 `box_1` / `section_5`：标题与列表之间的 1pt 分隔线。
              SizedBox(
                height: layout.px(1),
                child: const ColoredBox(color: AppColors.idVerifyDivider),
              ),
              for (var i = 0; i < types.length; i++) ...[
                if (i > 0) _DashedDivider(layout: layout),
                _IdTypeRow(
                  layout: layout,
                  idType: types[i],
                  onTap: () => onSelected(types[i]),
                ),
              ],
              // 设计稿 `section_3` / `section_4` 的 `padding-bottom: 12px`。
              SizedBox(height: layout.px(12)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 证件类型行（设计稿 `box_2` ~ `box_6` / `section_6` ~ `section_10`）。
///
/// 设计稿行文 15pt/行高 18，行与行之间靠外边距撑开（折算下来每行 46pt，
/// 整卡 5 行的高度与设计稿 246pt 只差 1pt）。
class _IdTypeRow extends StatelessWidget {
  const _IdTypeRow({
    required this.layout,
    required this.idType,
    required this.onTap,
  });

  final AppLayout layout;
  final String idType;
  final VoidCallback onTap;

  static const _designHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.px(_designHeight),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // 设计稿行元素 `margin: 11px 12px 0 14px`。
          padding: layout.edgeInsets(left: 14, right: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  idType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.idVerifyRowText,
                    fontSize: layout.px(15),
                    // 设计稿：`font-size: 15px; line-height: 18px`。
                    height: 18 / 15,
                  ),
                ),
              ),
              SizedBox(width: layout.px(AppSpacing.xs)),
              _Chevron(layout: layout),
            ],
          ),
        ),
      ),
    );
  }
}

/// 行尾箭头（设计稿 `thumbnail_*`，5x9，颜色同行文案）。
///
/// 设计稿切图在 `assets/` 里没有对应文件，`assets/common/chevron_right.png` 是
/// 个人中心那套灰色箭头（7x11、`rgba(153,153,153)`），配色对不上，这里按设计稿
/// 尺寸用画笔还原，颜色走 [AppColors.idVerifyRowText]。
class _Chevron extends StatelessWidget {
  const _Chevron({required this.layout});

  final AppLayout layout;

  static const _width = 5.0;
  static const _height = 9.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.px(_width),
      height: layout.px(_height),
      child: CustomPaint(
        painter: _ChevronPainter(color: AppColors.idVerifyRowText),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // 设计稿切图实测描边约 1pt。
      ..strokeWidth = size.width * 0.22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}

/// 行与行之间的虚线（设计稿「路径 4」：316x1，实 4 空 4，`rgba(189,189,162)`）。
///
/// Flutter 没有虚线边框，用 [CustomPainter] 画；虚线左右各内缩 12pt，
/// 与设计稿 `image_4` 的居中摆法一致。
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.layout});

  final AppLayout layout;

  static const _dash = 4.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.edgeInsets(left: 12, right: 12),
      child: SizedBox(
        height: layout.px(1),
        child: CustomPaint(
          painter: _DashedLinePainter(
            color: AppColors.idVerifyDashedDivider,
            dashWidth: layout.px(_dash),
            gapWidth: layout.px(_dash),
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gapWidth,
  });

  final Color color;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || dashWidth <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;

    for (var x = 0.0; x < size.width; x += dashWidth + gapWidth) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.gapWidth != gapWidth;
}
