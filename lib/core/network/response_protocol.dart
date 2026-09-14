import 'api_protocol.dart';

/// 后端响应体的原始结构（未做业务解析）。
class ResponseProtocol {
  const ResponseProtocol({
    required this.code,
    required this.message,
    required this.data,
  });

  /// 容错解析：结构不符时返回 code = -1，由上层转成 [ApiFailureType.invalidResponse]。
  factory ResponseProtocol.parse(Object? json) {
    if (json is! Map) {
      return const ResponseProtocol(
        code: -1,
        message: 'Invalid response format',
        data: null,
      );
    }

    final rawCode = json[ApiProtocol.codeField];
    final code = rawCode is int ? rawCode : int.tryParse('$rawCode') ?? -1;

    return ResponseProtocol(
      code: code,
      message: json[ApiProtocol.messageField]?.toString() ?? '',
      data: json[ApiProtocol.dataField],
    );
  }

  final int code;
  final String message;
  final Object? data;

  bool get isSuccess => ApiProtocol.successCodes.contains(code);

  bool get isAuthError => code == ApiProtocol.authErrorCode;

  bool get isSignError => code == ApiProtocol.signErrorCode;
}
