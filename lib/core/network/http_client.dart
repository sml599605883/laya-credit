import 'package:dio/dio.dart';

import '../device/device_params.dart';
import 'api_exception.dart';
import 'api_protocol.dart';
import 'api_response.dart';
import 'capture_proxy.dart';
import 'common_params.dart';
import 'network_config.dart';
import 'obfuscation_helper.dart';
import 'proxy_configurer.dart';
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
    CaptureProxySettings? systemProxy,
  }) : _config = config,
       _signer = RequestSigner(config.signSecret) {
    _dio = _createDio(systemProxy);
  }

  final NetworkConfig _config;
  final DeviceParams _device;
  final String? Function() _getUserToken;
  final void Function() _onAuthExpired;
  final RequestSigner _signer;

  late final Dio _dio;

  Dio get dio => _dio;

  Dio _createDio(CaptureProxySettings? systemProxy) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _config.apiBase.toString(),
        connectTimeout: _config.connectionTimeout,
        receiveTimeout: _config.responseTimeout,
        sendTimeout: _config.requestTimeout,
        contentType: Headers.formUrlEncodedContentType,
        // 4xx 也交给业务层解析，只有 5xx 当成传输层错误。
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // `dart:io` 默认不读系统代理，必须显式写进 findProxy 才能被 Charles/Proxyman 抓到。
    // 优先用运行时探测到的系统代理，其次退回编译期配置的固定代理。
    if (systemProxy != null && systemProxy.isValid) {
      ProxyConfigurer.configure(
        dio,
        host: systemProxy.host,
        port: systemProxy.port,
        allowInsecure: true,
      );
    } else if (_config.proxyHost.isNotEmpty && _config.proxyPort != null) {
      ProxyConfigurer.configure(
        dio,
        host: _config.proxyHost,
        port: _config.proxyPort!,
        allowInsecure: _config.allowInsecureProxy,
      );
    }

    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );

    return dio;
  }

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

    // multipart 请求的字段已经装在 FormData 里，不能再当普通 form body 处理，
    // 否则这里会把整个 FormData 覆盖成 null、文件被静默丢掉。
    final isMultipart = options.data is FormData;

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
      if (!isMultipart) {
        options.data = businessParams.isEmpty
            ? null
            : businessParams.cast<String, dynamic>();
      }
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

  /// multipart/form-data 上传单个文件。
  ///
  /// [fields] 是随文件一起提交的业务参数；公共参数与签名仍由拦截器放到 query，
  /// 和普通 POST 保持一致。[fileField] 必须是后端约定的文件字段名。
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    required String fileField,
    required Map<String, Object?> fields,
    required T Function(Object? data) parse,
  }) async {
    final formData = FormData.fromMap({
      ...fields,
      fileField: await MultipartFile.fromFile(filePath),
    });
    return _send(
      () => _dio.post<Map<String, dynamic>>(path, data: formData),
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
