import '../../core/network/api_fields.dart';

/// 获取用户身份信息（认证第一项，`GET /outsulk/gaonate`）。
///
/// 只解析证件选择页要用的两组数据：
/// - [recommended]：设计稿 `Recommended ID Type`（`wollongong[0].unconversational`）
/// - [other]：设计稿 `Other Options`（`wollongong[0].drumfish`）
///
/// `wollongong` 是数组，接口文档的示例只有一组，这里取第一组。
///
/// 响应里还有几组数据这一页用不到，等证件上传页落地时再一起接：
/// `ceratin` / `acquirements`（已上传的身份证正面 / 活体）、`nonbuoyantly`、
/// `magisterial`（客户端写死的示例证件图）、`befleas`（引导文案）。
class IdVerificationData {
  const IdVerificationData({required this.recommended, required this.other});

  factory IdVerificationData.fromJson(Map<String, dynamic> json) {
    final groups = json[ApiFields.idCardGroups];
    final group = groups is List && groups.isNotEmpty && groups.first is Map
        ? (groups.first as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    return IdVerificationData(
      recommended: _cardTypesOf(group[ApiFields.idCardRecommended]),
      other: _cardTypesOf(group[ApiFields.idCardOthers]),
    );
  }

  /// 推荐证件（设计稿第一张卡）。
  final List<IdCardType> recommended;

  /// 其他证件（设计稿第二张卡）。
  final List<IdCardType> other;

  /// 两组都是空：后端没下发证件配置（低版本 / 未灰度用户），页面走空态。
  bool get isEmpty => recommended.isEmpty && other.isEmpty;
}

/// 证件类型（`partridge`）。
///
/// [name] 直接当行文案展示，同时也用作后续上传 / 保存身份证接口的卡类型取值
/// （上传接口的 `heterological`）。
///
/// ⚠️ 待联调确认：文档示例里 `partridge` 是 `DRIVINGLICENSE` / `TIN` 这种短码，
/// 而设计稿行文案是 `DRIVER'S LICENSE` / `TIN  ID`。前端**不维护**「短码 → 文案」
/// 映射表（`PHILIPPINE PASSPORT`、`UMID(Unified Multi-Purpose ID)` 这种文案也推不出来）。
/// 真机联调时先确认后端下发的是哪一种：如果下发的是短码，由后端补展示文案。
class IdCardType {
  const IdCardType({
    required this.name,
    this.sampleUrls = const [],
    this.wrongSampleUrls = const [],
  });

  final String name;

  /// 正确示范图（上传页展示）。
  final List<String> sampleUrls;

  /// 错误示范图（上传页展示）。
  final List<String> wrongSampleUrls;
}

List<IdCardType> _cardTypesOf(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        IdCardType(
          name: item[ApiFields.idCardName]?.toString() ?? '',
          sampleUrls: _stringListOf(item[ApiFields.idCardSampleUrls]),
          wrongSampleUrls: _stringListOf(item[ApiFields.idCardWrongSampleUrls]),
        ),
  ].where((card) => card.name.isNotEmpty).toList();
}

List<String> _stringListOf(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item?.toString().isNotEmpty ?? false) item.toString(),
  ];
}
