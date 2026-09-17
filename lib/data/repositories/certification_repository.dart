import '../../core/network/api_endpoints.dart';
import '../../core/network/api_fields.dart';
import '../../core/network/api_response.dart';
import '../../core/network/http_client.dart';
import '../../core/network/obfuscation_helper.dart';
import '../models/id_verification_data.dart';

/// 认证项相关接口（证件 / 活体 / 个人信息 / 工作 / 紧急联系人 / 绑卡）。
///
/// 目前只接了第一项（证件类型列表），其余认证项按接口文档 `4.certify.html`
/// 在落地对应页面时逐个补到这里。
class CertificationRepository {
  const CertificationRepository(this._client);

  final HttpClient _client;

  /// 获取用户身份信息（认证第一项）：证件类型列表。
  ///
  /// 产品维度下发，页面每次进入都会用 [productId] 拉一次（Provider 里按产品缓存）。
  Future<ApiResponse<IdVerificationData>> getIdentityInfo({
    required String productId,
  }) {
    return _client.get<IdVerificationData>(
      ApiEndpoints.identityInfo,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscateIdentityInfo: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? IdVerificationData.fromJson(data.cast<String, dynamic>())
          : const IdVerificationData(recommended: [], other: []),
    );
  }
}
