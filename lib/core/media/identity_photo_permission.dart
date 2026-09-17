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
  static Future<bool> ensureCamera(BuildContext context) async {
    final PermissionStatus status;
    try {
      status = await Permission.camera.request();
    } catch (_) {
      return false;
    }
    if (status.isGranted || status.isLimited) return true;

    if (!context.mounted) return false;
    final goToSettings = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Camera access needed'),
        content: const Text(
          'Please allow camera access so you can photograph your ID. '
          'You can also pick an existing photo from your album.',
        ),
        actions: [
          CupertinoDialogAction(
            textStyle: const TextStyle(
              color: AppColors.actionSheetTextSecondary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          CupertinoDialogAction(
            textStyle: const TextStyle(color: AppColors.primary),
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open settings'),
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
