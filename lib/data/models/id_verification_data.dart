import '../../core/network/api_fields.dart';

/// 获取用户身份信息（认证第一项，`GET /outsulk/gaonate`）。
///
/// 证件类型列表取 `magisterial`：文档里是两段字符串数组
/// （`[[推荐 6 项], [其他 5 项]]`），第一段对应设计稿的 `Recommended ID Type`，
/// 第二段对应 `Other Options`。两段的划分与同一响应里 `wollongong` 的
/// `unconversational` / `drumfish`（推荐 / 其他）一致。
///
/// 卡片文案直接原样展示，客户端**不做**「短码 → 文案」映射：设计稿上的
/// `DRIVER'S LICENSE` / `PHILIPPINE PASSPORT` 这类文案推不出来，
/// 后端下发什么就展示什么。
///
/// 响应里还有几组数据这一页用不到，等对应页面落地时再接：
/// `ceratin` / `acquirements`（已上传的身份证正面 / 活体）、`nonbuoyantly`、
/// `wollongong`（每个卡类型的正确 / 错误示范图，上传页用）、
/// `befleas`（引导文案，低版本或未灰度用户不下发）。
class IdVerificationData {
  const IdVerificationData({required this.recommended, required this.other});

  factory IdVerificationData.fromJson(Map<String, dynamic> json) {
    final groups = json[ApiFields.idCardGroups];
    final lists = groups is List ? groups : const [];

    return IdVerificationData(
      recommended: _stringListOf(lists.isNotEmpty ? lists.first : null),
      other: _stringListOf(lists.length > 1 ? lists[1] : null),
    );
  }

  /// 推荐证件（`magisterial[0]`，设计稿第一张卡）。
  final List<String> recommended;

  /// 其他证件（`magisterial[1]`，设计稿第二张卡）。
  final List<String> other;

  /// 两组都是空：后端没下发证件配置（低版本 / 未灰度用户），页面走空态。
  bool get isEmpty => recommended.isEmpty && other.isEmpty;
}

List<String> _stringListOf(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      // 只把「空字符串 / null」这类脏数据丢掉，文案本身原样保留（含空格）。
      if (item != null && item.toString().trim().isNotEmpty) item.toString(),
  ];
}
