import '../../core/network/api_fields.dart';

/// 订单状态文案的配色分档（蓝湖稿 `05-01 - 订单列表-有订单`）。
///
/// 后端只下发状态码 `polyphonist` 与状态文案，不下发颜色。设计稿画了三种：
/// 待还款（`Outstanding`，柠檬绿）/ 逾期（`Overdue`，品牌红）/ 其余终态
/// （`Settled` 等，深灰），客户端按状态码分档，取值见 [OrderStatusCode]。
enum OrderStatusTone { overdue, active, neutral }

/// 订单状态码（`polyphonist`）。
abstract final class OrderStatusCode {
  /// 待还款：设计稿 `Outstanding`，柠檬绿，展示主按钮。
  static const pendingRepay = 179;

  /// 逾期：设计稿 `Overdue`，品牌红，展示主按钮。
  static const overdue = 180;
}

/// 订单列表项。字段来自接口文档 `5.order.html#订单列表`（`POST /outsulk/gundy`）。
class OrderListItem {
  const OrderListItem({
    required this.orderId,
    required this.orderNo,
    required this.productId,
    required this.productName,
    required this.productLogo,
    required this.statusCode,
    required this.statusText,
    required this.amountText,
    required this.amountLabel,
    required this.actionText,
    required this.legacyTarget,
    required this.dateLabel,
    required this.dateValue,
    required this.overdueDays,
    required this.cardTarget,
    required this.actionTarget,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> json) => OrderListItem(
    orderId: _intValue(json[ApiFields.orderListOrderId]),
    orderNo: _stringValue(json[ApiFields.orderListOrderNo]),
    productId: _stringValue(json[ApiFields.orderListProductId]),
    productName: _stringValue(json[ApiFields.orderListProductName]),
    productLogo: _stringValue(json[ApiFields.orderListProductLogo]),
    statusCode: _intValue(json[ApiFields.orderListStatusCode]),
    statusText: _stringValue(json[ApiFields.orderListStatusText]),
    amountText: _stringValue(json[ApiFields.orderListAmountText]),
    amountLabel: _stringValue(json[ApiFields.orderListAmountLabel]),
    actionText: _stringValue(json[ApiFields.orderListActionText]),
    legacyTarget: _stringValue(json[ApiFields.orderListLegacyTarget]),
    dateLabel: _stringValue(json[ApiFields.orderListDateLabel]),
    dateValue: _stringValue(json[ApiFields.orderListDateValue]),
    overdueDays: _intValue(json[ApiFields.orderListOverdueDays]),
    cardTarget: _stringValue(json[ApiFields.orderListCardTarget]),
    actionTarget: _stringValue(json[ApiFields.orderListActionTarget]),
  );

  final int orderId;
  final String orderNo;
  final String productId;
  final String productName;
  final String productLogo;
  final int statusCode;
  final String statusText;

  /// 已格式化金额（例如 `₱ 2,000`），客户端不再做千分位处理。
  final String amountText;
  final String amountLabel;

  /// 主按钮文案（是否展示见 [hasAction]，文案由后端下发）。
  final String actionText;

  /// 老版本跳转地址（订单详情页），`cardTarget` 缺失时兜底。
  final String legacyTarget;
  final String dateLabel;
  final String dateValue;

  /// 逾期天数（`ozonic`）。配色只看 [statusCode]，这个字段留给需要精确天数的场景。
  final int overdueDays;

  /// 卡片点击跳转地址（订单详情页，新字段 `danubian`）。
  final String cardTarget;

  /// 按钮点击跳转地址（还款详情页）。
  final String actionTarget;

  /// 卡片实际跳转地址：优先新字段 `danubian`，缺失时回落老版本的
  /// `rondelle`，两者都没有时返回空串（调用方会拦掉空地址）。
  String get detailTarget => cardTarget.isNotEmpty ? cardTarget : legacyTarget;

  /// 是否展示主按钮：只有待还款 / 逾期两个进行中的状态有
  /// （设计稿的终态卡没有按钮）。
  bool get hasAction =>
      statusCode == OrderStatusCode.pendingRepay ||
      statusCode == OrderStatusCode.overdue;

  /// 是否逾期（`polyphonist = 180`）。
  bool get isOverdue => statusCode == OrderStatusCode.overdue;

  /// 状态文案配色分档，见 [OrderStatusTone]。
  OrderStatusTone get statusTone => switch (statusCode) {
    OrderStatusCode.pendingRepay => OrderStatusTone.active,
    OrderStatusCode.overdue => OrderStatusTone.overdue,
    _ => OrderStatusTone.neutral,
  };
}

/// 订单列表接口返回（`connectedly`）。
///
/// 文档只给了「总页数」（`contraception`），没有总条数，所以判断还有没有下一页
/// 只看 [totalPages]。
class OrderListResult {
  const OrderListResult({required this.items, required this.totalPages});

  factory OrderListResult.fromJson(Object? data) {
    final raw = data is Map ? data : const {};
    return OrderListResult(
      items: parseOrderListItems(raw),
      totalPages: _pageCount(raw[ApiFields.orderListTotalPages]),
    );
  }

  final List<OrderListItem> items;

  /// 总页数。缺省或非法时按 1 处理，否则「还有下一页」会永远为真。
  final int totalPages;
}

/// 解析 `connectedly`，取出订单数组。缺字段时回落空列表，不抛异常。
List<OrderListItem> parseOrderListItems(Object? data) {
  if (data is! Map) return const [];
  final raw = data[ApiFields.orderListItems];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => OrderListItem.fromJson(item.cast<String, dynamic>()))
      .toList(growable: false);
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

int _pageCount(Object? value) {
  final parsed = _intValue(value);
  return parsed < 1 ? 1 : parsed;
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}
