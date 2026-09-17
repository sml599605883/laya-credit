import '../../core/network/api_fields.dart';

/// 「点击申请」（`POST /outsulk/weaken`）的准入结果。
///
/// 响应报文的外层 `connectedly` 由 [ApiResponse] 剥掉后传进来，这里只读业务数据。
/// 文档里的几种典型结果：
/// - `countercharged == 200` 且无 `superidealness`：准入成功，继续拉产品详情走认证；
/// - `countercharged == 200` 且有 `superidealness`：借款中，直接跳转；
/// - `countercharged == 302`：准入失败 / 重新授信，按 `liquidators` 判断原生还是 H5；
/// - `countercharged == 505`：风控或分期失败，跳 H5 错误页。
class ProductApplyResult {
  const ProductApplyResult({
    required this.statusCode,
    required this.jumpUrl,
    required this.jumpType,
    required this.message,
    this.accessKey,
    this.secretKey,
  });

  factory ProductApplyResult.fromJson(Map<String, dynamic> json) {
    return ProductApplyResult(
      statusCode: _intOf(json[ApiFields.applyResultCode]),
      jumpUrl: json[ApiFields.jumpUrl]?.toString() ?? '',
      jumpType: _intOf(json[ApiFields.applyJumpType]),
      message: json[ApiFields.applyMessage]?.toString() ?? '',
      accessKey: json[ApiFields.applyAccessKey]?.toString(),
      secretKey: json[ApiFields.applySecretKey]?.toString(),
    );
  }

  /// 准入结果码，`200` 为成功。
  final int statusCode;

  /// 需要跳转的地址（H5 链接或原生 Scheme），可能为空。
  final String jumpUrl;

  /// 跳转类型：0 原生 / 1 H5。
  final int jumpType;

  /// 结果文案。
  final String message;

  /// advance 风控 SDK 的 accessKey / secretKey，后续上报会用到。
  final String? accessKey;
  final String? secretKey;

  /// 是否准入成功（需要继续走认证流程）。
  bool get isAdmitted => statusCode == 200;

  /// 准入结果里是否带跳转地址。
  bool get hasJump => jumpUrl.isNotEmpty;
}

int _intOf(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
