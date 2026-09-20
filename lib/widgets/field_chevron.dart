import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 表单取值行尾的深色箭头（设计稿 `路径 2` / `thumbnail_3`，6x10）。
///
/// 个人信息 / 工作信息 / 紧急联系人三稿的行尾箭头是同一张切图
/// （设计稿实测描边色 `rgba(24,28,23,1)`），但 `assets/` 里没有对应文件，
/// 按设计稿尺寸用画笔还原，颜色走 [AppColors.personalInfoFieldChevron]。
class FieldChevron extends StatelessWidget {
  const FieldChevron({required this.layout, super.key});

  final AppLayout layout;

  static const _width = 6.0;
  static const _height = 10.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: layout.px(_width),
      height: layout.px(_height),
      child: CustomPaint(
        painter: const _FieldChevronPainter(
          color: AppColors.personalInfoFieldChevron,
        ),
      ),
    );
  }
}

class _FieldChevronPainter extends CustomPainter {
  const _FieldChevronPainter({required this.color});

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
  bool shouldRepaint(_FieldChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}
