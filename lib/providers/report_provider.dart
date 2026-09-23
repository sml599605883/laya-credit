import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_environment.dart';
import '../core/report/report.dart';
import '../data/repositories/report_repository.dart';
import 'network_provider.dart';
import 'session_provider.dart';

/// 上报接口仓库。
final reportRepositoryProvider = FutureProvider<ReportRepository>((ref) async {
  final client = await ref.watch(httpClientProvider.future);
  return ReportRepository(client);
});

/// 上报服务（全局单例）。
///
/// 首次读取时构建并注册为 [ReportService.current]，之后页面直接通过
/// `ReportService.current?.reportRisk(...)` 埋点，不需要再依赖 Provider。
final reportServiceProvider = FutureProvider<ReportService>((ref) async {
  final repository = await ref.watch(reportRepositoryProvider.future);
  return ReportService.configure(
    repository,
    ReportBridge.shared,
    encryptKey: ApiEnvironment.aesKey,
    encryptIv: ApiEnvironment.aesIv,
    accessToken: () => ref.read(userSessionProvider).accessToken,
  );
});
