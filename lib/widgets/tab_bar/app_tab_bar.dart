import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_tab_item.dart';

/// 底部导航栏（Home / Stats / Mine）。
///
/// 视觉参数来自蓝湖切图取色（切图 `navigation/tab_bar_background.png`）：
/// 深色底槽 + 浅绿胶囊选中态。设计稿给全后如需换成整图背景，
/// 直接替换这里的 DecoratedBox 即可，页面不需要改。
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      key: const Key('app-tab-bar'),
      height: layout.px(56) + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      color: AppColors.tabBarTrack,
      child: Row(
        children: [
          AppTabItem(
            label: 'Home',
            activeIcon: AppAssets.tabHomeActive,
            inactiveIcon: AppAssets.tabHomeInactive,
            selected: currentIndex == 0,
            onTap: () => onSelected(0),
          ),
          AppTabItem(
            label: 'Stats',
            activeIcon: AppAssets.tabStatsActive,
            inactiveIcon: AppAssets.tabStatsInactive,
            selected: currentIndex == 1,
            onTap: () => onSelected(1),
          ),
          AppTabItem(
            label: 'Mine',
            activeIcon: AppAssets.tabMineActive,
            inactiveIcon: AppAssets.tabMineInactive,
            selected: currentIndex == 2,
            onTap: () => onSelected(2),
          ),
        ],
      ),
    );
  }
}
