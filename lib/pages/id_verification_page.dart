import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/navigation/navigation.dart';
import '../core/ui/toast_helper.dart';
import '../theme/theme.dart';

/// 顶部导航标题（设计稿 `text_3`）。
const _navTitle = 'ID Verification';

/// 推荐证件分组标题（设计稿 `text_6`）。
const _recommendedTitle = 'Recommended ID Type';

/// 其他证件分组标题（设计稿 `text_5`）。
const _otherOptionsTitle = 'Other Options';

/// 推荐证件类型（设计稿 `section_3`，顺序与文案都与设计稿一致）。
///
/// `POSTAL  ID` 的两个空格来自设计稿（`POSTAL&nbsp;&nbsp;ID`），不要顺手改成
/// 一个空格；`UMID(...)` 的括号内外也没有多余空格。
const _recommendedIdTypes = <String>[
  'PRC ID',
  'SSS ID',
  'PHILIPPINE PASSPORT',
  'POSTAL  ID',
  'UMID(Unified Multi-Purpose ID)',
];

/// 其他证件类型（设计稿 `section_4`）。
const _otherIdTypes = <String>[
  "DRIVER'S LICENSE",
  'STUDENT CARD',
  'TIN  ID',
  "Voter's ID",
  'PhilHealth ID',
];

/// 头图高度（设计稿 `section_1`，375x213）。
const _headerHeight = 213.0;

/// 卡片比头图底边高出的部分（设计稿 `text-wrapper_4` 的 `top: -19`）：
/// 白色标题块压在头图下沿上，让头图不被生硬截断。
const _cardOverlap = 19.0;

/// 两张卡片之间的间距（设计稿 `section_3` 底边 483 -> `text-wrapper_4` 顶边 495）。
const _groupGap = 12.0;

/// 页面底部留白（设计稿卡片底边 784 -> 页面底边 812）。
const _pageBottom = 28.0;

/// 证件选择页（蓝湖稿 `03 - 认证流程模块`），认证流程第一步。
///
/// 页面分三段，与设计稿一一对应：
/// 1. 通栏头图（`section_1`）：绿色渐变 + 「ID Verification」大标题 + 吉祥物，
///    全部烘焙在切图 `id_verify_header.png` 里；返回按钮与导航标题浮在头图上。
/// 2. `Recommended ID Type` 卡片（`section_3`）：5 个推荐证件。
/// 3. `Other Options` 卡片（`section_4`）：5 个备选证件。
///
/// 证件类型是客户端固定清单（设计稿写死的文案），不请求接口，因此页面没有
/// Loading / Error / Empty 态；选中证件后的上传页尚未搭建，点击先给占位提示。
class IdVerificationPage extends StatelessWidget {
  const IdVerificationPage({super.key});

  /// 选中证件类型。
  ///
  /// TODO(页面): 证件上传页（正面 / 反面 + 拍摄引导）尚未搭建，先弹占位提示。
  /// TODO(埋点): 选择证件类型需要在 Firebase Analytics 上报事件。
  void _onIdTypeSelected(String idType) {
    ToastHelper.showMessage('$idType is not available yet');
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Scaffold(
      // 设计稿 `page` 底色 `rgba(245,245,245)`。
      backgroundColor: AppColors.idVerifyBackground,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Stack(
              children: [
                // 头图通栏：宽度铺满，高度按 375pt 设计稿等比换算。
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    AppAssets.idVerifyHeader,
                    height: layout.px(_headerHeight),
                    fit: BoxFit.cover,
                  ),
                ),
                Column(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _IdTypeGroup(
                            layout: layout,
                            title: _recommendedTitle,
                            types: _recommendedIdTypes,
                            onSelected: _onIdTypeSelected,
                          ),
                          SizedBox(height: layout.px(_groupGap)),
                          _IdTypeGroup(
                            layout: layout,
                            title: _otherOptionsTitle,
                            types: _otherIdTypes,
                            onSelected: _onIdTypeSelected,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 导航浮层固定在头图上：设计稿内容正好一屏放得下，小屏滚动时返回按钮
          // 也不能跟着滚出屏幕，否则用户没有出口。
          _NavBar(layout: layout, onBack: () => AppNavigator.pop()),
        ],
      ),
    );
  }
}

/// 顶部返回按钮 + 导航标题（设计稿 `block_2`）。
class _NavBar extends StatelessWidget {
  const _NavBar({required this.layout, required this.onBack});

  final AppLayout layout;
  final VoidCallback onBack;

  /// 图标 24x24（设计稿 `label_1`）。
  static const _iconSize = 24.0;

  /// 点击热区：设计稿只标了 24pt 图标，真机上太小，热区补到 40x40。
  static const _tapSize = 40.0;

  /// 图标相对安全区的位置（设计稿 `label_1`：x=16，y=54；
  /// 状态栏 `block_1` 占 16+17，导航 `block_2` 再下移 21）。
  static const _iconLeft = 16.0;
  static const _iconTop = 10.0;

  /// 导航行高度：热区不能超出父容器（超出后收不到点击），这里按热区算。
  static const _height = _iconTop + (_tapSize + _iconSize) / 2;

  @override
  Widget build(BuildContext context) {
    // 热区以图标为中心，左右各多出 (_tapSize - _iconSize) / 2。
    final inset = (_tapSize - _iconSize) / 2;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: layout.px(_height),
        child: Stack(
          children: [
            // 标题居中于整页宽度（设计稿 `text_3` 居中，左右并不跟随返回按钮）。
            Center(
              child: Text(
                _navTitle,
                style: TextStyle(
                  color: AppColors.sectionTitle,
                  fontSize: layout.px(17),
                  fontWeight: FontWeight.w600,
                  // 设计稿：`font-size: 17px; line-height: 24px`。
                  height: 24 / 17,
                ),
              ),
            ),
            Positioned(
              left: layout.px(_iconLeft - inset),
              top: layout.px(_iconTop - inset),
              child: SizedBox(
                width: layout.px(_tapSize),
                height: layout.px(_tapSize),
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: Center(
                      child: Image.asset(
                        AppAssets.back,
                        width: layout.px(_iconSize),
                        height: layout.px(_iconSize),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
            borderRadius: layout.radius(AppSpacing.radiusBanner),
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
