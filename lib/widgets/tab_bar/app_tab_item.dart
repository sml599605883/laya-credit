import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// 底部导航的单个 Tab：一枚圆形按钮（选中为柠檬绿实心，未选中为深灰实心）。
///
/// 设计稿（02-01 / 07-01）只给了圆形按钮 + 图标，没有文字标签，
/// 可读性由 [Semantics] 提供。
class AppTabItem extends StatelessWidget {
  const AppTabItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// 无障碍标签（不参与视觉）。
  final String label;
  final String activeIcon;
  final String inactiveIcon;
  final bool selected;
  final VoidCallback onTap;

  /// 设计稿：圆形按钮 40pt、图标 24pt。
  static const _circleSize = 40.0;
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final background = selected ? AppColors.actionLime : AppColors.tabItemTrack;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          // 实心圆上的水波纹：深色底用浅色，柠檬绿底用深色。
          splashColor: (selected ? AppColors.black : AppColors.white)
              .withValues(alpha: 0.12),
          child: SizedBox(
            width: layout.px(_circleSize),
            height: layout.px(_circleSize),
            child: Center(
              child: Image.asset(
                // 切图自带颜色：选中态是深色图标，未选中态是白色线框图标。
                selected ? activeIcon : inactiveIcon,
                width: layout.px(_iconSize),
                height: layout.px(_iconSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
