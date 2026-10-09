import '../../core/network/api_endpoints.dart';
import '../../core/network/api_fields.dart';
import '../../core/network/api_response.dart';
import '../../core/network/http_client.dart';
import '../../core/network/obfuscation_helper.dart';
import '../models/login_result.dart';

/// 账号相关接口（登录/注册、验证码、退出登录）。
class AuthRepository {
  const AuthRepository(this._client);

  final HttpClient _client;

  /// 验证码发送渠道。当前只支持短信，后端字段按协议原样上送。
  static const _smsChannel = 'sms';

  /// 获取登录/注册短信验证码。
  Future<ApiResponse<void>> sendSmsCode({required String phone}) {
    return _client.post<void>(
      ApiEndpoints.sendSmsCode,
      params: {
        ApiFields.phone: phone,
        ApiFields.channel: _smsChannel,
        ApiFields.obfuscateSendSms: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// 验证码登录/注册。返回的 sessionId 即登录态。
  Future<ApiResponse<LoginResult>> login({
    required String phone,
    required String code,
  }) {
    return _client.post<LoginResult>(
      ApiEndpoints.smsLogin,
      params: {
        ApiFields.username: phone,
        ApiFields.smsCode: code,
        ApiFields.obfuscateLogin1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateLogin2: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? LoginResult.fromJson(data.cast<String, dynamic>())
          : const LoginResult(
              sessionId: '',
              phone: '',
              realName: '',
              isOldUser: false,
              smsMaxId: '',
            ),
    );
  }

  /// 退出登录。
  Future<ApiResponse<void>> logout() {
    return _client.get<void>(
      ApiEndpoints.logout,
      params: {
        ApiFields.obfuscateLogout1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateLogout2: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// 注销账号。接口文档「注销账号」（`/outsulk/norseled`）。
  Future<ApiResponse<void>> deleteAccount() {
    return _client.get<void>(
      ApiEndpoints.deleteAccount,
      params: {
        ApiFields.obfuscateDeleteAccount: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }
}
