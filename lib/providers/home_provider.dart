import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/ui/toast_helper.dart';
import '../data/models/home_data.dart';
import 'repository_provider.dart';

/// 刷新时的全局 Loading 遮罩。
///
/// 默认走 [ToastHelper]；测试可覆盖成空实现，避免把数据层挂死在 BotToast 上
/// （对齐 dali_cash 把 `showLoading` / `dismissLoading` 注入控制器的做法）。
class HomeLoadingIndicator {
  const HomeLoadingIndicator({required this.show, required this.hide});

  final void Function() show;
  final void Function() hide;
}

final homeLoadingIndicatorProvider = Provider<HomeLoadingIndicator>(
  (ref) => HomeLoadingIndicator(
    show: ToastHelper.showLoading,
    hide: ToastHelper.hideLoading,
  ),
);

/// 首页数据。游客可浏览，不依赖登录态。
final homeDataProvider = AsyncNotifierProvider<HomeDataNotifier, HomeData>(
  HomeDataNotifier.new,
);

class HomeDataNotifier extends AsyncNotifier<HomeData> {
  /// 刷新请求序号：只让最新一次请求写回状态。
  ///
  /// 下拉、生命周期恢复、路由返回几个触发点可能前后脚重叠，没有这个序号时
  /// 先发出的慢请求会覆盖后发出的新数据（对齐 dali_cash 的 last-wins 策略）。
  int _refreshRequestId = 0;

  @override
  Future<HomeData> build() => _fetch();

  /// 下拉刷新 / 从后台回到前台 / 从子页面返回时重新拉取。
  ///
  /// 保留上一次的数据，不把 state 切回 Loading（否则额度头图会整块闪成加载态
  /// 再跳回来）；改为在最上层盖一层全局 Loading 遮罩（对齐 dali_cash 的
  /// `showLoading`），遮罩期间拦截交互，避免刷新没完成就重复点申请 / 推荐卡。
  Future<void> refresh() async {
    final requestId = ++_refreshRequestId;
    final loading = ref.read(homeLoadingIndicatorProvider);
    loading.show();
    try {
      final result = await AsyncValue.guard(_fetch);
      // 期间已发起更新的请求：丢弃本次结果，避免旧数据盖掉新数据。
      if (requestId != _refreshRequestId) return;
      state = result;
    } finally {
      // 只有最新的请求负责收起遮罩，避免被先结束的旧请求提前关掉。
      if (requestId == _refreshRequestId) loading.hide();
    }
  }

  Future<HomeData> _fetch() async {
    final repository = await ref.read(appRepositoryProvider.future);
    final response = await repository.getHomePage();
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
