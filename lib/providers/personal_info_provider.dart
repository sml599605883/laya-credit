import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/personal_info_data.dart';
import 'repository_provider.dart';

/// 个人信息表单（认证第二项）。
///
/// 不缓存：离开页面即释放结果，重新进入会重新请求，避免展示过期的字段描述；
/// 失败时页面用 `ref.invalidate(personalInfoProvider(productId))` 重试。
final personalInfoProvider = FutureProvider.autoDispose
    .family<PersonalInfoData, String>((ref, productId) async {
      final repository = await ref.watch(
        certificationRepositoryProvider.future,
      );
      final response = await repository.getPersonalInfo(productId: productId);
      if (!response.isSuccess) {
        throw ApiException(
          type: ApiFailureType.business,
          message: response.message,
          code: response.code,
        );
      }
      return response.data;
    });
