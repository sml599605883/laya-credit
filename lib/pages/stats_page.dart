import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 统计 Tab。
///
/// TODO(设计): 设计稿尚未提供，当前为占位空态。图表库的选型要等设计确认后再定，
/// 不要提前引入第三方图表依赖。
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceMint,
      appBar: AppBar(
        title: const Text('Stats'),
        backgroundColor: AppColors.surfaceMint,
      ),
      body: Center(
        child: Padding(
          padding: layout.edgeInsets(left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppAssets.homeProgressEmpty,
                width: layout.px(140),
                height: layout.px(119),
              ),
              SizedBox(height: layout.px(AppSpacing.md)),
              Text(
                'No records yet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: layout.px(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: layout.px(AppSpacing.xs)),
              Text(
                'Your borrowing history will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: layout.px(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
