import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/media/identity_photo_permission.dart';
import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../providers/liveness_provider.dart';
import '../providers/product_flow_provider.dart';
import '../providers/repository_provider.dart';
import '../providers/session_provider.dart';
import '../theme/theme.dart';
import '../widgets/certification_scaffold.dart';
import '../widgets/upload_button.dart';

/// 导航标题（设计稿 `text_10`）。
const _navTitle = 'Face verification';

/// 引导段落相对导航行的下移量（设计稿：段落顶边 112，与证件信息确认页一致）。
const _promptGap = 26.0;

/// 引导段落宽度（设计稿 `text_4 { width: 193px }`）。
const _promptWidth = 193.0;

/// 接口没下发引导文案时的兜底（设计稿 `text_4` 的三行断行）。
///
/// 正常情况走产品详情下发的 `overwhelming.seisin`，这里只在低版本 /
/// 未灰度用户（后端不下发）时兜底。
const _fallbackPrompt =
    'Move naturally, ensure\n'
    'good light. Once passed,\n'
    'your identity is verified.';

/// 示范卡顶边（设计稿 `group_5`：顶边 194，比头图下沿高 19pt）。
const _demoTop = 194.0;

/// 示范卡宽高比（切图 343x420）。
const _demoAspectRatio = 343 / 420;

/// 示范卡与按钮之间的间距（设计稿 614 -> 714）。
const _demoToButtonGap = 100.0;

/// 按钮下沿到页面底边的留白（设计稿 762 -> 812）。
const _buttonBottom = 50.0;

/// 人脸识别页（蓝湖稿 `03-01 - 身份认证-人脸识别`），认证流程的活体项。
///
/// 页面结构与证件上传页一致：通栏头图、引导段落、示范整块切图、底部主按钮。
/// 区别在引导文案取产品详情的 `overwhelming.seisin`，按钮先取活体 token、
/// 再拉起 TrustDecision SDK，最后把抓拍图回传到 `POST /outsulk/fashioned`。
class FaceVerificationPage extends ConsumerStatefulWidget {
  const FaceVerificationPage({
    super.key,
    required this.productId,
    required this.orderNo,
  });

  /// 产品 id，活体通过后继续产品详情的下一步。
  final String productId;

  /// 订单号（token 接口 `resex`），由产品申请流程从产品详情带下来。
  final String orderNo;

  @override
  ConsumerState<FaceVerificationPage> createState() =>
      _FaceVerificationPageState();
}

class _FaceVerificationPageState extends ConsumerState<FaceVerificationPage> {
  /// 活体进行中：挡住按钮，避免同一笔订单重复拉起 SDK。
  bool _isVerifying = false;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    // 引导文案由产品详情 `overwhelming.seisin` 下发，没下发时用设计稿兜底。
    final cachedPrompt = ref
        .watch(sessionStoreProvider)
        .productDetailLivenessPrompt
        .trim();
    final prompt = cachedPrompt.isEmpty ? _fallbackPrompt : cachedPrompt;

    return CertificationScaffold(
      navTitle: _navTitle,
      prompt: prompt,
      promptGap: _promptGap,
      promptWidth: _promptWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: layout.px(_demoTop)),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
            ),
            child: AspectRatio(
              aspectRatio: _demoAspectRatio,
              child: Image.asset(
                AppAssets.faceVerifyDemo,
                fit: BoxFit.fill,
                semanticLabel: prompt,
              ),
            ),
          ),
          SizedBox(height: layout.px(_demoToButtonGap)),
          Padding(
            padding: layout.edgeInsets(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
            ),
            child: UploadButton(
              layout: layout,
              enabled: !_isVerifying,
              onTap: _startVerification,
            ),
          ),
          SizedBox(height: layout.px(_buttonBottom)),
        ],
      ),
    );
  }

  /// 取活体授权码 -> 拉起 SDK -> 回传抓拍图 -> 继续下一步认证。
  Future<void> _startVerification() async {
    if (_isVerifying) return;

    // 先做相机权限预检（对齐 peso_shield）：被拒时弹引导去系统设置，
    // 不浪费一次 token 请求，也不让用户卡在一个没有反馈的按钮上。
    final cameraGranted = await IdentityPhotoPermission.ensureCameraForLiveness(
      context,
    );
    if (!cameraGranted || !mounted) return;

    // TODO(埋点): 点击人脸页主按钮需要在 Firebase Analytics 上报事件。

    if (widget.orderNo.isEmpty) {
      ToastHelper.showError('Order information is missing');
      return;
    }

    setState(() => _isVerifying = true);
    final loading = ToastHelper.showLoading();
    // 抓拍图落在临时目录，上传完（无论成败）都要删掉。
    String? facePath;

    try {
      final repository = await ref.read(certificationRepositoryProvider.future);
      final tokenResponse = await repository.getFaceToken(
        orderNo: widget.orderNo,
      );
      // token 到手就收掉 Loading：后面要么弹确认框、要么拉起 SDK 原生界面，
      // Loading 的转圈动画留着会一直盖在上面（也会让测试的 pumpAndSettle 挂住）。
      loading();
      if (!mounted) return;

      if (!tokenResponse.isSuccess) {
        ToastHelper.showError(tokenResponse.message);
        return;
      }

      final token = tokenResponse.data;
      // `400` 是后端明确要求重新上传身份证，引导用户回认证第一步。
      if (token.needsIdentityResubmit) {
        await _confirmReuploadIdentity();
        return;
      }
      if (!token.canStartLiveness) {
        ToastHelper.showError(
          token.error.isNotEmpty
              ? token.error
              : 'Unable to start face verification',
        );
        return;
      }

      final outcome = await ref.read(livenessGatewayProvider).run(token.token);
      if (!mounted) return;

      if (!outcome.passed) {
        ToastHelper.showError(
          outcome.message.isNotEmpty
              ? outcome.message
              : 'Face verification was not completed',
        );
        return;
      }
      if (!outcome.hasUploadPayload) {
        ToastHelper.showError('Face verification returned incomplete data');
        return;
      }

      facePath = _writeFaceImage(outcome.imageBase64);

      final uploading = ToastHelper.showLoading();
      try {
        final uploadResponse = await repository.uploadFaceImage(
          filePath: facePath,
          livenessId: outcome.livenessId,
          license: token.token,
          livenessType: token.livenessType,
        );
        if (!mounted) return;

        if (!uploadResponse.isSuccess) {
          ToastHelper.showError(
            uploadResponse.message.isNotEmpty
                ? uploadResponse.message
                : 'Face verification upload failed',
          );
          return;
        }
      } finally {
        uploading();
      }

      final flow = await ref.read(productApplicationFlowProvider.future);
      if (mounted) await flow.continueProductDetailFlow(widget.productId);
    } on ApiException catch (error) {
      if (mounted) ToastHelper.showError(error.message);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError('Verification failed, please try again');
      }
    } finally {
      ToastHelper.hideLoading();
      if (facePath != null) {
        try {
          File(facePath).deleteSync();
        } on FileSystemException {
          // 删临时文件失败不影响业务，忽略。
        }
      }
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  /// 后端要求重新上传身份证时的确认弹窗。
  Future<void> _confirmReuploadIdentity() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Upload Your ID Again'),
        content: const Text(
          'Please select your ID type and upload your ID again to continue '
          'verification.',
        ),
        actions: [
          CupertinoDialogAction(
            textStyle: const TextStyle(
              color: AppColors.actionSheetTextSecondary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            textStyle: const TextStyle(color: AppColors.primary),
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: IdVerificationPageArguments(productId: widget.productId),
    );
  }

  /// 把 SDK 回传的 base64 人脸图写到临时文件，交给 multipart 上传。
  ///
  /// 用同步写：人脸抓拍图只有几百 KB，写入耗时远小于一次网络请求，
  /// 却能让这段流程不依赖事件循环，widget 测试里也能跑通。
  String _writeFaceImage(String base64Image) {
    final normalized = base64Image.contains(',')
        ? base64Image.split(',').last
        : base64Image;
    final file = File(
      '${Directory.systemTemp.path}/laya_credit_face_'
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    file.writeAsBytesSync(base64Decode(normalized), flush: true);
    return file.path;
  }
}
