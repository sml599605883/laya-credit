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
  ///
  /// 不切 Loading 态：刷新期间页面继续展示上一次的数据（下拉转圈由
  /// `RefreshIndicator` 负责），否则额度头图会整块闪成加载态再跳回来。
  Future<void> refresh() async {
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
