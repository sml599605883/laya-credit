import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/app_colors.dart';

/// 认证流程的相机权限。
///
/// 相册取图在 iOS 14+ 走 PHPicker，系统不需要相册权限，所以这里只管相机。
/// 权限被拒绝时弹一次说明并引导去系统设置，不让用户卡在一个没有反馈的按钮上。
class IdentityPhotoPermission {
  IdentityPhotoPermission._();

  /// 申请相机权限；拿到返回 true，被拒绝时返回 false（已经弹过引导）。
  ///
  /// 权限框架本身异常（例如插件未注册）时按「未授权」处理：
  /// 认证流程宁可什么都不做，也不能因为权限调用把整个页面顶崩。
  static Future<bool> ensureCamera(BuildContext context) {
    return _ensureCamera(
      context,
      title: 'Camera access needed',
      content:
          'Please allow camera access so you can photograph your ID. '
          'You can also pick an existing photo from your album.',
      cancelLabel: 'Not now',
      confirmLabel: 'Open settings',
    );
  }

  /// 活体（人脸识别）前的相机权限预检，口径对齐 peso_shield 的
  /// `PermissionHelper.showCameraPermissionDialog`（拒绝时引导去系统设置）。
  static Future<bool> ensureCameraForLiveness(BuildContext context) {
    return _ensureCamera(
      context,
      title: 'Enable Camera to Continue',
      content:
          "We can't complete identity verification without camera access. "
          'Enable the permission to continue your application securely.',
      cancelLabel: 'Not Now',
      confirmLabel: 'Allow',
    );
  }

  static Future<bool> _ensureCamera(
    BuildContext context, {
    required String title,
    required String content,
    required String cancelLabel,
    required String confirmLabel,
  }) async {
    final PermissionStatus status;
    try {
      // 先看当前状态：已授权直接放行，永久拒绝不再重复弹系统框（对齐 peso_shield）。
      final current = await Permission.camera.status;
      status = current.isGranted ? current : await Permission.camera.request();
    } catch (_) {
      return false;
    }
    if (status.isGranted || status.isLimited) return true;

    if (!context.mounted) return false;
    final goToSettings = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            textStyle: const TextStyle(
              color: AppColors.actionSheetTextSecondary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            textStyle: const TextStyle(color: AppColors.primary),
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (goToSettings ?? false) {
      await openAppSettings();
    }
    return false;
  }
}
