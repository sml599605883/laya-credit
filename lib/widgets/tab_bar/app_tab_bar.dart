import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_tab_item.dart';

/// 底部导航（Home / Stats / Mine）。
///
/// 蓝湖稿（02-01 首页 / 07-01 个人中心）：一枚悬浮的深色胶囊，
/// 内部横向排三个圆形按钮，选中态是柠檬绿实心圆 + 深色图标。
/// 设计稿没有整条底栏的底色，胶囊直接浮在页面底色上。
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// 设计稿几何（375pt 基准）：胶囊 200x48、圆角 24、内边距 4、按钮 40pt。
  static const _pillWidth = 200.0;
  static const _pillHeight = 48.0;
  static const _pillPadding = 4.0;

  /// 胶囊底边与安全区之间的间距。
  static const _bottomGap = 24.0;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      key: const Key('app-tab-bar'),
      // 只保留胶囊 + 下间距所需的高度，其余页面内容照常滚动到这条线以上。
      height: layout.px(_pillHeight + _bottomGap) + bottomInset,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: layout.px(_pillWidth),
          height: layout.px(_pillHeight),
          padding: layout.edgeInsets(left: _pillPadding, right: _pillPadding),
          decoration: BoxDecoration(
            color: AppColors.tabBarPill,
            borderRadius: layout.radius(_pillHeight / 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.08),
                blurRadius: layout.px(20),
                offset: Offset(0, layout.px(6)),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppTabItem(
                key: const Key('tab-home'),
                label: 'Home',
                activeIcon: AppAssets.tabHomeActive,
                inactiveIcon: AppAssets.tabHomeInactive,
                selected: currentIndex == 0,
                onTap: () => onSelected(0),
              ),
              AppTabItem(
                key: const Key('tab-stats'),
                label: 'Stats',
                activeIcon: AppAssets.tabStatsActive,
                inactiveIcon: AppAssets.tabStatsInactive,
                selected: currentIndex == 1,
                onTap: () => onSelected(1),
              ),
              AppTabItem(
                key: const Key('tab-mine'),
                label: 'Mine',
                activeIcon: AppAssets.tabMineActive,
                inactiveIcon: AppAssets.tabMineInactive,
                selected: currentIndex == 2,
                onTap: () => onSelected(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
