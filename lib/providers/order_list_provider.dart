import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/order_list_data.dart';
import 'repository_provider.dart';

/// 订单列表页状态。
///
/// 接口按页下发，所以「已加载到第几页」「是否正在加载下一页」也放在状态里，
/// 页面不用自己维护分页游标。
class OrderListState {
  const OrderListState({
    required this.items,
    required this.page,
    required this.totalPages,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  OrderListState.fromResult(OrderListResult result)
    : items = result.items,
      page = 1,
      totalPages = result.totalPages,
      isLoadingMore = false,
      loadMoreFailed = false;

  final List<OrderListItem> items;

  /// 已加载到第几页（首次为 1）。
  final int page;

  /// 总页数（接口 `contraception`）。
  final int totalPages;

  /// 正在加载下一页。
  final bool isLoadingMore;

  /// 下一页加载失败：列表中保留已加载的数据，由页面给出重试入口。
  final bool loadMoreFailed;

  bool get isEmpty => items.isEmpty;

  /// 是否还有下一页。
  bool get hasMore => page < totalPages;

  OrderListState copyWith({bool? isLoadingMore, bool? loadMoreFailed}) {
    return OrderListState(
      items: items,
      page: page,
      totalPages: totalPages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }

  /// 把下一页的结果接在已加载数据后面。
  OrderListState append(OrderListResult next) {
    return OrderListState(
      items: [...items, ...next.items],
      page: page + 1,
      totalPages: next.totalPages,
    );
  }
}

/// 订单列表（`POST /outsulk/gundy`），按筛选状态分别缓存。
///
/// key 是 `OrderFilterStatus.value`（4/7/6/5），切换筛选项各自拉一次并缓存；
/// 触底调 [OrderListNotifier.loadMore] 追加下一页，首页失败时页面
/// `ref.invalidate(orderListProvider(status))` 整页重试。
final orderListProvider =
    AsyncNotifierProvider.family<OrderListNotifier, OrderListState, String>(
      OrderListNotifier.new,
    );

class OrderListNotifier extends AsyncNotifier<OrderListState> {
  OrderListNotifier(this.status);

  /// 筛选状态码，取值见 `OrderFilterStatus.value`。
  final String status;

  /// 每页条数（文档要求传 50）。
  static const pageSize = 50;

  /// 请求序号：刷新会让在途的「加载下一页」作废，避免旧的一页接在新列表后面。
  int _requestId = 0;

  @override
  Future<OrderListState> build() {
    _requestId++;
    return _fetch(1).then(OrderListState.fromResult);
  }

  /// 触底加载下一页。
  ///
  /// 没有下一页、正在加载、或当前是错误态时直接返回，所以重复触底不会重复请求。
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final requestId = _requestId;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final next = await _fetch(current.page + 1);
      if (requestId != _requestId) return;
      final latest = state.value ?? current;
      state = AsyncData(latest.append(next));
    } catch (error) {
      if (requestId != _requestId) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
      debugPrint('[OrderList] 加载下一页失败: $error');
    }
  }

  Future<OrderListResult> _fetch(int page) async {
    final repository = await ref.read(orderRepositoryProvider.future);
    final response = await repository.getOrderList(
      status: status,
      page: page,
      pageSize: pageSize,
    );
    if (!response.isSuccess) {
      throw ApiException(
        type: ApiFailureType.business,
        message: response.message,
        code: response.code,
      );
    }
    return response.data;
  }
}
