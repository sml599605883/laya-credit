import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_environment.dart';
import '../core/navigation/app_navigator.dart';
import '../core/ui/toast_helper.dart';
import '../providers/login_provider.dart';
import '../providers/network_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/back_nav_bar.dart';
import 'widgets/account_retention_dialog.dart';

/// 设置页，入口与 `peso_shield` 对齐：首页、H5、推送等来源下发的设置深链
/// 都落到这里，而不是由各调用页面分别给提示。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = AppLayout.of(context);
    final website = Uri.tryParse(ApiEnvironment.h5Base)?.host ?? '';
    final version = ref.watch(deviceParamsProvider).value?.appVersion ?? '';

    return Scaffold(
      backgroundColor: AppColors.surfaceMint,
      body: Column(
        children: [
          BackNavBar(
            layout: layout,
            title: 'Settings',
            onBack: AppNavigator.pop,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: layout.edgeInsets(
                left: 24,
                top: 32,
                right: 24,
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      AppAssets.mineAvatar,
                      width: layout.px(96),
                      height: layout.px(96),
                    ),
                  ),
                  SizedBox(height: layout.px(32)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: layout.radius(16),
                      border: Border.all(color: AppColors.fieldBorder),
                    ),
                    child: Column(
                      children: [
                        _SettingsRow(
                          layout: layout,
                          label: 'Website',
                          value: website,
                          onTap: website.isEmpty
                              ? null
                              : () => _copyWebsite(website),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.actionSheetDivider,
                        ),
                        _SettingsRow(
                          layout: layout,
                          label: 'APP Version',
                          value: version.isEmpty ? '-' : 'v$version',
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.actionSheetDivider,
                        ),
                        _SettingsRow(
                          layout: layout,
                          label: 'Privacy Agreement',
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.listItemValue,
                          ),
                          onTap: () => AppNavigator.toWebPath<void>(
                            path: AppNavigator.privacyAgreementPath,
                            title: 'Privacy Agreement',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: layout.px(32)),
                  _SettingsButton(
                    layout: layout,
                    label: 'Delete Account',
                    backgroundColor: AppColors.actionSheetGap,
                    foregroundColor: AppColors.actionSheetTextSecondary,
                    onPressed: () => _deleteAccount(context, ref),
                  ),
                  SizedBox(height: layout.px(16)),
                  _SettingsButton(
                    layout: layout,
                    label: 'Log Out',
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    onPressed: () => _logout(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyWebsite(String website) async {
    await Clipboard.setData(ClipboardData(text: website));
    ToastHelper.showMessage('$website copied');
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final wasLoggedIn = ref.read(userSessionProvider).isLoggedIn;
    await showAccountRetentionDialog(
      context: context,
      action: AccountRetentionAction.logout,
      onExit: () async {
        await ref.read(logoutProvider)();
        return true;
      },
    );
    if (context.mounted &&
        wasLoggedIn &&
        !ref.read(userSessionProvider).isLoggedIn) {
      AppNavigator.popToRoot();
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    var deleted = false;
    await showAccountRetentionDialog(
      context: context,
      action: AccountRetentionAction.deleteAccount,
      onExit: () async {
        deleted = await ref.read(deleteAccountProvider)();
        if (!deleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ToastHelper.showError('Delete Account failed, please try again');
          });
        }
        return deleted;
      },
    );
    if (context.mounted && deleted) AppNavigator.popToRoot();
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.layout,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final AppLayout layout;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return InkWell(
      onTap: onTap,
      borderRadius: layout.radius(16),
      child: Padding(
        padding: layout.edgeInsets(left: 16, top: 16, right: 16, bottom: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: layout.px(16),
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.listItemValue,
                    fontSize: layout.px(14),
                  ),
                ),
              ),
            if (trailing != null) ...[SizedBox(width: layout.px(8)), trailing!],
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    required this.layout,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final AppLayout layout;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: layout.px(56),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(borderRadius: layout.radius(25)),
        ),
        child: Text(label, style: TextStyle(fontSize: layout.px(18))),
      ),
    );
  }
}
