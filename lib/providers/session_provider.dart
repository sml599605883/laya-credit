import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// 登录态。页面通过 `ref.watch(userSessionProvider)` 读取，
/// 通过 `ref.read(userSessionProvider.notifier)` 修改。
final userSessionProvider = NotifierProvider<UserSessionNotifier, UserSession>(
  UserSessionNotifier.new,
);

class UserSessionNotifier extends Notifier<UserSession> {
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  UserSession build() => const UserSession();

  /// 从本地恢复会话。启动时调用一次。
  Future<void> restore() async {
    if (state.isRestored) return;
    final restored = await _store.restore();
    // 恢复期间用户可能已经手动登录，不要用旧数据覆盖新状态。
    if (state.isLoggedIn) {
      state = state.copyWith(isRestored: true);
      return;
    }
    state = restored;
  }

  Future<void> setSession({
    required String token,
    required String userId,
    required String phone,
  }) async {
    state = UserSession(
      accessToken: token,
      userId: userId,
      phone: phone,
      isLoggedIn: true,
      isRestored: true,
    );
    await _store.save(token: token, userId: userId, phone: phone);
  }

  /// 退出登录：清除登录态，但保留手机号方便下次预填。
  Future<void> clearSession() async {
    state = UserSession(phone: state.phone, isRestored: true);
    await _store.clear();
  }
}

/// 登录态失效信号。
///
/// 与「用户主动退出登录」区分开：只有 token 过期才需要自动弹出登录页，
/// 主动退出时不应该再弹。
final sessionExpirySignalProvider = Provider<SessionExpirySignal>((ref) {
  final signal = SessionExpirySignal();
  ref.onDispose(signal.dispose);
  return signal;
});

class SessionExpirySignal {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get events => _controller.stream;

  void notifyExpired() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
