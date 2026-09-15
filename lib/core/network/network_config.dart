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
    this.proxyHost = '',
    this.proxyPort,
    this.allowInsecureProxy = false,
  });

  final Uri apiBase;
  final String signSecret;
  final String marketIdentifier;
  final String aesKey;
  final String aesIv;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final Duration responseTimeout;

  /// 固定抓包代理。系统代理读不到时（如 Android）才会用到；
  /// iOS 下通常留空，交给 [CaptureProxyDiscovery] 动态发现。
  final String proxyHost;
  final int? proxyPort;

  /// 是否放行自签名证书。走抓包代理做 HTTPS 中间人时需要开启。
  final bool allowInsecureProxy;
}
