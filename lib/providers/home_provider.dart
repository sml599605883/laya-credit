import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/home_data.dart';
import 'repository_provider.dart';

/// 首页数据。游客可浏览，不依赖登录态。
final homeDataProvider = AsyncNotifierProvider<HomeDataNotifier, HomeData>(
  HomeDataNotifier.new,
);

class HomeDataNotifier extends AsyncNotifier<HomeData> {
  @override
  Future<HomeData> build() => _fetch();

  /// 下拉刷新 / 从后台回到前台时重新拉取。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
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
