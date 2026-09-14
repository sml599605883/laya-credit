import 'package:dio/dio.dart';

import '../device/device_params.dart';
import 'api_exception.dart';
import 'api_protocol.dart';
import 'api_response.dart';
import 'common_params.dart';
import 'network_config.dart';
import 'obfuscation_helper.dart';
import 'request_signer.dart';
import 'response_protocol.dart';

/// 统一的 HTTP 客户端。
///
/// 职责只有三件事：拼公共参数与签名、解析响应协议、把异常翻译成 [ApiException]。
/// 业务接口放在 `data/repositories/` 下，不要直接依赖 Dio。
class HttpClient {
  HttpClient({
    required NetworkConfig config,
    required this._device,
    required this._getUserToken,
    required this._onAuthExpired,
  }) : _config = config,
       _signer = RequestSigner(config.signSecret) {
    _dio =
        Dio(
            BaseOptions(
              baseUrl: config.apiBase.toString(),
              connectTimeout: config.connectionTimeout,
              receiveTimeout: config.responseTimeout,
              sendTimeout: config.requestTimeout,
              contentType: Headers.formUrlEncodedContentType,
              // 4xx 也交给业务层解析，只有 5xx 当成传输层错误。
              validateStatus: (status) => status != null && status < 500,
            ),
          )
          ..interceptors.add(
            InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
          );
  }

  final NetworkConfig _config;
  final DeviceParams _device;
  final String? Function() _getUserToken;
  final void Function() _onAuthExpired;
  final RequestSigner _signer;

  late final Dio _dio;

  Dio get dio => _dio;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final commonParams = CommonParams.create(
      deviceId: _device.deviceId,
      market: _config.marketIdentifier,
      appVersion: _device.appVersion,
      deviceName: _device.modelName,
      osVersion: _device.systemVersion,
      advertisingId: _device.advertisingId,
      sessionId: _getUserToken(),
    );

    // 签名只覆盖公共参数 + 接口路径，不包含业务参数、混淆字段和签名本身。
    final signature = _signer.sign(
      CommonParams.signable(commonParams, _normalizedPath(options.path)),
    );

    // 混淆字段每次请求随机生成，不参与签名。
    final requestParams = <String, Object?>{
      ...commonParams,
      ApiProtocol.obfuscation: ObfuscationHelper.randomParam(),
      ApiProtocol.signature: signature,
    };

    final businessParams = <String, Object?>{
      if (options.method == 'GET') ...options.queryParameters,
      if (options.method == 'POST' && options.data is Map)
        ...(options.data as Map).cast<String, Object?>(),
    };

    if (options.method == 'GET') {
      options.queryParameters = {...requestParams, ...businessParams};
      options.data = null;
    } else {
      // POST：公共参数与签名走 query，业务参数走 form body。
      options.queryParameters = requestParams;
      options.data = businessParams.isEmpty
          ? null
          : businessParams.cast<String, dynamic>();
    }

    handler.next(options);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    handler.reject(error);
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, Object?>? params,
    required T Function(Object? data) parse,
  }) async {
    return _send(
      () => _dio.get<Map<String, dynamic>>(path, queryParameters: params),
      parse,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    required Map<String, Object?> params,
    required T Function(Object? data) parse,
  }) async {
    return _send(
      () => _dio.post<Map<String, dynamic>>(path, data: params),
      parse,
    );
  }

  Future<ApiResponse<T>> _send<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
    T Function(Object? data) parse,
  ) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await request();
    } on DioException catch (error) {
      throw _toApiException(error);
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 400) {
      throw ApiException(
        type: ApiFailureType.http,
        message: 'HTTP $statusCode',
        statusCode: statusCode,
      );
    }

    final protocol = ResponseProtocol.parse(response.data);
    if (protocol.isAuthError) {
      _onAuthExpired();
      throw const ApiException(
        type: ApiFailureType.authentication,
        message: '登录状态已失效',
      );
    }

    return ApiResponse<T>(
      code: protocol.code,
      message: protocol.message,
      data: parse(protocol.data),
    );
  }

  ApiException _toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          type: ApiFailureType.timeout,
          message: '请求超时，请稍后重试',
          cause: error,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          type: ApiFailureType.noConnection,
          message: '网络连接失败，请检查网络设置',
          cause: error,
        );
      case DioExceptionType.cancel:
        return ApiException(
          type: ApiFailureType.cancelled,
          message: '请求已取消',
          cause: error,
        );
      case DioExceptionType.badResponse:
        return ApiException(
          type: ApiFailureType.http,
          message: 'HTTP ${error.response?.statusCode ?? 0}',
          statusCode: error.response?.statusCode,
          cause: error,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ApiException(
          type: ApiFailureType.unexpected,
          message: '请求失败，请稍后重试',
          cause: error,
        );
    }
  }

  /// 去掉 baseUrl 前缀，得到签名用的相对 path。
  String _normalizedPath(String path) {
    final base = _config.apiBase.toString();
    return path.startsWith(base) ? path.substring(base.length) : path;
  }
}
