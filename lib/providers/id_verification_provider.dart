import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/id_verification_data.dart';
import 'repository_provider.dart';

/// 证件类型列表（认证第一项）。
///
/// 按产品维度缓存：同一产品反复进出页面不会重复请求；失败时页面用
/// `ref.invalidate(idVerificationProvider(productId))` 重试。
final idVerificationProvider =
    FutureProvider.family<IdVerificationData, String>((ref, productId) async {
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
