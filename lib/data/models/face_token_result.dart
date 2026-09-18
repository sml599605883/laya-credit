import '../../core/network/api_fields.dart';

/// 获取 face++ token（`POST /outsulk/carline`）的业务数据。
///
/// 来源：接口文档「获取face++ token」响应里的 `connectedly`，示例：
///
/// ```json
/// {
///   "gravel": "200",          // result_code：200 正常 / 400 需重新上传身份证 / 500 其他错误
///   "benzanthracene": "",     // face++ base url
///   "inducted": "",           // face++ token；活体类型为 7 时是活体检测授权码
///   "instellation": "",       // face++ 具体错误
///   "bassein": 7              // 活体类型：5 face++ / 6 lite face++ / 7 trustdecision
/// }
/// ```
///
/// 页面按 [resultCode] 分流：`200` 拉起活体 SDK，`400` 引导用户重新上传身份证，
/// 其余按 [error] 提示。
class FaceTokenResult {
  const FaceTokenResult({
    this.resultCode = -1,
    this.bizUrl = '',
    this.token = '',
    this.error = '',
    this.livenessType = 7,
  });

  factory FaceTokenResult.fromJson(Map<String, dynamic> json) {
    return FaceTokenResult(
      resultCode: _intOf(json[ApiFields.faceTokenResultCode]),
      bizUrl: _stringOf(json[ApiFields.faceTokenBizUrl]),
      token: _stringOf(json[ApiFields.faceToken]),
      error: _stringOf(json[ApiFields.faceTokenError]),
      // 活体类型与上传接口的 `bassein` 是同一个字段名，语义一致。
      livenessType: _intOf(json[ApiFields.uploadFaceType], fallback: 7),
    );
  }

  /// 后端结果码，`-1` 表示响应结构不符。
  final int resultCode;

  /// face++ base url；信任决策 SDK 自己带地址时为空，页面不用它。
  final String bizUrl;

  /// face++ token / 活体检测授权码。
  final String token;

  /// face++ 具体错误文案。
  final String error;

  /// 活体类型：`5` face++ / `6` lite face++ / `7` trustdecision。
  final int livenessType;

  /// 可以拉起活体 SDK：结果码 `200` 且拿到了 token。
  bool get canStartLiveness => resultCode == 200 && token.isNotEmpty;

  /// 后端要求用户重新上传身份证（`result_code = 400`）。
  bool get needsIdentityResubmit => resultCode == 400;
}

String _stringOf(Object? value) => value?.toString().trim() ?? '';

int _intOf(Object? value, {int fallback = -1}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}
