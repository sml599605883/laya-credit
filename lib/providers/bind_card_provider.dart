import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/bind_card_data.dart';
import 'repository_provider.dart';

/// 绑卡表单（认证第五项，`GET /outsulk/cussedly`）。
///
/// 打款方式分组与字段描述都由后端按产品下发；不缓存，离开页面即释放结果，
/// 重新进入会重新请求；失败时页面用
/// `ref.invalidate(bindCardProvider(productId))` 重试。
final bindCardProvider = FutureProvider.autoDispose
    .family<BindCardData, String>((ref, productId) async {
      final repository = await ref.watch(
        certificationRepositoryProvider.future,
      );
      final response = await repository.getBindCardInfo(productId: productId);
      if (!response.isSuccess) {
        throw ApiException(
          type: ApiFailureType.business,
          message: response.message,
          code: response.code,
        );
      }
      return response.data;
    });
