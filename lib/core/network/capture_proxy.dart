import 'package:flutter/services.dart';

/// 抓包代理配置。
///
/// `peso_shield` 同款方案：Flutter 的 `dart:io` 走原生 socket，不会自动读系统代理，
/// 所以由 iOS 原生读出系统代理后经 MethodChannel 下发（见 `capture_proxy` 通道）。
class CaptureProxySettings {
  const CaptureProxySettings({required this.host, required this.port});

  final String host;
  final int port;

  bool get isValid => host.trim().isNotEmpty && port > 0 && port <= 65535;
}

/// 读取 iOS 系统代理设置（Wi-Fi 里配的 HTTP 代理）。
class CaptureProxyDiscovery {
  const CaptureProxyDiscovery._();

  static const _channel = MethodChannel('laya_credit/capture_proxy');

  static Future<CaptureProxySettings?> systemSettings() async {
    try {
      final value = await _channel.invokeMethod<Object?>('getSystemProxy');
      if (value is! Map) return null;
      final host = value['host']?.toString() ?? '';
      final port = value['port'] is int
          ? value['port'] as int
          : int.tryParse(value['port']?.toString() ?? '');
      if (port == null) return null;
      final settings = CaptureProxySettings(host: host, port: port);
      return settings.isValid ? settings : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
