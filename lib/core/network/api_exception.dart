/// 失败类型。UI 层按它决定展示哪种状态（网络错误页 / 重试 / Toast）。
enum ApiFailureType {
  /// 业务失败：后端返回了非成功状态码。
  business,

  /// 登录态失效。
  authentication,

  /// 本地配置有问题（如 baseUrl 未配置）。
  configuration,

  /// 请求超时。
  timeout,

  /// 无网络 / 连不上。
  noConnection,

  /// 请求被取消。
  cancelled,

  /// HTTP 层错误（4xx / 5xx）。
  http,

  /// 响应体不是预期结构。
  invalidResponse,

  /// 其它未预期错误。
  unexpected,
}

/// 网络层统一抛出的异常。所有 API 调用都必须能 catch 到它，
/// 金融 App 不允许因为接口异常导致闪退。
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.code,
    this.statusCode,
    this.cause,
  });

  final ApiFailureType type;
  final String message;
  final int? code;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'ApiException($type, $message)';
}
