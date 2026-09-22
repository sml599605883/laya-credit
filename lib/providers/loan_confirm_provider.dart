import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/loan_confirm_data.dart';
import 'repository_provider.dart';

/// 借款确认页的可选收款账户（`POST /outsulk/heartfelt`）。
///
/// 账户按产品下发，所以按产品维度缓存：同一产品反复进出页面不会重复请求；
/// 失败时页面用 `ref.invalidate(loanConfirmProvider(productId))` 重试。
final loanConfirmProvider = FutureProvider.family<LoanConfirmData, String>((
  ref,
  productId,
) async {
  final repository = await ref.watch(certificationRepositoryProvider.future);
  final response = await repository.getUserAccounts(productId: productId);
  if (!response.isSuccess) {
    throw ApiException(
      type: ApiFailureType.business,
      message: response.message,
      code: response.code,
    );
  }
  return response.data;
});
