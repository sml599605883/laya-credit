import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_environment.dart';
import '../core/device/device_params.dart';
import '../core/network/network.dart';
import 'session_provider.dart';

/// 运行时接口地址覆盖。
///
/// 默认走 [ApiEnvironment] 里的编译期地址；QA 可以在启动页或调试入口
/// 调用 `update()` 切到测试环境，不需要重新打包。
final runtimeApiBaseProvider = NotifierProvider<RuntimeApiBaseNotifier, Uri?>(
  RuntimeApiBaseNotifier.new,
);

class RuntimeApiBaseNotifier extends Notifier<Uri?> {
  @override
  Uri? build() => null;

  void update(Uri? value) => state = value;
}

final networkConfigProvider = Provider<NetworkConfig>((ref) {
  return NetworkConfig(
    apiBase:
        ref.watch(runtimeApiBaseProvider) ?? Uri.parse(ApiEnvironment.apiBase),
    signSecret: ApiEnvironment.signSecret,
    marketIdentifier: ApiEnvironment.marketIdentifier,
    aesKey: ApiEnvironment.aesKey,
    aesIv: ApiEnvironment.aesIv,
  );
});

/// 设备信息只加载一次，后续请求复用。
final deviceParamsProvider = FutureProvider<DeviceParams>((ref) {
  return DeviceParamsLoader().load();
});

/// 全局 HTTP 客户端。业务仓库通过 `ref.watch(httpClientProvider.future)` 获取。
final httpClientProvider = FutureProvider<HttpClient>((ref) async {
  final config = ref.watch(networkConfigProvider);
  final device = await ref.watch(deviceParamsProvider.future);

  return HttpClient(
    config: config,
    device: device,
    getUserToken: () => ref.read(userSessionProvider).accessToken,
    onAuthExpired: () {
      ref.read(userSessionProvider.notifier).clearSession();
      ref.read(sessionExpirySignalProvider).notifyExpired();
    },
  );
});
