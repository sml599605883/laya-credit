import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/product/product_application_flow.dart';
import 'repository_provider.dart';
import 'session_provider.dart';

/// 产品申请流程协调器。页面通过它发起准入 / 详情请求，
/// 不要在页面里直接拼接口参数。
final productApplicationFlowProvider = FutureProvider<ProductApplicationFlow>((
  ref,
) async {
  final repository = await ref.watch(productRepositoryProvider.future);
  return ProductApplicationFlow(
    repository: repository,
    isLoggedIn: () => ref.read(userSessionProvider).isLoggedIn,
    sessionStore: ref.read(sessionStoreProvider),
  );
});
