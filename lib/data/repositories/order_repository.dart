import '../../core/network/api_endpoints.dart';
import '../../core/network/api_fields.dart';
import '../../core/network/api_response.dart';
import '../../core/network/http_client.dart';
import '../models/order_list_data.dart';

/// 订单相关接口（接口文档 `5.order.html`）。
class OrderRepository {
  const OrderRepository(this._client);

  final HttpClient _client;

  /// 订单列表（`POST /outsulk/gundy`）。
  ///
  /// [status] 取 `OrderFilterStatus.value`：4 全部 / 7 进行中 / 6 待还款 / 5 已结清；
  /// 每页 50 条（文档要求），翻页由调用方按返回的总页数决定。
  Future<ApiResponse<OrderListResult>> getOrderList({
    required String status,
    int page = 1,
    int pageSize = 50,
  }) {
    return _client.post<OrderListResult>(
      ApiEndpoints.orderList,
      params: {
        ApiFields.orderListStatus: status,
        ApiFields.orderListPage: page.toString(),
        ApiFields.orderListPageSize: pageSize.toString(),
      },
      parse: OrderListResult.fromJson,
    );
  }
}
