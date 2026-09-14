import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 把 375pt 的设计稿尺寸换算成当前屏幕尺寸。
///
/// 上限 [maxScale] 用来避免平板上把固定尺寸等比放大到全屏宽度后纵向溢出。
class AppLayout {
  const AppLayout._(this.scale);

  /// 设计稿基准宽度。
  static const designWidth = 375.0;

  /// 最大缩放系数。
  static const maxScale = 1.2;

  final double scale;

  factory AppLayout.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final layoutWidth = math.min(math.max(width, 1), designWidth * maxScale);
    return AppLayout._(layoutWidth / designWidth);
  }

  /// 把设计稿上的 pt 值换算成当前设备上的逻辑像素。
  double px(num value) => value * scale;

  EdgeInsets edgeInsets({
    num left = 0,
    num top = 0,
    num right = 0,
    num bottom = 0,
  }) => EdgeInsets.fromLTRB(px(left), px(top), px(right), px(bottom));

  BorderRadius radius(num value) =>
      BorderRadius.all(Radius.circular(px(value)));
}
