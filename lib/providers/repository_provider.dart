import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/certification_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/product_repository.dart';
import 'network_provider.dart';

/// 仓库统一入口：页面/Provider 只依赖仓库，不直接依赖 Dio。
/// HTTP 客户端是异步初始化的（要等设备信息），所以这里用 FutureProvider。
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final client = await ref.watch(httpClientProvider.future);
  return AuthRepository(client);
});

final appRepositoryProvider = FutureProvider<AppRepository>((ref) async {
  final client = await ref.watch(httpClientProvider.future);
  return AppRepository(client);
});

final productRepositoryProvider = FutureProvider<ProductRepository>((
  ref,
) async {
  final client = await ref.watch(httpClientProvider.future);
  return ProductRepository(client);
});

final certificationRepositoryProvider = FutureProvider<CertificationRepository>(
  (ref) async {
    final client = await ref.watch(httpClientProvider.future);
    return CertificationRepository(client);
  },
);

final orderRepositoryProvider = FutureProvider<OrderRepository>((ref) async {
  final client = await ref.watch(httpClientProvider.future);
  return OrderRepository(client);
});
