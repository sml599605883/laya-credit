import '../../core/network/api_fields.dart';

/// 弹窗类型（文档语义 `type`，接口文档「弹窗」）。
enum AppPopupType {
  /// 无弹窗。
  none,

  /// 应用内升级弹窗。
  appUpgrade,

  /// 会员升级弹窗（暂未接入）。
  membershipUpgrade,

  /// 营销弹窗。
  marketing,

  /// 后端下发了未知类型。
  unsupported,
}

/// 首页 / 个人中心弹窗（`GET /outsulk/agatize` 的 `connectedly`）。
///
/// `liquidators` 是弹窗类型（`1` 应用内升级 / `2` 会员升级 / `3` 营销，`0` 无弹窗），
/// `lapsable` 是随类型变化的内容节点。目前接入了应用内升级与营销弹窗，
/// 会员升级的内容先保留在 [payload] 里，待接入时再解析。
class AppDialog {
  const AppDialog({
    this.type = AppPopupType.none,
    this.version = '',
    this.message = '',
    this.imageUrl = '',
    this.targetUrl = '',
    this.payload,
  });

  factory AppDialog.fromJson(Map<String, dynamic> json) {
    final node = json[ApiFields.popupData];
    final payload = node is Map ? node.cast<String, dynamic>() : null;
    return AppDialog(
      type: _typeOf(json[ApiFields.popupType]),
      version: _textOf(payload?[ApiFields.popupUpgradeVersion]),
      message: _textOf(payload?[ApiFields.popupUpgradeMessage]),
      imageUrl: _textOf(payload?[ApiFields.popupMarketingImage]),
      targetUrl: _textOf(payload?[ApiFields.popupUrl]),
      payload: payload,
    );
  }

  /// 弹窗类型。
  final AppPopupType type;

  /// 最新版本号（应用内升级弹窗，`fmcs`）。
  final String version;

  /// 弹窗文案（应用内升级弹窗，`predy`）。
  final String message;

  /// 弹窗图片地址（营销弹窗，`radiotelegraphy`）。
  final String imageUrl;

  /// 跳转地址（`superidealness`）：升级弹窗是下载链接，营销弹窗是落地页。
  final String targetUrl;

  /// 原始内容节点（`lapsable`），供暂未接入的弹窗类型使用。
  final Map<String, dynamic>? payload;

  /// 是否有需要展示的弹窗。营销弹窗没有下发图片时无可展示内容，按无弹窗处理。
  bool get hasPopup => switch (type) {
    AppPopupType.appUpgrade => true,
    AppPopupType.marketing => imageUrl.isNotEmpty,
    _ => false,
  };

  /// 版本号胶囊文案：后端下发的是 `1.1.4`，设计稿展示成 `V1.1.4`，
  /// 缺 `V` 前缀时补上（对齐 dali_cash）。
  String get displayVersion {
    final value = version.trim();
    if (value.isEmpty) return '';
    return value.toUpperCase().startsWith('V') ? value : 'V$value';
  }
}

AppPopupType _typeOf(Object? value) => switch (value?.toString().trim() ?? '') {
  '1' => AppPopupType.appUpgrade,
  '2' => AppPopupType.membershipUpgrade,
  '3' => AppPopupType.marketing,
  '0' || '' => AppPopupType.none,
  _ => AppPopupType.unsupported,
};

String _textOf(Object? value) => value?.toString().trim() ?? '';
