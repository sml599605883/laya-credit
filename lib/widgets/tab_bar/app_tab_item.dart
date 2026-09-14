import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// 底部导航的单个 Tab。
class AppTabItem extends StatelessWidget {
  const AppTabItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String activeIcon;
  final String inactiveIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          // 深色底上用 Theme 默认的水波纹几乎看不见，这里显式给一个浅色高亮。
          splashColor: AppColors.surfaceMint.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 选中态：浅色胶囊托底 + 深色图标（切图本身即为深色）。
              Container(
                width: layout.px(48),
                height: layout.px(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.surfaceMint : Colors.transparent,
                  borderRadius: layout.radius(14),
                ),
                child: Image.asset(
                  selected ? activeIcon : inactiveIcon,
                  width: layout.px(24),
                  height: layout.px(24),
                ),
              ),
              SizedBox(height: layout.px(AppSpacing.xs / 2)),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.surfaceMint : AppColors.iconLight,
                  fontSize: layout.px(11),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
