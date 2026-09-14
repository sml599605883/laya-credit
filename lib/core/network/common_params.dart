import 'api_protocol.dart';

/// 每个请求都要带的公共参数（终端标识 + 设备信息 + 渠道 + 登录态 + 时间戳）。
///
/// 注意：这里**不包含**公共混淆字段 `stith`，也不包含签名本身——
/// 两者都不参与签名，由 [HttpClient] 在签名之后补进请求参数。
///
/// ⚠️ 签名覆盖的参数必须与实际下发的参数**完全一致**：后端是拿收到的参数重算
/// 签名的，多签一个没下发的字段就会被判成 `code 400`（联调时已实测）。
/// 因此 `gruelled` 虽然文档标注「已弃用，不传此字段」，但加签示例里有它，
/// 就照发照签——少了它同样会 400。
abstract final class CommonParams {
  static Map<String, Object?> create({
    required String deviceId,
    required String market,
    required String appVersion,
    required String deviceName,
    required String osVersion,
    required String advertisingId,
    String? sessionId,
  }) {
    return {
      ApiProtocol.clientType: ApiProtocol.clientTypeValue,
      ApiProtocol.appVersion: appVersion,
      ApiProtocol.deviceName: deviceName,
      ApiProtocol.deviceId: deviceId,
      ApiProtocol.osVersion: osVersion,
      ApiProtocol.market: market,
      ApiProtocol.sessionId: sessionId ?? '',
      ApiProtocol.advertisingId: advertisingId,
      ApiProtocol.timestamp: '${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  /// 拼出签名原文的入参：公参 + 接口路径。
  ///
  /// 文档加签规则：字段按 key 升序排序后，把「键名 + 值」直接拼接，
  /// 再用服务端下发的 verifySecretKey 做 HMAC-SHA256。
  static Map<String, Object?> signable(
    Map<String, Object?> commonParams,
    String path,
  ) {
    return {...commonParams, ApiProtocol.signaturePath: path};
  }
}
