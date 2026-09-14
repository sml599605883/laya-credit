import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 加载中。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.onDark = false});

  /// 深色背景页面需要浅色指示器。
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: onDark ? AppColors.surfaceMint : AppColors.primary,
      ),
    );
  }
}

/// 请求失败。金融 App 不允许闪退，任何接口异常都要落到这里并给出重试入口。
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    required this.onRetry,
    super.key,
    this.onDark = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final titleColor = onDark ? AppColors.surfaceMint : AppColors.textPrimary;

    return Center(
      child: Padding(
        padding: layout.edgeInsets(left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: layout.px(48),
              color: titleColor,
            ),
            SizedBox(height: layout.px(AppSpacing.sm)),
            Text(
              message.isEmpty ? 'Something went wrong' : message,
              textAlign: TextAlign.center,
              style: TextStyle(color: titleColor, fontSize: layout.px(14)),
            ),
            SizedBox(height: layout.px(AppSpacing.md)),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: titleColor,
                side: BorderSide(color: titleColor.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: layout.radius(AppSpacing.radiusMd),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
