import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/certification/certification_retention_guard.dart';
import 'repository_provider.dart';

/// 认证流程的返回挽留拦截器。
///
/// 做成 Provider 而不是每页 new 一个：同一个容器里共用一个实例，
/// 请求在途时重复按返回键只会被忽略，不会叠出两个弹窗。
final certificationRetentionGuardProvider =
    FutureProvider<CertificationRetentionGuard>((ref) async {
      final repository = await ref.watch(
        certificationRepositoryProvider.future,
      );
      return CertificationRetentionGuard(repository: repository);
    });
