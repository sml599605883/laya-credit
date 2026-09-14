import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 上报给后端的设备信息。一次启动内不会变化，加载一次后缓存使用。
class DeviceParams {
  const DeviceParams({
    required this.deviceId,
    required this.appVersion,
    required this.modelName,
    required this.systemVersion,
    required this.advertisingId,
  });

  final String deviceId;
  final String appVersion;
  final String modelName;
  final String systemVersion;

  /// 广告标识（IDFA）。未取得 ATT 授权时为「全零」串或空串，由调用方决定是否上报。
  final String advertisingId;
}

/// 读取设备信息。
class DeviceParamsLoader {
  DeviceParamsLoader({
    DeviceInfoPlugin? deviceInfo,
    SharedPreferencesAsync? prefs,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _injectedPrefs = prefs;

  static const _fallbackDeviceIdKey = 'laya_credit.device.fallback_id';

  /// 读取设备信息的最长等待时间。原生插件偶发不回调时，不能让它把
  /// 首页的 Loading 永远挂住——超时后退回兜底值，保证 App 能继续跑。
  static const _timeout = Duration(seconds: 8);

  final DeviceInfoPlugin _deviceInfo;
  final SharedPreferencesAsync? _injectedPrefs;

  /// 同 [SessionStore]：平台实现缺失时退化为空操作，不能阻塞启动。
  SharedPreferencesAsync? get _prefs {
    final injected = _injectedPrefs;
    if (injected != null) return injected;
    try {
      return SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  Future<DeviceParams> load() async {
    try {
      return await _read().timeout(_timeout);
    } catch (error) {
      debugPrint('[DeviceParams] 读取设备信息失败，使用兜底值: $error');
      return _fallback();
    }
  }

  /// 兜底值：保证后续请求仍能带上一个稳定的 deviceId。
  Future<DeviceParams> _fallback() async {
    return DeviceParams(
      deviceId: await _resolveDeviceId(null),
      appVersion: '0.0.0',
      modelName: Platform.operatingSystem,
      systemVersion: Platform.operatingSystemVersion,
      advertisingId: '',
    );
  }

  Future<DeviceParams> _read() async {
    final packageInfo = await PackageInfo.fromPlatform();
    // 文档要求 `plica` 形如 1.0.0，不要带 buildNumber。
    final appVersion = packageInfo.version;

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return DeviceParams(
        deviceId: await _resolveDeviceId(info.identifierForVendor),
        appVersion: appVersion,
        modelName: info.modelName,
        systemVersion: info.systemVersion,
        // 文档要求 gps_adid 传 idfv。
        advertisingId: info.identifierForVendor ?? '',
      );
    }

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return DeviceParams(
        deviceId: await _resolveDeviceId(info.id),
        appVersion: appVersion,
        modelName: info.model,
        systemVersion: info.version.release,
        advertisingId: '',
      );
    }

    return DeviceParams(
      deviceId: await _resolveDeviceId(null),
      appVersion: appVersion,
      modelName: Platform.operatingSystem,
      systemVersion: Platform.operatingSystemVersion,
      advertisingId: '',
    );
  }

  /// identifierForVendor 在极少数情况下为空，此时退回到本地持久化的随机 ID，
  /// 保证同一个安装包内 `deviceId` 始终稳定。
  Future<String> _resolveDeviceId(String? systemDeviceId) async {
    final normalized = systemDeviceId?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;

    final prefs = _prefs;
    if (prefs == null) {
      return DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    }

    final cached = await prefs.getString(_fallbackDeviceIdKey);
    if (cached != null && cached.isNotEmpty) return cached;

    final generated = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    await prefs.setString(_fallbackDeviceIdKey, generated);
    return generated;
  }
}
