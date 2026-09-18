import '../../core/network/api_fields.dart';

/// 上传证件照后后端识别出的身份信息。
///
/// 来源：`POST /outsulk/fashioned`（`type=11` 身份证正面）响应里的 `connectedly`，
/// 文档示例：
///
/// ```json
/// {
///   "harbingers": "NAVEEN TOM VARGHESE",   // 姓名
///   "approach": "623099344111",            // 证件号
///   "counter": "23/11/1993",               // 出生日期
///   "superidealness": "http://eaxs.png"    // 证件照
/// }
/// ```
///
/// 这几个值在证件信息确认页展示，并由保存接口（`POST /outsulk/wardmote`）
/// 原样回传，所以页面只做格式归一，不做任何业务改写。
class IdentityRecognition {
  const IdentityRecognition({
    this.name = '',
    this.idNumber = '',
    this.birthDate = '',
    this.imageUrl = '',
  });

  /// 从上传接口响应的 `connectedly` 解析；字段缺失时全部按空串处理。
  factory IdentityRecognition.fromUploadResponse(Map<String, dynamic> json) {
    return IdentityRecognition(
      name: _stringOf(json[ApiFields.identityName]),
      idNumber: _stringOf(json[ApiFields.identityIdNumber]),
      birthDate: normalizeBirthDate(
        _stringOf(json[ApiFields.identityBirthDate]),
      ),
      imageUrl: _stringOf(json[ApiFields.identityImageUrl]),
    );
  }

  /// 识别出的姓名。
  final String name;

  /// 识别出的证件号。
  final String idNumber;

  /// 识别出的出生日期，已归一成 `d-m-Y`。
  final String birthDate;

  /// 证件照地址，可能为空（后端没回传时页面用设计稿切图兜底）。
  final String imageUrl;

  /// 把识别出的出生日期归一成保存接口要求的 `dd-MM-yyyy`。
  ///
  /// 后端两种顺序都出现过：上传响应是 `23/11/1993`（日在先），身份信息
  /// `gaonate` 响应是 `1969/11/03`（年在先）。所以这里先解析再格式化，
  /// 不能只把 `/` 换成 `-`（那会把 `1969/11/03` 写成 `1969-11-03`）。
  /// 解析不出真实日期时原样返回，交给用户在确认页改。
  static String normalizeBirthDate(String raw) {
    final date = parseBirthDate(raw);
    return date == null ? raw.trim() : formatBirthDate(date);
  }

  /// 解析出生日期，支持 `/`、`-`、`.` 分隔。
  ///
  /// 第一段是 4 位就按 `yyyy-MM-dd` 读，否则按 `dd-MM-yyyy` 读；
  /// 用 [DateTime] 回读校验，2 月 30 日这类不存在的日期会被挡掉。
  static DateTime? parseBirthDate(String raw) {
    final parts = raw.trim().split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return null;
    final values = parts.map((part) => int.tryParse(part.trim())).toList();
    if (values.any((value) => value == null)) return null;

    final yearFirst = parts[0].trim().length == 4;
    final year = yearFirst ? values[0]! : values[2]!;
    final month = values[1]!;
    final day = yearFirst ? values[2]! : values[0]!;

    final date = DateTime(year, month, day);
    // DateTime 会把溢出值滚到下个月，回读一遍才能确认日期真实存在。
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// 把日期格式化成保存接口要求的 `dd-MM-yyyy`。
  static String formatBirthDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  static String _stringOf(Object? value) => value?.toString().trim() ?? '';
}
