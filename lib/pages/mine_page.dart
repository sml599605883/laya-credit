import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/app_deep_link.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/personal_center_data.dart';
import '../providers/login_provider.dart';
import '../providers/personal_center_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/remote_image.dart';
import '../widgets/state_views.dart';

/// 个人中心（对应蓝湖稿 07-01）。
///
/// 接口：`GET /outsulk/interoscillate`。服务入口列表（客服、投诉、设置等）
/// 由后端下发，客户端不写死，避免调整入口就要发版。
class MinePage extends ConsumerWidget {
  const MinePage({super.key, this.isActive = true});

  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = AppLayout.of(context);
    final session = ref.watch(userSessionProvider);
    final centerAsync = ref.watch(personalCenterProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceMint,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.read(personalCenterProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: layout.edgeInsets(
              top: AppSpacing.xs,
              bottom: AppSpacing.xl,
            ),
            children: [
              _ProfileHeader(
                layout: layout,
                phone: session.phone,
                isLoggedIn: session.isLoggedIn,
                hasRedPoint: centerAsync.value?.hasRedPoint ?? false,
              ),
              SizedBox(height: layout.px(AppSpacing.md)),
              _OrderCard(layout: layout),
              SizedBox(height: layout.px(AppSpacing.md)),
              centerAsync.when(
                loading: () => SizedBox(
                  height: layout.px(160),
                  child: const LoadingView(),
                ),
                error: (error, _) => SizedBox(
                  height: layout.px(160),
                  child: ErrorView(
                    message: switch (error) {
                      ApiException(:final message) => message,
                      _ => 'Failed to load, please try again',
                    },
                    onRetry: () =>
                        ref.read(personalCenterProvider.notifier).refresh(),
                  ),
                ),
                data: (center) => Column(
                  children: [
                    if (center.services.isNotEmpty) ...[
                      _ServiceList(layout: layout, services: center.services),
                      SizedBox(height: layout.px(AppSpacing.md)),
                    ],
                  ],
                ),
              ),
              if (session.isLoggedIn) _LogoutButton(layout: layout),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.layout,
    required this.phone,
    required this.isLoggedIn,
    required this.hasRedPoint,
  });

  final AppLayout layout;
  final String? phone;
  final bool isLoggedIn;
  final bool hasRedPoint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.edgeInsets(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Image.asset(
            AppAssets.mineAvatar,
            width: layout.px(48),
            height: layout.px(48),
          ),
          SizedBox(width: layout.px(AppSpacing.sm)),
          Expanded(
            child: Text(
              isLoggedIn && phone != null && phone!.isNotEmpty
                  ? phone!
                  : 'Log in to continue',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: layout.px(18),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                AppAssets.mineMessage,
                width: layout.px(24),
                height: layout.px(24),
                color: AppColors.textPrimary,
              ),
              if (hasRedPoint)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: layout.px(8),
                    height: layout.px(8),
                    decoration: const BoxDecoration(
                      color: AppColors.bannerEnd,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 订单入口卡片。状态取值见文档：4 全部 / 7 进行中 / 6 待还款 / 5 已结清。
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.layout});

  final AppLayout layout;

  static const _entries = <(String, String, OrderFilterStatus)>[
    ('All', AppAssets.orderAll, OrderFilterStatus.all),
    ('To repay', AppAssets.orderOutstanding, OrderFilterStatus.toRepay),
    ('Settled', AppAssets.orderSettled, OrderFilterStatus.settled),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.edgeInsets(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.orderCardStart, AppColors.orderCardEnd],
          ),
          borderRadius: layout.radius(AppSpacing.radiusMd),
        ),
        child: Padding(
          padding: layout.edgeInsets(top: AppSpacing.md, bottom: AppSpacing.md),
          child: Row(
            children: [
              for (final (label, icon, status) in _entries)
                Expanded(
                  child: InkWell(
                    // TODO(页面): 订单列表页尚未搭建。
                    onTap: () => ToastHelper.showMessage(
                      'Orders: ${status.name} (${status.value})',
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          icon,
                          width: layout.px(28),
                          height: layout.px(28),
                          color: AppColors.white,
                        ),
                        SizedBox(height: layout.px(AppSpacing.xs)),
                        Text(
                          label,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: layout.px(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.layout, required this.services});

  final AppLayout layout;
  final List<ServiceEntry> services;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: layout.edgeInsets(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: layout.radius(AppSpacing.radiusMd),
        ),
        child: Column(
          children: [
            for (final (index, service) in services.indexed) ...[
              if (index > 0) const Divider(height: 1, indent: 56),
              _ServiceRow(layout: layout, service: service),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.layout, required this.service});

  final AppLayout layout;
  final ServiceEntry service;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(service),
      child: Padding(
        padding: layout.edgeInsets(
          left: AppSpacing.sm,
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Row(
          children: [
            RemoteImage(
              url: service.iconUrl,
              width: layout.px(24),
              height: layout.px(24),
              fit: BoxFit.contain,
            ),
            SizedBox(width: layout.px(AppSpacing.sm)),
            Expanded(
              child: Text(
                service.title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: layout.px(14),
                ),
              ),
            ),
            Image.asset(
              AppAssets.chevronRight,
              width: layout.px(7),
              height: layout.px(11),
            ),
          ],
        ),
      ),
    );
  }

  void _open(ServiceEntry service) {
    final target = service.target;
    if (target.isEmpty) {
      ToastHelper.showMessage('${service.title} is not available');
      return;
    }
    // TODO(页面): H5 用 WebView 打开，原生路由走 AppNavigator / 深链解析。
    ToastHelper.showMessage(
      '${service.title}: ${service.isH5 ? 'H5' : 'native'} $target',
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: layout.edgeInsets(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
      ),
      child: SizedBox(
        height: layout.px(44),
        child: OutlinedButton(
          key: const Key('mine-logout-button'),
          onPressed: () async {
            // TODO(埋点): 退出登录需要上报埋点。
            await ref.read(logoutProvider)();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(
              borderRadius: layout.radius(AppSpacing.radiusMd),
            ),
          ),
          child: const Text('Log out'),
        ),
      ),
    );
  }
}
