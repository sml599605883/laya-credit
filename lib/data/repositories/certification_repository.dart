import '../../core/media/identity_photo.dart';
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

  /// 上传身份证正面照（multipart），返回后端 OCR 识别出的信息。
  ///
  /// 文档「接口上传(face,身份证正面)（第一项）」：固定 `liquidators=11`（身份证正面），
  /// 卡类型取证件选择页的行文案，来源区分相册 / 拍照。
  Future<ApiResponse<Map<String, dynamic>>> uploadIdentityImage({
    required String filePath,
    required String cardType,
    required IdentityPhotoSource source,
  }) {
    return _client.upload<Map<String, dynamic>>(
      ApiEndpoints.uploadIdentityImage,
      filePath: filePath,
      fileField: ApiFields.uploadFileField,
      fields: {
        ApiFields.uploadType: '11',
        ApiFields.uploadImageSource: source.code,
        ApiFields.uploadCardType: cardType,
        // 身份证正面用不到活体参数，但后端要求字段存在，空串也要带上。
        ApiFields.uploadLivenessId: '',
        ApiFields.uploadLivenessLicense: '',
        ApiFields.uploadFaceType: '',
        ApiFields.uploadBizId: '',
      },
      parse: (data) =>
          data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
    );
  }
}
