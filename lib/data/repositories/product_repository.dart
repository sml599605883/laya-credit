import '../../core/network/api_endpoints.dart';
import '../../core/network/api_fields.dart';
import '../../core/network/api_response.dart';
import '../../core/network/http_client.dart';
import '../../core/network/obfuscation_helper.dart';
import '../models/product_apply_result.dart';
import '../models/product_detail.dart';

/// 产品申请相关接口：准入、产品详情、借款确认跳转。
class ProductRepository {
  const ProductRepository(this._client);

  final HttpClient _client;

  /// 文档标注「已弃用」的固定参数，照发。
  static const _moduleId = '1001';
  static const _position = '1000';
  static const _subModuleId = '1000';

  /// 点击申请（准入）。[apiRemind] 是来源标识，默认 0。
  Future<ApiResponse<ProductApplyResult>> applyProduct({
    required String productId,
    int apiRemind = 0,
  }) {
    return _client.post<ProductApplyResult>(
      ApiEndpoints.productApply,
      params: {
        ApiFields.applyModuleId: _moduleId,
        ApiFields.applyPosition: _position,
        ApiFields.applySubModuleId: _subModuleId,
        ApiFields.productId: productId,
        ApiFields.apiRemind: apiRemind.toString(),
        ApiFields.obfuscateApply1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateApply2: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? ProductApplyResult.fromJson(data.cast<String, dynamic>())
          : const ProductApplyResult(
              statusCode: 0,
              jumpUrl: '',
              jumpType: 0,
              message: '',
            ),
    );
  }

  /// 产品详情（认证项列表 / 下一步）。
  Future<ApiResponse<ProductDetail>> getProductDetail({
    required String productId,
  }) {
    return _client.post<ProductDetail>(
      ApiEndpoints.productDetail,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscateDetail1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateDetail2: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateDetail3: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? ProductDetail.fromJson(data.cast<String, dynamic>())
          : const ProductDetail(
              resultCode: 0,
              basicInfo: ProductBasicInfo(),
              nextStep: ProductNextStep(),
            ),
    );
  }

  /// 认证完成后，用订单信息换借款确认页地址。
  Future<ApiResponse<String>> getOrderPushUrl({
    required String orderNo,
    required String amount,
    required String loanTerm,
    required String termType,
  }) {
    return _client.post<String>(
      ApiEndpoints.productPush,
      params: {
        ApiFields.orderNo: orderNo,
        ApiFields.amount: amount,
        ApiFields.detailTerm: loanTerm,
        ApiFields.detailTermType: termType,
        ApiFields.obfuscatePush1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscatePush2: ObfuscationHelper.randomParam(),
        ApiFields.obfuscatePush3: ObfuscationHelper.randomParam(),
        ApiFields.obfuscatePush4: ObfuscationHelper.randomParam(),
      },
      parse: (data) =>
          data is Map ? data[ApiFields.jumpUrl]?.toString() ?? '' : '',
    );
  }
}
