import '../../core/network/api_fields.dart';

/// 验证码登录/注册的返回结果。
class LoginResult {
  const LoginResult({
    required this.sessionId,
    required this.phone,
    required this.realName,
    required this.isOldUser,
    required this.smsMaxId,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      // 文档：rear 即登录态，后续请求以公共参数 sessionId 带上。
      sessionId: json[ApiFields.sessionId]?.toString() ?? '',
      phone: json[ApiFields.username]?.toString() ?? '',
      realName: json[ApiFields.realName]?.toString() ?? '',
      isOldUser: json[ApiFields.isOldUser]?.toString() == '1',
      smsMaxId: json[ApiFields.smsMaxId]?.toString() ?? '',
    );
  }

  final String sessionId;
  final String phone;
  final String realName;

  /// 是否老用户（0 表示本次注册）。
  final bool isOldUser;

  /// 短信验证码的最大可用 ID，用于后续校验。
  final String smsMaxId;

  bool get isValid => sessionId.isNotEmpty;
}
