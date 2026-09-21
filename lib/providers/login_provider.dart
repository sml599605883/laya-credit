import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/login_result.dart';
import '../data/models/sms_channel_options.dart';
import 'repository_provider.dart';
import 'session_provider.dart';

/// 登录流程。
///
/// 用 [AsyncNotifier] 承载 Loading / Error 状态，页面 `ref.watch` 即可，
/// 不需要在每个页面里自己维护一套 `isLoading`。
final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(
  LoginController.new,
);

class LoginController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// 发送验证码。失败时把异常写进 state，由页面展示 Toast。
  Future<bool> sendCode({
    required String phone,
    SmsChannel channel = SmsChannel.sms,
  }) async {
    state = const AsyncLoading();
    var succeeded = false;
    state = await AsyncValue.guard(() async {
      final repository = await ref.read(authRepositoryProvider.future);
      final response = await repository.sendSmsCode(
        phone: phone,
        channel: channel,
      );
      if (!response.isSuccess) {
        throw ApiException(
          type: ApiFailureType.business,
          message: response.message,
          code: response.code,
        );
      }
      succeeded = true;
    });
    return succeeded;
  }

  /// 验证码登录/注册。成功后将登录态写入 [userSessionProvider]。
  Future<LoginResult?> login({
    required String phone,
    required String code,
  }) async {
    state = const AsyncLoading();
    LoginResult? result;
    state = await AsyncValue.guard(() async {
      final repository = await ref.read(authRepositoryProvider.future);
      final response = await repository.login(phone: phone, code: code);
      if (!response.isSuccess) {
        throw ApiException(
          type: ApiFailureType.business,
          message: response.message,
          code: response.code,
        );
      }

      final data = response.data;
      if (!data.isValid) {
        throw const ApiException(
          type: ApiFailureType.invalidResponse,
          message: '登录返回缺少会话标识',
        );
      }

      await ref
          .read(userSessionProvider.notifier)
          .setSession(
            token: data.sessionId,
            userId: data.smsMaxId,
            phone: data.phone.isNotEmpty ? data.phone : phone,
          );
      result = data;
    });
    return result;
  }
}

/// 登录后主动退出：先通知后端，再清本地登录态。
/// 接口失败不阻塞本地退出——用户点了退出就应该退出。
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      await repository.logout();
    } catch (error) {
      debugPrint('[Logout] 通知后端失败，继续清本地登录态: $error');
    } finally {
      await ref.read(userSessionProvider.notifier).clearSession();
    }
  };
});

/// 注销账号：先通知后端删除账号，成功后再清本地登录态。
///
/// 与 [logoutProvider] 不同，注销失败时**不能**清本地登录态——
/// 后端没删成功就退出会让用户以为账号已注销，属于合规风险。
/// 返回是否注销成功，由页面决定错误提示。
final deleteAccountProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      final response = await repository.deleteAccount();
      if (!response.isSuccess) {
        debugPrint('[DeleteAccount] 后端返回失败: ${response.code}');
        return false;
      }
    } catch (error) {
      debugPrint('[DeleteAccount] 注销失败: $error');
      return false;
    }
    await ref.read(userSessionProvider.notifier).clearSession();
    return true;
  };
});
