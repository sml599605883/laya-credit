import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 认证流程二级页的**固定**底部操作条（证件上传 / 证件确认 / 人脸识别）。
///
/// 设计稿（`03-01 - 身份认证-*`）的 `Upload` 固定在 812pt 稿的 y 714~762：
/// 按钮高 48、下沿距屏幕底 50pt，去掉 34pt 手势条安全区后按钮下方留 16pt。
/// 这一条不随内容滚动——小屏上内容比一屏高时，用户不用先滚到底才能提交。
///
/// 与个人信息 / 绑卡页那条不同：设计稿这里是页面底色，没有独立白条与投影。
class CertificationBottomBar extends StatelessWidget {
  const CertificationBottomBar({required this.child, super.key});

  /// 按钮下沿与安全区之间的距离（设计稿 pt）。
  static const double _bottomGap = 16.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return ColoredBox(
      color: AppColors.idVerifyBackground,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: layout.edgeInsets(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            bottom: _bottomGap,
          ),
          child: child,
        ),
      ),
    );
  }
}
