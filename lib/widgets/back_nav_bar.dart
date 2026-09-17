import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 二级页顶部返回按钮 + 居中导航标题（蓝湖稿 `block_2`）。
///
/// 设计稿把返回图标放在 `left: 16, top: 54`（375pt 基准），标题居中于**整页宽度**，
/// 左右并不跟随返回按钮。真机安全区比设计稿的状态栏（17 + 21）高，所以图标落在
/// 「安全区 + 10pt」处；点击热区补到 40x40（设计稿只标了 24pt 图标）。
class BackNavBar extends StatelessWidget {
  const BackNavBar({
    required this.layout,
    required this.title,
    required this.onBack,
    super.key,
  });

  final AppLayout layout;
  final String title;
  final VoidCallback onBack;

  /// 图标 24x24（设计稿 `label_1`）。
  static const _iconSize = 24.0;

  /// 点击热区：设计稿只标了 24pt 图标，真机上太小，热区补到 40x40。
  static const _tapSize = 40.0;

  /// 图标相对安全区的位置（设计稿 `label_1`：x=16，y=54。
  /// 设计稿状态栏占 16+17，导航 `block_2` 再下移 21，折算出「安全区 + 10pt」）。
  static const _iconLeft = 16.0;
  static const _iconTop = 10.0;

  /// 导航行高度（不含安全区）：热区不能超出父容器（超出后收不到点击），这里按热区算。
  static const height = _iconTop + (_tapSize + _iconSize) / 2;

  @override
  Widget build(BuildContext context) {
    // 热区以图标为中心，左右各多出 (_tapSize - _iconSize) / 2。
    final inset = (_tapSize - _iconSize) / 2;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: layout.px(height),
        child: Stack(
          children: [
            Center(
              child: Text(
                title,
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
