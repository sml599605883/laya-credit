import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/emergency_contact_data.dart';
import 'repository_provider.dart';

/// 紧急联系人（认证第四项，`GET /outsulk/liquidators`）。
///
/// 联系人条数与关系选项都由后端按产品下发，所以按产品维度缓存：
/// 同一产品反复进出页面不会重复请求；失败时页面用
/// `ref.invalidate(emergencyContactProvider(productId))` 重试。
final emergencyContactProvider =
    FutureProvider.family<EmergencyContactData, String>((ref, productId) async {
      final repository = await ref.watch(
        certificationRepositoryProvider.future,
      );
      final response = await repository.getEmergencyContacts(
        productId: productId,
      );
      if (!response.isSuccess) {
        throw ApiException(
          type: ApiFailureType.business,
          message: response.message,
          code: response.code,
        );
      }
      return response.data;
    });
