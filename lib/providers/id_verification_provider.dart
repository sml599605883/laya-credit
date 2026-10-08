import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/id_verification_data.dart';
import 'repository_provider.dart';

/// 证件类型列表（认证第一项）。
///
/// 不缓存：离开页面即释放结果，重新进入会重新请求；失败时页面用
/// `ref.invalidate(idVerificationProvider(productId))` 重试。
final idVerificationProvider = FutureProvider.autoDispose
    .family<IdVerificationData, String>((ref, productId) async {
      final repository = await ref.watch(
        certificationRepositoryProvider.future,
      );
      final response = await repository.getIdentityInfo(productId: productId);
      if (!response.isSuccess) {
        throw ApiException(
          type: ApiFailureType.business,
          message: response.message,
          code: response.code,
        );
      }
      return response.data;
    });
