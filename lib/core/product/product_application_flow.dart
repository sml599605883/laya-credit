import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/product_apply_result.dart';
import '../../data/models/product_detail.dart';
import '../../data/repositories/product_repository.dart';
import '../../theme/app_colors.dart';
import '../navigation/app_deep_link.dart';
import '../permissions/permission_coordinator.dart';
import '../report/report.dart';
import '../navigation/app_navigator.dart';
import '../navigation/app_route_generator.dart';
import '../navigation/app_routes.dart';
import '../network/api_exception.dart';
import '../session/session_store.dart';
import '../ui/toast_helper.dart';

/// 产品申请流程协调器（参考 peso_shield 的 `ProductApplicationFlow`）。
///
/// 首页大卡 / 推荐卡 / banner 的「立即申请」都走这里，统一处理：
/// 登录校验 → 准入接口 → 结果分发（跳转 / 产品详情 → 下一步认证 / 借款确认）。
///
/// 认证页面与 WebView 尚未搭建，相关分支先给用户明确提示，页面补齐后在
/// [_openCertificationStep] / [_openWebPage] 里接对应路由即可。
/// 认证项 `taskType`：身份认证（证件选择 / 上传）。
///
/// 取值是后端混淆串，取值表见 [ProductNextStep.taskType] 的说明。
const _taskTypeIdentity = 'Kegful';

/// 认证项 `taskType`：活体（人脸识别）。
const _taskTypeFace = 'Reargued';

/// 认证项 `taskType`：个人信息。
const _taskTypePersonal = 'FlintiestDevwsor';

/// 认证项 `taskType`：工作信息。
const _taskTypeWork = 'TrussvilleUninstructively';

/// 认证项 `taskType`：紧急联系人。
const _taskTypeEmergencyContact = 'Thriftiness';

/// 认证项 `taskType`：绑卡（打款账户）。
const _taskTypeBindCard = 'Bespattered';

class ProductApplicationFlow {
  ProductApplicationFlow({
    required this.repository,
    required this.isLoggedIn,
    required this.sessionStore,
  });

  final ProductRepository repository;

  /// 调用时读取登录态（不要缓存，避免登录后流程层拿着旧值）。
  final bool Function() isLoggedIn;

  /// 产品详情里下发的各页文案要缓存给后续页面用，所以流程层持有会话存储。
  final SessionStore sessionStore;

  /// 防止用户连点导致重复发起准入。
  bool _isProcessing = false;

  /// 「立即申请」前的定位检查入口，默认真跑系统权限、测试可替换
  /// （对齐 dali 的 `NavigationHelper.certificationLocationRequester`）。
  @visibleForTesting
  static Future<CertificationLocationDecision> Function() locationChecker =
      _defaultLocationChecker;

  static Future<CertificationLocationDecision> _defaultLocationChecker() =>
      PermissionCoordinator.instance.requestCertificationLocation();

  /// 执行产品申请流程。
  ///
  /// [apiRemind] 来源标识（0 默认，1 首页 banner，2 首页弹窗 ...）。
  Future<void> applyProduct({
    required String productId,
    int apiRemind = 0,
  }) async {
    if (_isProcessing) return;

    // 未登录先引导登录，登录成功后由用户再次点击（与 peso_shield 一致）。
    if (!isLoggedIn()) {
      await AppNavigator.toLogin();
      return;
    }

    // 对齐 dali：点击「立即申请」时先做定位检查（系统授权弹窗与「去设置」引导
    // 只在这里出现），拿不到定位就中止本次申请，别去打扰后端。
    if (!await _ensureLocationAccess()) return;

    _isProcessing = true;
    try {
      ToastHelper.showLoading();
      // 定位与设备上报是旁路，不阻塞准入接口（与 dali 一致）。
      unawaited(
        ReportService.current?.reportLocationAndDevice() ??
            Future<void>.value(),
      );
      final response = await repository.applyProduct(
        productId: productId,
        apiRemind: apiRemind,
      );
      ToastHelper.hideLoading();

      if (!response.isSuccess) {
        ToastHelper.showError(response.message);
        return;
      }

      await _handleAdmissionResult(response.data, productId);
    } on ApiException catch (error) {
      ToastHelper.hideLoading();
      ToastHelper.showError(error.message);
    } catch (error) {
      ToastHelper.hideLoading();
      ToastHelper.showError('Request failed, please try again');
    } finally {
      _isProcessing = false;
    }
  }

  /// 「立即申请」前的定位检查（对齐 dali 的 `_ensureLocationAccess`）。
  ///
  /// 返回 false 表示中止本次申请：本次拒绝授权、服务关闭或永久拒绝后选择
  /// 去设置。用户取消「去设置」引导时按 dali 口径放行，保证不误伤申请。
  Future<bool> _ensureLocationAccess() async {
    final decision = await locationChecker();
    if (decision == CertificationLocationDecision.granted) return true;
    if (decision == CertificationLocationDecision.denied) return false;

    final openSettings = await _showLocationSettingsPrompt(
      serviceDisabled:
          decision == CertificationLocationDecision.serviceDisabled,
    );
    if (openSettings) {
      await openAppSettings();
      return false;
    }
    return true;
  }

  /// 定位不可用时的系统设置引导框（标题 / 文案对齐 dali）。
  Future<bool> _showLocationSettingsPrompt({
    required bool serviceDisabled,
  }) async {
    final context = AppNavigator.navigatorKey.currentContext;
    if (context == null) return false;
    try {
      final result = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(
            serviceDisabled
                ? 'Turn On Location Services'
                : 'Allow Location Access',
          ),
          content: Text(
            serviceDisabled
                ? 'To help us confirm your identity and safeguard your '
                      'account against unauthorized access, please enable '
                      'Location Services on your device to continue.'
                : "We couldn't verify your location because permission is "
                      'disabled. Please allow location access in your device '
                      'settings to continue your application.',
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
              child: const Text('Settings'),
            ),
          ],
        ),
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 拉取产品详情；失败返回 null（已经弹过提示）。
  Future<ProductDetail?> fetchProductDetail(String productId) async {
    try {
      ToastHelper.showLoading();
      final response = await repository.getProductDetail(productId: productId);
      ToastHelper.hideLoading();

      if (!response.isSuccess) {
        ToastHelper.showError(response.message);
        return null;
      }
      // 详情里的认证页文案在进入对应页面前先落到缓存，认证页直接读，不用再传参。
      // `overwhelming` 里每个认证页一条：`splendacious` 给上传页、
      // `bocking` 给证件信息确认页、`seisin` 给人脸识别页、
      // `deerherd` 给个人信息认证页、`ssn` 给工作信息认证页。
      sessionStore.saveProductDetailIdentityPrompt(
        response.data.identityPrompt,
      );
      sessionStore.saveProductDetailIdentitySuccessPrompt(
        response.data.identitySuccessPrompt,
      );
      sessionStore.saveProductDetailLivenessPrompt(
        response.data.livenessPrompt,
      );
      sessionStore.saveProductDetailPersonalPrompt(
        response.data.personalInfoPrompt,
      );
      sessionStore.saveProductDetailWorkPrompt(response.data.workInfoPrompt);
      sessionStore.saveProductDetailEmergencyContactPrompt(
        response.data.emergencyContactPrompt,
      );
      sessionStore.saveProductDetailBindCardPrompt(
        response.data.bindCardPrompt,
      );
      sessionStore.saveProductDetailBindCardBottomPrompt(
        response.data.bindCardBottomPrompt,
      );
      return response.data;
    } on ApiException catch (error) {
      ToastHelper.hideLoading();
      ToastHelper.showError(error.message);
      return null;
    } catch (error) {
      ToastHelper.hideLoading();
      ToastHelper.showError('Failed to load product details');
      return null;
    }
  }

  /// 深链直接落到「产品详情」时继续认证流程。
  Future<void> continueProductDetailFlow(String productId) async {
    if (productId.isEmpty) {
      ToastHelper.showError('Invalid link');
      return;
    }
    final detail = await fetchProductDetail(productId);
    if (detail == null) return;
    await _continueFromDetail(detail, productId);
  }

  /// 处理准入结果（对照接口文档「点击申请」的几种返回）。
  Future<void> _handleAdmissionResult(
    ProductApplyResult result,
    String productId,
  ) async {
    // 有跳转地址：失败 / 重新授信 / 借款中，统一按地址分发。
    if (result.hasJump) {
      await _openJump(result.jumpUrl, result.jumpType, productId);
      return;
    }

    // 准入成功且没有跳转地址，继续拉产品详情走认证。
    if (result.isAdmitted) {
      final detail = await fetchProductDetail(productId);
      if (detail == null) return;
      await _continueFromDetail(detail, productId);
      return;
    }

    ToastHelper.showError(
      result.message.isNotEmpty
          ? result.message
          : 'Admission failed, please try again',
    );
  }

  /// 根据产品详情继续处理：还有认证项就跳认证页，全部完成就进借款确认。
  Future<void> _continueFromDetail(
    ProductDetail detail,
    String productId,
  ) async {
    final step = detail.nextStep;
    if (step.taskType.isNotEmpty) {
      _openCertificationStep(step, productId, detail.basicInfo.orderNo);
      return;
    }
    await _openConfirmLoanPage(detail, productId);
  }

  /// 下一步认证项。
  ///
  /// `taskType` 取值（接口文档「产品详情认证项目列表」，混淆后）：
  /// `Kegful`=身份 / `Reargued`=活体 / `FlintiestDevwsor`=个人信息 /
  /// `TrussvilleUninstructively`=工作 / `Thriftiness`=紧急联系人 / `Bespattered`=绑卡。
  void _openCertificationStep(
    ProductNextStep step,
    String productId,
    String orderNo,
  ) {
    // 身份认证：证件选择页已按蓝湖稿 `03 - 认证流程模块` 落地。
    // 证件类型由后端按产品下发（`GET /outsulk/gaonate`），页面自己按 productId 拉。
    if (step.taskType == _taskTypeIdentity) {
      AppNavigator.push(
        AppRoutes.idVerification,
        arguments: IdVerificationPageArguments(
          productId: productId,
          orderNo: orderNo,
        ),
      );
      return;
    }

    // 活体（人脸识别）：token 接口要订单号，从产品详情带下去，页面不再自己拉详情。
    // 进入新的认证项用顶层跳转，清掉前面的证件页，返回时直接回入口页。
    if (step.taskType == _taskTypeFace) {
      AppNavigator.pushTopLevelCertification(
        AppRoutes.faceVerification,
        arguments: FaceVerificationPageArguments(
          productId: productId,
          orderNo: orderNo,
        ),
      );
      return;
    }

    // 个人信息：字段与选项全部由后端下发，页面只按描述渲染。
    if (step.taskType == _taskTypePersonal) {
      AppNavigator.pushTopLevelCertification(
        AppRoutes.personalInfo,
        arguments: PersonalInfoPageArguments(
          productId: productId,
          orderNo: orderNo,
        ),
      );
      return;
    }

    // 工作信息：与个人信息同一套 UI，切到工作信息的数据源 / 保存接口。
    if (step.taskType == _taskTypeWork) {
      AppNavigator.pushTopLevelCertification(
        AppRoutes.workInfo,
        arguments: WorkInfoPageArguments(
          productId: productId,
          orderNo: orderNo,
        ),
      );
      return;
    }

    // 紧急联系人：条数与关系选项全部由后端下发，页面只按描述渲染。
    if (step.taskType == _taskTypeEmergencyContact) {
      AppNavigator.pushTopLevelCertification(
        AppRoutes.emergencyContact,
        arguments: EmergencyContactPageArguments(
          productId: productId,
          orderNo: orderNo,
        ),
      );
      return;
    }

    // 绑卡：打款方式分组与字段描述全部由后端下发，页面只按描述渲染。
    // 提交后若后端要求活体（`code == 20000`），页面用产品详情的订单号取 token。
    if (step.taskType == _taskTypeBindCard) {
      AppNavigator.pushTopLevelCertification(
        AppRoutes.bindCard,
        arguments: BindCardPageArguments(
          productId: productId,
          orderNo: orderNo,
        ),
      );
      return;
    }

    final title = step.title.isEmpty ? 'certification' : step.title;
    ToastHelper.showMessage('Please complete $title');
  }

  /// 认证全部完成后，用订单信息换确认用款 H5 地址并打开。
  ///
  /// 口径对齐 peso_shield 的 `_continueFromDetail`：所有认证项做完后调
  /// `getOrderJumpUrl` 拿地址进 WebView，**不是**进原生账号列表页。
  /// 原生 `LoanConfirmPage`（账号列表）是「更换打款账户」页，只由订单详情
  /// H5 桥（`WebViewPage._changeOrderAccount`）与进度卡 `Change` 进入。
  Future<void> _openConfirmLoanPage(
    ProductDetail detail,
    String productId,
  ) async {
    final info = detail.basicInfo;
    if (info.orderNo.isEmpty) {
      ToastHelper.showError('Order information is missing');
      return;
    }

    try {
      ToastHelper.showLoading();
      // 风控埋点场景 9（开始申贷）：开始时间是 <跟进订单号获取跳转地址> 的
      // 请求时间，结束时间是接口响应成功。与 Dali 一致，接口一返回就上报。
      final startedAtSeconds = ReportService.nowSeconds();
      final response = await repository.getOrderPushUrl(
        orderNo: info.orderNo,
        amount: info.amount,
        loanTerm: info.loanTerm,
        termType: info.termType,
      );
      ToastHelper.hideLoading();

      unawaited(
        ReportService.current?.reportRisk(
              productId: productId.isNotEmpty ? productId : info.productId,
              scene: '9',
              orderNo: info.orderNo,
              startedAtSeconds: startedAtSeconds,
            ) ??
            Future<void>.value(),
      );

      if (!response.isSuccess) {
        ToastHelper.showError(response.message);
        return;
      }
      if (response.data.isEmpty) {
        ToastHelper.showError('Jump URL is missing');
        return;
      }
      await _openWebPage(response.data);
    } on ApiException catch (error) {
      ToastHelper.hideLoading();
      ToastHelper.showError(error.message);
    } catch (_) {
      ToastHelper.hideLoading();
      ToastHelper.showError('Request failed, please try again');
    }
  }

  /// 按准入结果里的跳转地址分发。
  ///
  /// 文档：`liquidators=1` 走 H5，`=0` 走原生。原生目标交给
  /// [AppNavigator.openDeepLink] 统一处理，它没有页面承载的目标在这里补后续动作。
  Future<void> _openJump(String target, int jumpType, String productId) async {
    if (jumpType == 1) {
      await _openWebPage(target);
      return;
    }

    await AppNavigator.openDeepLink(
      const AppDeepLinkParser().parse(target),
      onUnhandled: (link) async {
        switch (link.kind) {
          case AppDeepLinkKind.productDetail:
            await continueProductDetailFlow(
              link.productId.isNotEmpty ? link.productId : productId,
            );
          case AppDeepLinkKind.admission:
            // TODO(页面): 准入页（`Isaria`）本身就是本流程，正常不会作为跳转目标下发；
            // 真出现时按新一次申请处理（当前会命中 _isProcessing 防连点，这里先提示）。
            ToastHelper.showMessage('Admission link is not supported here');
          case AppDeepLinkKind.settings:
            // TODO(页面): 设置页尚未搭建。
            ToastHelper.showMessage('Settings page is not available yet');
          case AppDeepLinkKind.unsupported:
            ToastHelper.showError('Invalid link');
          case AppDeepLinkKind.webView:
          case AppDeepLinkKind.home:
          case AppDeepLinkKind.login:
          case AppDeepLinkKind.order:
          case AppDeepLinkKind.recredit:
            // 已由 AppNavigator.openDeepLink 处理，不会回调到这里。
            break;
        }
      },
    );
  }

  /// H5 跳转。
  Future<void> _openWebPage(String url) async {
    if (url.isEmpty) {
      ToastHelper.showError('Invalid link');
      return;
    }
    await AppNavigator.toWebView<void>(url: url);
  }
}
