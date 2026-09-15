import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/navigation.dart';
import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../providers/login_provider.dart';
import '../theme/theme.dart';

/// 登录页（蓝湖稿 `01-02 - 登录`）。
///
/// 设计稿给了三个状态，这里都用同一套布局表达：
/// - 默认：手机号/验证码为空，`Log in` 禁用（整颗按钮 50% 透明度）。
/// - 已输入：两位都填了，`Log in` 变实色，发送验证码的位置变成倒计时。
/// - 未勾选协议：按钮可点，点击后浮出提示条 `Please read and agree ...`。
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
  // ---------- 设计稿（375x812）标注值 ----------

  /// 导航栏高度：设计稿标题（y 54~78）的中线正好落在 44pt 导航栏的中线上。
  static const _navBarHeight = 44.0;
  static const _navFontSize = 17.0;
  static const _navLineHeight = 24.0;

  /// 品牌行（设计稿 `box_3`，y 128~176）。
  static const _brandLogoSize = 48.0;
  static const _brandGap = 16.0;
  static const _brandFontSize = 28.0;
  static const _brandLineHeight = 34.0;

  /// 表单卡（设计稿 `编组 8`，339x333）。
  /// 切图里白卡相对底图内缩 10pt，所以卡内边距按 22/21/21/22 摆内容即可对齐。
  static const _cardWidth = 339.0;

  /// 卡片底图是 339x333 的定尺切图，卡高锁死在设计稿尺寸上，避免文案变短后
  /// 卡身跟着内容收缩、把底图纵向压扁；内容更长时仍可撑高。
  static const _cardHeight = 333.0;
  static const _cardPadLeft = 22.0;
  static const _cardPadTop = 22.0;
  static const _cardPadRight = 21.0;
  static const _cardPadBottom = 21.0;
  static const _cardLabelGap = 12.0;
  static const _cardBlockGap = 16.0;
  static const _cardButtonGap = 16.0;
  static const _cardAgreementGap = 12.0;

  /// 字段标题（Please enter mobile number / Verify with SMS Code）。
  static const _labelFontSize = 16.0;
  static const _labelLineHeight = 22.0;

  /// 输入框（296x48，圆角 4，描边 `#EBF0F7`）。
  static const _fieldHeight = 48.0;
  static const _fieldPadHorizontal = 11.0;
  static const _fieldFontSize = 14.0;
  static const _fieldLineHeight = 20.0;
  static const _phoneDividerHeight = 12.0;

  /// 未勾选协议提示条（设计稿绝对定位：left -2 / top 189，相对表单卡）。
  static const _warningLeft = -2.0;
  static const _warningTop = 189.0;
  static const _warningWidth = 343.0;
  static const _warningHeight = 35.0;
  static const _warningPadLeft = 11.0;
  static const _warningPadRight = 15.0;
  static const _warningPadTop = 7.0;
  static const _warningPadBottom = 8.0;

  static const _bannerWidth = 343.0;
  static const _bannerHeight = 120.0;

  /// 设计稿默认态：整颗 `Log in`（底色 + 文案）按 50% 透明度绘制。
  static const _disabledOpacity = 0.5;

  // ---------- 文案 ----------

  static const _appName = 'Maya Agad';
  static const _phoneLabel = 'Please enter mobile number';
  static const _phonePrefix = '+63';
  static const _phoneHint = 'Mobile numbers starting with 9';
  static const _smsLabel = 'Verify with SMS Code';
  static const _smsHint = 'SMS code';
  static const _sendCodeLabel = 'Get it';
  static const _submitLabel = 'Log in';
  static const _agreementLead = 'I have read and agree to the ';
  static const _agreementPrivacy = 'Privacy Policy';
  static const _agreementWarning =
      'Please read and agree to the Privacy Agreement';

  // ---------- 业务参数 ----------

  /// 重发验证码倒计时（秒）。
  static const _resendSeconds = 60;

  /// 手机号长度。文档示例为 9~11 位纯数字，这里只做宽松校验，
  /// 避免把合法号码挡在门外（各市场号段规则不同）。
  static const _minPhoneLength = 9;
  static const _maxPhoneLength = 11;

  /// 验证码位数上限。
  static const _codeMaxLength = 6;

  /// 提示条停留时长，与全局 Toast 保持一致。
  static const _warningDuration = Duration(seconds: 2);

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  Timer? _countdownTimer;
  Timer? _warningTimer;
  int _secondsLeft = 0;

  /// 设计稿默认态是已勾选（01-02 - 登录-默认）。
  bool _agreed = true;
  bool _showAgreementWarning = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _warningTimer?.cancel();
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

  /// 提交按钮是否可用：只看两个字段，协议没勾选时由提交动作给提示。
  bool get _canSubmit => _phoneValid && _codeValid;

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

  /// 浮出「未勾选协议」提示条。
  void _showAgreementTip() {
    _warningTimer?.cancel();
    setState(() => _showAgreementWarning = true);
    _warningTimer = Timer(_warningDuration, () {
      if (!mounted) return;
      setState(() => _showAgreementWarning = false);
    });
  }

  /// 打开协议页。
  ///
  /// TODO(页面): 隐私政策 / 服务条款 H5 页尚未搭建（见 README「遗留问题」），
  /// 沿用二级页占位提示；WebView 落地后改成 AppNavigator.toWebView(...)。
  void _openAgreement(String title) {
    ToastHelper.showMessage('$title is not available');
  }

  Future<void> _submit() async {
    if (!_agreed) {
      _showAgreementTip();
      return;
    }

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

  /// 点空白处收起键盘。Flutter 默认只在桌面端这么做，移动端要自己挂。
  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final busy = ref.watch(loginControllerProvider).isLoading;

    // 键盘只盖住表单区。Banner 那一块（Banner + 间距 + 底部安全区）本来就在
    // 键盘下方，不能再算一遍，否则键盘上方会空出一条。
    final media = MediaQuery.of(context);
    final formBottomInset = math.max(
      0.0,
      media.viewInsets.bottom -
          media.padding.bottom -
          layout.px(_bannerHeight + AppSpacing.md),
    );

    // 请求失败统一转成 Toast，页面本身不吞异常。
    ref.listen(loginControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null || next.isLoading) return;
      ToastHelper.showError(switch (error) {
        ApiException(:final message) when message.isNotEmpty => message,
        _ => 'Request failed, please try again',
      });
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 深色底 → 状态栏用浅色图标（设计稿状态栏为白色）。
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        // body 不跟着键盘重排：否则底部 Banner 会被顶到键盘上方压住表单。
        // 键盘让位交给下面的表单区自己处理。
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          // 空白区域点击收起键盘，子级（输入框 / 按钮 / 协议链接）优先响应。
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  AppAssets.loginBackground,
                  fit: BoxFit.cover,
                  // 光晕在画面顶部，屏幕比例不同于设计稿时裁底部。
                  alignment: Alignment.topCenter,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // 表单区收缩到键盘上沿（键盘矮于 Banner 那一块时收缩到 Banner 上沿），
                    // 屏幕够高时内容自然贴顶；Banner 始终吸在屏幕底部，不被键盘顶起。
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: formBottomInset),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _navBar(layout),
                              SizedBox(height: layout.px(AppSpacing.xl)),
                              _brand(layout),
                              SizedBox(height: layout.px(AppSpacing.md)),
                              _formCard(layout, busy: busy),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _banner(layout),
                    SizedBox(height: layout.px(AppSpacing.md)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部导航栏：只有居中的 App 名。
  Widget _navBar(AppLayout layout) {
    return SizedBox(
      height: layout.px(_navBarHeight),
      child: Center(
        child: Text(
          _appName,
          style: TextStyle(
            color: AppColors.white,
            fontSize: layout.px(_navFontSize),
            height: _navLineHeight / _navFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 品牌行：产品 Logo + 产品名。
  Widget _brand(AppLayout layout) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          AppAssets.loginLogo,
          width: layout.px(_brandLogoSize),
          height: layout.px(_brandLogoSize),
        ),
        SizedBox(width: layout.px(_brandGap)),
        Text(
          _appName,
          style: TextStyle(
            color: AppColors.white,
            fontSize: layout.px(_brandFontSize),
            height: _brandLineHeight / _brandFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// 表单卡：卡片底图 + 手机号 / 验证码 / 提交 / 协议。
  Widget _formCard(AppLayout layout, {required bool busy}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: layout.px(_cardHeight)),
          child: Container(
            width: layout.px(_cardWidth),
            decoration: const BoxDecoration(
              image: DecorationImage(
                // 切图含玻璃层与白卡，白卡相对切图内缩 10pt。
                image: AssetImage(AppAssets.loginCard),
                fit: BoxFit.fill,
              ),
            ),
            padding: layout.edgeInsets(
              left: _cardPadLeft,
              top: _cardPadTop,
              right: _cardPadRight,
              bottom: _cardPadBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_phoneLabel, style: _labelStyle(layout)),
                SizedBox(height: layout.px(_cardLabelGap)),
                _phoneField(layout, busy: busy),
                SizedBox(height: layout.px(_cardBlockGap)),
                Text(_smsLabel, style: _labelStyle(layout)),
                SizedBox(height: layout.px(_cardLabelGap)),
                _smsField(layout, busy: busy),
                SizedBox(height: layout.px(_cardButtonGap)),
                _submitButton(layout, busy: busy),
                SizedBox(height: layout.px(_cardAgreementGap)),
                _AgreementRow(
                  layout: layout,
                  selected: _agreed,
                  onChanged: (selected) => setState(() => _agreed = selected),
                  onPrivacyPolicyTap: () => _openAgreement(_agreementPrivacy),
                ),
              ],
            ),
          ),
        ),
        if (_showAgreementWarning)
          Positioned(
            left: layout.px(_warningLeft),
            top: layout.px(_warningTop),
            width: layout.px(_warningWidth),
            height: layout.px(_warningHeight),
            child: _agreementWarningBar(layout),
          ),
      ],
    );
  }

  /// 手机号输入：`+63 | 号码`。
  Widget _phoneField(AppLayout layout, {required bool busy}) {
    return _fieldShell(
      layout,
      Row(
        children: [
          Text(
            _phonePrefix,
            style: _fieldStyle(
              layout,
              color: AppColors.fieldText,
              weight: FontWeight.w500,
            ),
          ),
          SizedBox(width: layout.px(AppSpacing.xs)),
          Container(
            width: layout.px(1),
            height: layout.px(_phoneDividerHeight),
            color: AppColors.loginLabel,
          ),
          SizedBox(width: layout.px(AppSpacing.xs)),
          Expanded(
            child: TextField(
              key: const Key('login-phone-field'),
              controller: _phoneController,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_maxPhoneLength),
              ],
              onChanged: (_) => setState(() {}),
              cursorColor: AppColors.primary,
              style: _fieldStyle(layout, color: AppColors.fieldText),
              decoration: InputDecoration.collapsed(
                hintText: _phoneHint,
                hintStyle: _fieldStyle(layout, color: AppColors.fieldHint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 验证码输入：右侧是获取验证码 / 重发倒计时。
  Widget _smsField(AppLayout layout, {required bool busy}) {
    final counting = _secondsLeft > 0;

    return _fieldShell(
      layout,
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('login-code-field'),
              controller: _codeController,
              enabled: !busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeMaxLength),
              ],
              onChanged: (_) => setState(() {}),
              cursorColor: AppColors.primary,
              style: _fieldStyle(layout, color: AppColors.fieldText),
              decoration: InputDecoration.collapsed(
                hintText: _smsHint,
                hintStyle: _fieldStyle(layout, color: AppColors.fieldHint),
              ),
            ),
          ),
          SizedBox(width: layout.px(AppSpacing.xs)),
          TextButton(
            key: const Key('login-send-code-button'),
            onPressed: (_canSendCode && !busy) ? _sendCode : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: counting
                  ? AppColors.hintOrange
                  : AppColors.cardValue,
              // 设计稿默认态（手机号还没填）里 `Get it` 也是深色，不置灰。
              disabledForegroundColor: AppColors.cardValue,
            ),
            child: Text(
              counting ? '$_secondsLeft S' : _sendCodeLabel,
              style: _fieldStyle(
                layout,
                color: counting ? AppColors.hintOrange : AppColors.cardValue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 提交按钮。禁用态整颗按钮半透明（设计稿默认态）。
  Widget _submitButton(AppLayout layout, {required bool busy}) {
    return SizedBox(
      width: double.infinity,
      height: layout.px(_fieldHeight),
      child: Opacity(
        opacity: _canSubmit ? 1 : _disabledOpacity,
        child: FilledButton(
          key: const Key('login-submit-button'),
          // 金融 App 的关键提交按钮：请求进行中一律禁用，避免重复提交。
          onPressed: (_canSubmit && !busy) ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.actionLime,
            foregroundColor: AppColors.cardValue,
            disabledBackgroundColor: AppColors.actionLime,
            disabledForegroundColor: AppColors.cardValue,
            padding: EdgeInsets.zero,
            textStyle: _labelStyle(layout).copyWith(color: null),
            shape: RoundedRectangleBorder(
              borderRadius: layout.radius(AppSpacing.radiusLg),
            ),
          ),
          child: busy
              ? SizedBox(
                  width: layout.px(20),
                  height: layout.px(20),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cardValue,
                  ),
                )
              : const Text(_submitLabel),
        ),
      ),
    );
  }

  /// 未勾选协议提示条（设计稿 `形状结合`：343x35，黑 70%）。
  Widget _agreementWarningBar(AppLayout layout) {
    return Container(
      padding: layout.edgeInsets(
        left: _warningPadLeft,
        top: _warningPadTop,
        right: _warningPadRight,
        bottom: _warningPadBottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningBar,
        borderRadius: layout.radius(AppSpacing.radiusToast),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        // 设计稿文案宽度正好占满提示条，换字体后可能超出，
        // 这里宁可等比缩小也不省略号截断。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _agreementWarning,
            maxLines: 1,
            style: TextStyle(
              color: AppColors.white,
              fontSize: layout.px(_fieldFontSize),
              height: _fieldLineHeight / _fieldFontSize,
            ),
          ),
        ),
      ),
    );
  }

  /// 底部运营 Banner（文案已含在切图里）。
  Widget _banner(AppLayout layout) {
    return Image.asset(
      AppAssets.loginBanner,
      width: layout.px(_bannerWidth),
      height: layout.px(_bannerHeight),
    );
  }

  /// 输入框外壳：白底 / 描边 / 圆角 4，固定 48pt 高。
  Widget _fieldShell(AppLayout layout, Widget child) {
    return Container(
      height: layout.px(_fieldHeight),
      padding: layout.edgeInsets(
        left: _fieldPadHorizontal,
        right: _fieldPadHorizontal,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: layout.radius(AppSpacing.radiusXs),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: child,
    );
  }

  /// 字段标题：16pt / 行高 22。
  TextStyle _labelStyle(AppLayout layout) => TextStyle(
    fontSize: layout.px(_labelFontSize),
    height: _labelLineHeight / _labelFontSize,
    fontWeight: FontWeight.w600,
    color: AppColors.loginLabel,
  );

  /// 输入框内文字：14pt / 行高 20。
  TextStyle _fieldStyle(
    AppLayout layout, {
    required Color color,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontSize: layout.px(_fieldFontSize),
    height: _fieldLineHeight / _fieldFontSize,
    fontWeight: weight,
    color: color,
  );
}

/// 协议勾选行：勾选框 + `Privacy Policy` 链接。
///
/// 对照 peso_shield 的 `LoginAgreement`：**只有左侧勾选框负责切换选中态**，
/// 文案里的链接挂 [TapGestureRecognizer]，点文字不会误勾/误取消。
class _AgreementRow extends StatefulWidget {
  const _AgreementRow({
    required this.layout,
    required this.selected,
    required this.onChanged,
    this.onPrivacyPolicyTap,
  });

  final AppLayout layout;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onPrivacyPolicyTap;

  // 设计稿标注：勾选框 16x16，文案 12pt/行高 17。
  // 设计稿里勾选框（y 487~503）正好在整段协议文案（y 478~512）的垂直中线上，
  // 所以整行按 center 对齐即可，文案变成几行都对得上。
  static const _checkboxSize = 16.0;
  static const _checkboxGap = 8.0;
  static const _fontSize = 12.0;
  static const _lineHeight = 17.0;

  @override
  State<_AgreementRow> createState() => _AgreementRowState();
}

class _AgreementRowState extends State<_AgreementRow> {
  late final TapGestureRecognizer _privacyPolicyRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyPolicyRecognizer = TapGestureRecognizer()
      ..onTap = widget.onPrivacyPolicyTap;
  }

  @override
  void didUpdateWidget(covariant _AgreementRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _privacyPolicyRecognizer.onTap = widget.onPrivacyPolicyTap;
  }

  @override
  void dispose() {
    _privacyPolicyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final base = TextStyle(
      fontSize: layout.px(_AgreementRow._fontSize),
      height: _AgreementRow._lineHeight / _AgreementRow._fontSize,
      color: AppColors.agreementText,
    );
    final link = base.copyWith(
      color: AppColors.agreementLink,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.agreementLink,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          key: const Key('login-agreement-checkbox'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!widget.selected),
          child: Image.asset(
            widget.selected
                ? AppAssets.loginCheckboxChecked
                : AppAssets.loginCheckboxUnchecked,
            width: layout.px(_AgreementRow._checkboxSize),
            height: layout.px(_AgreementRow._checkboxSize),
          ),
        ),
        SizedBox(width: layout.px(_AgreementRow._checkboxGap)),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: _LoginPageState._agreementLead),
                TextSpan(
                  text: _LoginPageState._agreementPrivacy,
                  style: link,
                  recognizer: _privacyPolicyRecognizer,
                ),
              ],
            ),
            style: base,
          ),
        ),
      ],
    );
  }
}
