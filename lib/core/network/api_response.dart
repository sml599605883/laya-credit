import 'api_protocol.dart';

/// 统一的接口返回包装。业务层只看 [isSuccess] 与 [data]，不关心 HTTP 细节。
class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.message,
    required this.data,
  });

  final int code;
  final String message;
  final T data;

  bool get isSuccess => ApiProtocol.successCodes.contains(code);

  bool get isAuthError => code == ApiProtocol.authErrorCode;
}
