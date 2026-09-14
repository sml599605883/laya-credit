import '../../core/network/api_fields.dart';

/// 个人中心数据。
class PersonalCenterData {
  const PersonalCenterData({
    required this.services,
    required this.hasRedPoint,
    required this.redPointId,
  });

  factory PersonalCenterData.fromJson(Map<String, dynamic> json) {
    final rawServices = json[ApiFields.serviceList];
    return PersonalCenterData(
      services: rawServices is List
          ? rawServices
                .whereType<Map>()
                .map(
                  (item) => ServiceEntry.fromJson(item.cast<String, dynamic>()),
                )
                .toList()
          : const [],
      hasRedPoint: _int(json[ApiFields.ifRedPoint]) == 1,
      redPointId: json[ApiFields.redPointId]?.toString() ?? '',
    );
  }

  final List<ServiceEntry> services;

  /// 是否有未读消息红点。
  final bool hasRedPoint;
  final String redPointId;

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// 个人中心的服务入口（客服、投诉、设置等）。
///
/// 图标与跳转地址全部由后端下发，客户端不写死，避免每次调整入口都要发版。
class ServiceEntry {
  const ServiceEntry({
    required this.id,
    required this.title,
    required this.key,
    required this.iconUrl,
    required this.linkUrl,
    required this.jumpUrl,
    required this.isH5,
  });

  factory ServiceEntry.fromJson(Map<String, dynamic> json) {
    return ServiceEntry(
      id: json[ApiFields.itemId]?.toString() ?? '',
      title: json[ApiFields.itemTitle]?.toString() ?? '',
      key: json[ApiFields.itemKey]?.toString() ?? '',
      iconUrl: json[ApiFields.iconUrl]?.toString() ?? '',
      linkUrl: json[ApiFields.linkUrl]?.toString() ?? '',
      jumpUrl: json[ApiFields.jumpUrl]?.toString() ?? '',
      isH5: json[ApiFields.isH5]?.toString() == '1',
    );
  }

  final String id;
  final String title;

  /// 入口标识，例如 customer_service_center / set_up。
  final String key;
  final String iconUrl;

  /// 原生路由或深链（timeling / superidealness）。
  final String linkUrl;
  final String jumpUrl;

  /// 跳转目标是否为 H5。
  final bool isH5;

  /// 优先取原生跳转地址，其次取通用 url。
  String get target => linkUrl.isNotEmpty ? linkUrl : jumpUrl;
}
