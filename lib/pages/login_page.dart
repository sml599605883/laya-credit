import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../providers/login_provider.dart';
import '../theme/theme.dart';

/// 登录页：手机号 + 短信验证码。
///
/// 接口：获取验证码 `POST /outsulk/acarology`，登录 `POST /outsulk/chlorpikrin`。
/// 登录成功后把后端返回的 sessionId 作为登录态写入本地会话。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.onLoginSuccess});

  final Future<void> Function()? onLoginSuccess;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  /// 重发验证码倒计时（秒）。
  static const _resendSeconds = 60;

  /// 手机号长度。文档示例为 9~11 位纯数字，这里只做宽松校验，
  /// 避免把合法号码挡在门外（各市场号段规则不同）。
  static const _minPhoneLength = 9;
  static const _maxPhoneLength = 11;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  Timer? _countdownTimer;
  int _secondsLeft = 0;
  bool _agreed = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _phoneValid {
    final phone = _phoneController.text.trim();
    return phone.length >= _minPhoneLength &&
        phone.length <= _maxPhoneLength &&
        int.tryParse(phone) != null;
  }

  bool get _codeValid => _codeController.text.trim().length >= 4;

  bool get _canSendCode => _phoneValid && _secondsLeft == 0;

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    final sent = await ref
        .read(loginControllerProvider.notifier)
        .sendCode(phone: _phoneController.text.trim());
    if (!mounted) return;
    if (sent) {
      _startCountdown();
      ToastHelper.showMessage('Verification code sent');
    }
  }

  Future<void> _submit() async {
    final result = await ref
        .read(loginControllerProvider.notifier)
        .login(
          phone: _phoneController.text.trim(),
          code: _codeController.text.trim(),
        );
    if (!mounted || result == null) return;

    // TODO(埋点): 登录成功需要上报 Firebase Analytics 事件。
    final onLoginSuccess = widget.onLoginSuccess;
    if (onLoginSuccess != null) await onLoginSuccess();
    if (mounted) AppNavigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final loginState = ref.watch(loginControllerProvider);
    final busy = loginState.isLoading;

    // 请求失败统一转成 Toast，页面本身不吞异常。
    ref.listen(loginControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null || next.isLoading) return;
      ToastHelper.showError(switch (error) {
        ApiException(:final message) when message.isNotEmpty => message,
        _ => 'Request failed, please try again',
      });
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(),
      body: ListView(
        padding: layout.edgeInsets(
          left: AppSpacing.pageHorizontal,
          right: AppSpacing.pageHorizontal,
          bottom: AppSpacing.xl,
        ),
        children: [
          Text(
            'Log in',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: layout.px(24),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: layout.px(AppSpacing.xs)),
          Text(
            'Log in or sign up with your mobile number',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: layout.px(13),
            ),
          ),
          SizedBox(height: layout.px(AppSpacing.md)),
          TextField(
            key: const Key('login-phone-field'),
            controller: _phoneController,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            maxLength: _maxPhoneLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Mobile number',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: layout.radius(AppSpacing.radiusSm),
              ),
            ),
          ),
          SizedBox(height: layout.px(AppSpacing.sm)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('login-code-field'),
                  controller: _codeController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Verification code',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: layout.radius(AppSpacing.radiusSm),
                    ),
                  ),
                ),
              ),
              SizedBox(width: layout.px(AppSpacing.sm)),
              SizedBox(
                height: layout.px(56),
                child: OutlinedButton(
                  key: const Key('login-send-code-button'),
                  onPressed: (_canSendCode && !busy) ? _sendCode : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: layout.radius(AppSpacing.radiusSm),
                    ),
                  ),
                  child: Text(
                    _secondsLeft > 0 ? '${_secondsLeft}s' : 'Get code',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: layout.px(AppSpacing.xs)),
          Row(
            children: [
              Checkbox(
                key: const Key('login-agreement-checkbox'),
                value: _agreed,
                activeColor: AppColors.primary,
                onChanged: busy
                    ? null
                    : (value) => setState(() => _agreed = value ?? false),
              ),
              const Expanded(
                child: Text('I have read and agree to the Privacy Policy'),
              ),
            ],
          ),
          SizedBox(height: layout.px(AppSpacing.md)),
          SizedBox(
            height: layout.px(44),
            child: FilledButton(
              key: const Key('login-submit-button'),
              // 金融 App 的关键提交按钮：条件不满足或请求进行中一律禁用，避免重复提交。
              onPressed: (_agreed && _phoneValid && _codeValid && !busy)
                  ? _submit
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: layout.radius(AppSpacing.radiusMd),
                ),
              ),
              child: busy
                  ? SizedBox(
                      width: layout.px(20),
                      height: layout.px(20),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Text('Log in'),
            ),
          ),
        ],
      ),
    );
  }
}
