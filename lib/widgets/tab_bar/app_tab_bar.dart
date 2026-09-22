import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_tab_item.dart';

/// 底部导航（Home / Progress / Mine）。
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

  /// 悬浮导航会盖住的高度：胶囊 + 胶囊与安全区之间的间距。
  ///
  /// 根 Scaffold 用 `extendBody: true`，页面内容一直铺到屏幕底部、从胶囊下方穿过，
  /// 因此**每个 Tab 页的滚动容器都要把这个高度加到自己的底部内边距上**，
  /// 否则最后一条内容会藏在胶囊后面滚不出来。
  ///
  /// 安全区高度取 `View.viewPadding`（物理像素换算成逻辑像素）而不是
  /// `MediaQuery.viewPadding`：`extendBody` 下 Scaffold 会把 body 的底部内边距抹成 0，
  /// 用 MediaQuery 会少算一个安全区高度。
  static double overlapHeight(BuildContext context) {
    final view = View.of(context);
    final safeBottom = view.viewPadding.bottom / view.devicePixelRatio;
    return AppLayout.of(context).px(_pillHeight + _bottomGap) + safeBottom;
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return SizedBox(
      key: const Key('app-tab-bar'),
      height: overlapHeight(context),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          key: const Key('app-tab-bar-pill'),
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
                key: const Key('tab-progress'),
                label: 'Progress',
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
