import '../../core/network/api_endpoints.dart';
import '../../core/network/api_fields.dart';
import '../../core/network/api_response.dart';
import '../../core/network/http_client.dart';
import '../../core/network/obfuscation_helper.dart';

/// 设备型号查询结果（`POST /outsulk/omphacy`）。
class ReportDeviceInfo {
  const ReportDeviceInfo({this.deviceModel = '', this.physicalSize = ''});

  static const empty = ReportDeviceInfo();

  /// 设备名称（`connectedly.beautifully`），没匹配到时后端返回原文。
  final String deviceModel;

  /// 物理尺寸（`connectedly.squattest`），没匹配到时后端返回 `-1`。
  final String physicalSize;

  bool get isValid => deviceModel.isNotEmpty || physicalSize.isNotEmpty;
}

/// 数据上报相关接口。
///
/// 覆盖接口文档 `6.data-report.html` 的全部上报接口（**不含上报通讯录**）与
/// `4.certify.html#同盾report`。上报失败不应该影响业务流程，因此调用方
/// （[ReportService]）统一吞掉异常。
class ReportRepository {
  const ReportRepository(this._client);

  final HttpClient _client;

  /// 上报位置信息。
  Future<ApiResponse<void>> reportLocation({
    required String province,
    required String countryCode,
    required String country,
    required String street,
    required String latitude,
    required String longitude,
    required String city,
  }) {
    return _client.post<void>(
      ApiEndpoints.reportLocation,
      params: {
        ApiFields.reportProvince: province,
        ApiFields.reportCountryCode: countryCode,
        ApiFields.reportCountry: country,
        ApiFields.reportStreet: street,
        ApiFields.reportLatitude: latitude,
        ApiFields.reportLongitude: longitude,
        ApiFields.reportCity: city,
        ApiFields.obfuscateReportLocation1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateReportLocation2: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// google_market 上报，返回 adjust_token（拿不到时为空串）。
  Future<ApiResponse<String>> reportGoogleMarket({
    required String idfv,
    required String idfa,
  }) {
    return _client.post<String>(
      ApiEndpoints.reportGoogleMarket,
      params: {
        ApiFields.googleMarketIdfv: idfv,
        ApiFields.googleMarketIdfa: idfa,
        ApiFields.obfuscateGoogleMarket: ObfuscationHelper.randomParam(),
      },
      parse: (data) {
        if (data is! Map) return '';
        final token = data[ApiFields.googleMarketAdjustToken];
        return token?.toString().trim() ?? '';
      },
    );
  }

  /// 上报风控埋点。
  Future<ApiResponse<void>> reportRisk({
    required String productId,
    required String sceneType,
    required String orderNo,
    required String riskDeviceId,
    required String idfa,
    required String longitude,
    required String latitude,
    required String startTime,
    required String endTime,
  }) {
    return _client.post<void>(
      ApiEndpoints.reportRisk,
      params: {
        ApiFields.riskProductId: productId,
        ApiFields.riskSceneType: sceneType,
        ApiFields.riskOrderNo: orderNo,
        ApiFields.riskDeviceId: riskDeviceId,
        ApiFields.riskIdfa: idfa,
        ApiFields.riskLongitude: longitude,
        ApiFields.riskLatitude: latitude,
        ApiFields.riskStartTime: startTime,
        ApiFields.riskEndTime: endTime,
        ApiFields.obfuscateRisk: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// 设备信息上报（[encryptedPayload] 已 AES 加密）。
  Future<ApiResponse<void>> reportDeviceInfo({
    required String encryptedPayload,
  }) {
    return _client.post<void>(
      ApiEndpoints.reportDeviceInfo,
      params: {ApiFields.deviceReportPayload: encryptedPayload},
      parse: (_) {},
    );
  }

  /// 上报 Apple 推送 token。
  Future<ApiResponse<void>> reportApplePushToken({required String token}) {
    return _client.post<void>(
      ApiEndpoints.reportApplePushToken,
      params: {ApiFields.applePushToken: token},
      parse: (_) {},
    );
  }

  /// 同盾活体结果上报。
  Future<ApiResponse<void>> reportTrustDecisionResult({
    required String livenessId,
    required String requestId,
    required String resultCode,
    required String result,
  }) {
    return _client.post<void>(
      ApiEndpoints.reportTrustDecision,
      params: {
        ApiFields.trustLivenessId: livenessId,
        ApiFields.trustRequestId: requestId,
        ApiFields.trustResultCode: resultCode,
        ApiFields.trustResult: result,
      },
      parse: (_) {},
    );
  }

  /// 根据设备型号标识查询设备名称 / 物理尺寸。
  Future<ApiResponse<ReportDeviceInfo>> lookupDeviceInfo({
    required String identifier,
  }) {
    return _client.post<ReportDeviceInfo>(
      ApiEndpoints.deviceInfoLookup,
      params: {
        ApiFields.deviceLookupIdentifier: identifier,
        ApiFields.obfuscateDeviceLookup: ObfuscationHelper.randomParam(),
      },
      parse: (data) {
        if (data is! Map) return ReportDeviceInfo.empty;
        return ReportDeviceInfo(
          deviceModel:
              data[ApiFields.deviceLookupName]?.toString().trim() ?? '',
          physicalSize:
              data[ApiFields.deviceLookupPhysicalSize]?.toString().trim() ?? '',
        );
      },
    );
  }
}
