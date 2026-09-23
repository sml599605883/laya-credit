import '../../core/network/api_fields.dart';

/// 认证流程「返回挽留」弹窗素材（`POST /outsulk/curitiba` 的 `connectedly.lapsable`）。
///
/// 后端下发一张**整卡图片**（信封插画 / 标题 / 正文 / 胶囊按钮底色都烘焙在图里）
/// 与两个按钮文案，客户端只把文案叠到图上：
/// - [continueText] 叠在整卡自带的胶囊上，点了留在当前页；
/// - [exitText] 放在整卡下方的深色遮罩上，点了真正返回。
///
/// 素材缺失（[imageUrl] 为空）时调用方应直接放行返回，不要弹空壳弹窗。
class CertificationRetention {
  const CertificationRetention({
    this.imageUrl = '',
    this.continueText = '',
    this.exitText = '',
  });

  factory CertificationRetention.fromJson(Map<String, dynamic> json) {
    final node = json[ApiFields.retentionData];
    final data = node is Map
        ? node.cast<String, dynamic>()
        : const <String, dynamic>{};
    return CertificationRetention(
      imageUrl: _textOf(data[ApiFields.retentionImage]),
      continueText: _textOf(data[ApiFields.retentionContinueText]),
      exitText: _textOf(data[ApiFields.retentionExitText]),
    );
  }

  /// 整卡图片地址（`superidealness`）。
  final String imageUrl;

  /// 主按钮文案（`limbos`）。
  final String continueText;

  /// 次要行动文案（`leonor`）。
  final String exitText;

  /// 是否有可弹的素材：图没下发就当作「后端没有挽留」，直接返回。
  bool get hasImage => imageUrl.isNotEmpty;

  /// 主按钮文案，后端没下发时用设计稿兜底（蓝湖稿 `text_3`）。
  String get resolvedContinueText =>
      continueText.isEmpty ? 'Continue' : continueText;

  /// 次要行动文案，后端没下发时用设计稿兜底（蓝湖稿 `text_4`）。
  String get resolvedExitText => exitText.isEmpty ? 'Exit' : exitText;
}

String _textOf(Object? value) => value?.toString().trim() ?? '';
