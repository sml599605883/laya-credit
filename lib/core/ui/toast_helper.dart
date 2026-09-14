import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

/// 全局提示：Loading 与 Toast。
///
/// 所有提示居中显示，展示期间拦截用户交互，避免用户在请求进行中重复点击提交按钮。
class ToastHelper {
  ToastHelper._();

  static const _textDuration = Duration(seconds: 2);
  static const _animationDuration = Duration(milliseconds: 200);

  /// 显示 Loading，返回值用于手动关闭。
  static CancelFunc showLoading() {
    return BotToast.showLoading(
      clickClose: false,
      allowClick: false,
      crossPage: true,
      align: Alignment.center,
      enableKeyboardSafeArea: false,
    );
  }

  static void hideLoading() => BotToast.closeAllLoading();

  static void showMessage(String message) => _showText(message);

  static void showError(String message) => _showText(message);

  static void cancel() {
    BotToast.closeAllLoading();
    BotToast.removeAll(BotToast.textKey);
  }

  /// `BotToast.showText` 内部把 allowClick 固定为 true，无法拦截点击，
  /// 所以这里用 showAnimationWidget 自己组装。
  ///
  /// `enableKeyboardSafeArea` 必须关掉：否则会给整个区域垫上等于键盘高度的
  /// 底部 padding，剩下的区域再居中就会偏上。
  static void _showText(String message) {
    if (message.isEmpty) return;
    BotToast.showAnimationWidget(
      groupKey: BotToast.textKey,
      crossPage: true,
      allowClick: false,
      clickClose: false,
      ignoreContentClick: true,
      onlyOne: true,
      enableKeyboardSafeArea: false,
      duration: _textDuration,
      animationDuration: _animationDuration,
      wrapToastAnimation: (controller, cancel, child) => FadeTransition(
        opacity: controller,
        child: Align(alignment: Alignment.center, child: child),
      ),
      toastBuilder: (_) => _CenteredTextToast(text: message),
    );
  }
}

class _CenteredTextToast extends StatelessWidget {
  const _CenteredTextToast({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
      ),
    );
  }
}
