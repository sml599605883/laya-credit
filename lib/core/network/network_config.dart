/// 网络层运行时配置。
///
/// 与 [ApiEnvironment] 分开：前者是「编译期默认值」，这里是「跑起来之后实际生效的值」，
/// QA 可以通过 `runtimeApiBaseProvider` 在运行时切换环境地址。
class NetworkConfig {
  const NetworkConfig({
    required this.apiBase,
    required this.signSecret,
    required this.marketIdentifier,
    this.aesKey = '',
    this.aesIv = '',
    this.connectionTimeout = const Duration(seconds: 30),
    this.requestTimeout = const Duration(seconds: 30),
    this.responseTimeout = const Duration(seconds: 30),
  });

  final Uri apiBase;
  final String signSecret;
  final String marketIdentifier;
  final String aesKey;
  final String aesIv;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final Duration responseTimeout;
}
