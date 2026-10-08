import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/personal_info_data.dart';
import 'repository_provider.dart';

/// 工作信息表单（认证第三项，`GET /outsulk/timeling`）。
///
/// 与个人信息表单是同一份字段描述结构，所以共用 [PersonalInfoData]；
/// 不缓存：离开页面即释放结果，重新进入会重新请求；失败时页面用
/// `ref.invalidate(workInfoProvider(productId))` 重试。
final workInfoProvider = FutureProvider.autoDispose
    .family<PersonalInfoData, String>((ref, productId) async {
      final repository = await ref.watch(
        certificationRepositoryProvider.future,
      );
      final response = await repository.getWorkInfo(productId: productId);
      if (!response.isSuccess) {
        throw ApiException(
          type: ApiFailureType.business,
          message: response.message,
          code: response.code,
        );
      }
      return response.data;
    });
