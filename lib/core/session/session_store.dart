import 'package:shared_preferences/shared_preferences.dart';

import 'user_session.dart';

/// 登录态本地持久化。
///
/// 读写失败不向调用方抛异常：登录态丢失只影响体验，不应该让 App 启动失败。
class SessionStore {
  SessionStore({SharedPreferencesAsync? preferences}) : _injected = preferences;

  static const _tokenKey = 'laya_credit.session.access_token';
  static const _userIdKey = 'laya_credit.session.user_id';
  static const _phoneKey = 'laya_credit.session.phone';

  final SharedPreferencesAsync? _injected;
  SharedPreferencesAsync? _resolved;
  bool _resolveFailed = false;

  /// 产品详情下发的证件上传页引导文案（`overwhelming.splendacious`）。
  ///
  /// 只在内存里缓存：产品详情在进入认证流程前一定会先拉一次，
  /// 上传页拿不到时用设计稿兜底文案即可，不需要跨启动持久化。
  String _productDetailIdentityPrompt = '';

  String get productDetailIdentityPrompt => _productDetailIdentityPrompt;

  /// 写入产品详情下发的身份认证引导文案。
  void saveProductDetailIdentityPrompt(String prompt) {
    _productDetailIdentityPrompt = prompt.trim();
  }

  /// 产品详情下发的证件信息确认页引导文案（`overwhelming.bocking`）。
  ///
  /// 与上传页的 `splendacious` 一样只在内存里缓存：产品详情一定先于认证页拉取。
  String _productDetailIdentitySuccessPrompt = '';

  String get productDetailIdentitySuccessPrompt =>
      _productDetailIdentitySuccessPrompt;

  /// 写入产品详情下发的证件信息确认页引导文案。
  void saveProductDetailIdentitySuccessPrompt(String prompt) {
    _productDetailIdentitySuccessPrompt = prompt.trim();
  }

  /// 产品详情下发的人脸（活体）认证页引导文案（`overwhelming.seisin`）。
  ///
  /// 与另外两条认证页文案一样只在内存里缓存：产品详情一定先于认证页拉取。
  String _productDetailLivenessPrompt = '';

  String get productDetailLivenessPrompt => _productDetailLivenessPrompt;

  /// 写入产品详情下发的人脸认证引导文案。
  void saveProductDetailLivenessPrompt(String prompt) {
    _productDetailLivenessPrompt = prompt.trim();
  }

  /// 平台实现可能没有注册（例如单元测试环境）。拿不到实例时所有读写退化为空操作，
  /// 不能因为本地存储不可用就让 App 启动失败。
  SharedPreferencesAsync? get _preferences {
    final injected = _injected;
    if (injected != null) return injected;
    if (_resolved != null || _resolveFailed) return _resolved;
    try {
      return _resolved = SharedPreferencesAsync();
    } catch (_) {
      _resolveFailed = true;
      return null;
    }
  }

  /// 读取已保存的会话。手机号独立于 token 恢复：未登录时也要带上，登录页才能预填。
  Future<UserSession> restore() async {
    try {
      final preferences = _preferences;
      if (preferences == null) return const UserSession(isRestored: true);

      final token = _normalize(await preferences.getString(_tokenKey));
      final phone = _normalize(await preferences.getString(_phoneKey));
      if (token == null) {
        return UserSession(phone: phone, isRestored: true);
      }
      return UserSession(
        accessToken: token,
        userId: _normalize(await preferences.getString(_userIdKey)),
        phone: phone,
        isLoggedIn: true,
        isRestored: true,
      );
    } catch (_) {
      return const UserSession(isRestored: true);
    }
  }

  Future<void> save({
    required String token,
    required String userId,
    required String phone,
  }) async {
    try {
      final preferences = _preferences;
      if (preferences == null) return;
      await preferences.setString(_tokenKey, token);
      await preferences.setString(_userIdKey, userId);
      await preferences.setString(_phoneKey, phone);
    } catch (_) {
      // 持久化失败时保留内存态，下次启动重新登录即可。
    }
  }

  /// 清除 token，保留手机号方便下次登录预填。
  Future<void> clear() async {
    _productDetailIdentityPrompt = '';
    _productDetailIdentitySuccessPrompt = '';
    try {
      final preferences = _preferences;
      if (preferences == null) return;
      await preferences.remove(_tokenKey);
      await preferences.remove(_userIdKey);
    } catch (_) {
      // 忽略清除失败。
    }
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
