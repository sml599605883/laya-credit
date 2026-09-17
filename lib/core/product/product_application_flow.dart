import '../../data/models/product_apply_result.dart';
import '../../data/models/product_detail.dart';
import '../../data/repositories/product_repository.dart';
import '../navigation/app_deep_link.dart';
import '../navigation/app_navigator.dart';
import '../navigation/app_routes.dart';
import '../network/api_exception.dart';
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

class ProductApplicationFlow {
  ProductApplicationFlow({required this.repository, required this.isLoggedIn});

  final ProductRepository repository;

  /// 调用时读取登录态（不要缓存，避免登录后流程层拿着旧值）。
  final bool Function() isLoggedIn;

  /// 防止用户连点导致重复发起准入。
  bool _isProcessing = false;

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

    _isProcessing = true;
    try {
      ToastHelper.showLoading();
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
      _openCertificationStep(step, productId);
      return;
    }
    await _openLoanConfirm(detail, productId);
  }

  /// 下一步认证项。
  ///
  /// `taskType` 取值（接口文档「产品详情认证项目列表」，混淆后）：
  /// `Kegful`=身份 / `Reargued`=活体 / `FlintiestDevwsor`=个人信息 /
  /// `TrussvilleUninstructively`=工作 / `Thriftiness`=紧急联系人 / `Bespattered`=绑卡。
  void _openCertificationStep(ProductNextStep step, String productId) {
    // 身份认证：证件选择页已按蓝湖稿 `03 - 认证流程模块` 落地。
    // 证件类型是客户端固定清单，页面不再请求接口，所以这里不需要下发数据；
    // 选中证件后的上传页要按产品维度取资料，补齐时再把 productId 透传过去。
    if (step.taskType == _taskTypeIdentity) {
      AppNavigator.push(AppRoutes.idVerification);
      return;
    }

    // TODO(页面): 活体（`Reargued`）/ 个人信息 / 工作 / 紧急联系人 / 绑卡页尚未搭建。
    final title = step.title.isEmpty ? 'certification' : step.title;
    ToastHelper.showMessage('Please complete $title');
  }

  /// 认证全部完成后，用订单信息换借款确认页地址。
  Future<void> _openLoanConfirm(ProductDetail detail, String productId) async {
    final info = detail.basicInfo;
    if (info.orderNo.isEmpty) {
      ToastHelper.showError('Order information is missing');
      return;
    }

    try {
      ToastHelper.showLoading();
      final response = await repository.getOrderPushUrl(
        orderNo: info.orderNo,
        amount: info.amount,
        loanTerm: info.loanTerm,
        termType: info.termType,
      );
      ToastHelper.hideLoading();

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
    } catch (error) {
      ToastHelper.hideLoading();
      ToastHelper.showError('Request failed, please try again');
    }
  }

  /// 按准入结果里的跳转地址分发。
  Future<void> _openJump(String target, int jumpType, String productId) async {
    // 文档：liquidators=1 走 H5，=0 走原生。
    if (jumpType == 1) {
      await _openWebPage(target);
      return;
    }

    final link = const AppDeepLinkParser().parse(target);
    switch (link.kind) {
      case AppDeepLinkKind.webView:
        await _openWebPage(link.url);
      case AppDeepLinkKind.home:
        AppNavigator.popToRoot();
      case AppDeepLinkKind.login:
        await AppNavigator.toLogin();
      case AppDeepLinkKind.productDetail:
        await continueProductDetailFlow(
          link.productId.isNotEmpty ? link.productId : productId,
        );
      case AppDeepLinkKind.admission:
        // TODO(页面): 准入页（`Isaria`）本身就是本流程，正常不会作为跳转目标下发；
        // 真出现时按新一次申请处理（当前会命中 _isProcessing 防连点，这里先提示）。
        ToastHelper.showMessage('Admission link is not supported here');
      case AppDeepLinkKind.order:
        // TODO(页面): 订单列表页尚未搭建。
        ToastHelper.showMessage('Order page is not available yet');
      case AppDeepLinkKind.settings:
        // TODO(页面): 设置页尚未搭建。
        ToastHelper.showMessage('Settings page is not available yet');
      case AppDeepLinkKind.recredit:
        // TODO(页面): 重新授信 loading 页尚未搭建。
        ToastHelper.showMessage('Credit review page is not available yet');
      case AppDeepLinkKind.unsupported:
        ToastHelper.showError('Invalid link');
    }
  }

  /// H5 跳转。
  ///
  /// TODO(页面): WebView 页面尚未搭建（README「其余接口未接入」）。
  /// 落地后这里换成 `AppNavigator.toWebView(url: url)`。
  Future<void> _openWebPage(String url) async {
    if (url.isEmpty) {
      ToastHelper.showError('Invalid link');
      return;
    }
    ToastHelper.showMessage('Web page is not available yet');
  }
}
