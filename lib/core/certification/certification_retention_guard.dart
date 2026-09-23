import 'package:flutter/material.dart';

import '../../data/models/certification_retention.dart';
import '../../data/repositories/certification_repository.dart';
import '../../pages/widgets/certification_retention_dialog.dart';
import '../ui/toast_helper.dart';

/// 认证流程的挽留弹窗类型（接口文档「获取挽留弹窗」的 `lazy`）。
abstract final class CertificationRetentionType {
  /// 身份认证（证件选择 / 上传 / 确认）。
  static const identity = '0';

  /// 人脸（活体）。
  static const face = '1';

  /// 个人信息。
  static const personal = '2';

  /// 工作信息。
  static const work = '3';

  /// 紧急联系人。
  static const emergencyContact = '4';

  /// 确认用款（借款确认页 / 待确认用款 H5）。
  static const loanConfirm = '5';
}

/// 认证流程各页返回时的「挽留」拦截（参考 dali_cash 的 `CertificationRetentionGuard`）。
///
/// 页面按下返回（顶部返回按钮或系统返回手势）时不要直接 pop，先走 [handleBack]：
/// 调 `POST /outsulk/curitiba` 拿挽留素材，拿到就弹窗让用户二次确认；
/// 素材缺失或接口异常时**必须**直接放行 [onExit]——挽留是锦上添花，
/// 不能让接口问题把用户卡在认证页里出不去。
class CertificationRetentionGuard {
  CertificationRetentionGuard({
    required this.repository,
    void Function()? showLoading,
    void Function()? hideLoading,
  }) : _showLoading = showLoading ?? ToastHelper.showLoading,
       _hideLoading = hideLoading ?? ToastHelper.hideLoading;

  final CertificationRepository repository;

  /// 请求在途时的全局 Loading 遮罩。
  ///
  /// 默认走 [ToastHelper]；测试可换成空实现，避免把认证流程的返回拦在
  /// BotToast 这个全局单例上（对齐 `homeLoadingIndicatorProvider` 的做法）。
  final void Function() _showLoading;
  final void Function() _hideLoading;

  /// 请求在途 / 弹窗展示中：忽略重复的返回触发。
  bool _handling = false;

  Future<void> handleBack({
    required BuildContext context,
    required String productId,
    required String type,
    required VoidCallback onExit,
  }) async {
    if (_handling) return;
    // 没有产品 id 就没有挽留素材可拉（例如深链进来的脏参数），直接返回。
    if (productId.trim().isEmpty) {
      onExit();
      return;
    }

    _handling = true;
    try {
      final retention = await _load(productId: productId, type: type);
      if (!context.mounted) return;
      if (retention == null) {
        onExit();
        return;
      }
      await showCertificationRetentionDialog(
        context: context,
        retention: retention,
        onExit: onExit,
      );
    } finally {
      _handling = false;
    }
  }

  /// 拉挽留素材；任何异常都收敛成「没有挽留」，由调用方退回默认返回。
  ///
  /// Loading 只盖住这一次请求：弹窗自己要长时间停留，
  /// 遮罩留到弹窗关掉才收会让弹窗上一直叠着转圈的 Loading。
  Future<CertificationRetention?> _load({
    required String productId,
    required String type,
  }) async {
    _showLoading();
    try {
      final response = await repository.getRetentionPopup(
        productId: productId,
        type: type,
      );
      if (!response.isSuccess) return null;
      return response.data.hasImage ? response.data : null;
    } catch (error) {
      debugPrint('[CertificationRetention] 挽留弹窗素材获取失败: $error');
      return null;
    } finally {
      _hideLoading();
    }
  }
}
