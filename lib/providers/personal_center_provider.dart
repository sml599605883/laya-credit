import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/personal_center_data.dart';
import 'repository_provider.dart';
import 'session_provider.dart';

/// 个人中心数据。需要登录态，退出登录后自动失效重新拉取。
final personalCenterProvider =
    AsyncNotifierProvider<PersonalCenterNotifier, PersonalCenterData>(
      PersonalCenterNotifier.new,
    );

class PersonalCenterNotifier extends AsyncNotifier<PersonalCenterData> {
  @override
  Future<PersonalCenterData> build() async {
    // 登录态变化（登录/退出）时重新请求，避免展示上一个账号的数据。
    final session = ref.watch(userSessionProvider);
    if (!session.isLoggedIn) {
      return const PersonalCenterData(
        services: [],
        hasRedPoint: false,
        redPointId: '',
      );
    }
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<PersonalCenterData> _fetch() async {
    final repository = await ref.read(appRepositoryProvider.future);
    final response = await repository.getPersonalCenter();
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
