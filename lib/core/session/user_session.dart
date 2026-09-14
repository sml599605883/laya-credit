/// 登录态。整个 App 只依赖这个模型判断「是否已登录 / 用哪个 token」。
class UserSession {
  const UserSession({
    this.accessToken,
    this.userId,
    this.phone,
    this.isLoggedIn = false,
    this.isRestored = false,
  });

  final String? accessToken;
  final String? userId;
  final String? phone;
  final bool isLoggedIn;

  /// 是否已完成本地恢复。启动阶段用它区分「未登录」和「还没读出来」。
  final bool isRestored;

  UserSession copyWith({
    String? accessToken,
    String? userId,
    String? phone,
    bool? isLoggedIn,
    bool? isRestored,
  }) {
    return UserSession(
      accessToken: accessToken ?? this.accessToken,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isRestored: isRestored ?? this.isRestored,
    );
  }
}
