import 'package:flutter/foundation.dart';

/// 接口下发的设备信息（`POST /outsulk/omphacy` 返回的 `beautifully` / `squattest`）
/// 在进程内的同步缓存。
///
/// 公参 `beautifully` 要在同步的加签流程（[HttpClient.buildSignedQuery]）里读取，
/// 而接口查询是异步的；查询结果在落库（[ReportStore]）的同时写入这里，
/// 供公参同步读取。进程启动时会用落库值预热，网络失败时也能带上一次查到的值。
///
/// 用单例是因为 [HttpClient] 与上报服务分别在不同位置构建，需要共享同一份缓存
/// （与 `PushBridge.shared` / `ObfuscationHelper` 同样的约定）。
class DeviceInfoCache {
  DeviceInfoCache._();

  static final DeviceInfoCache shared = DeviceInfoCache._();

  String _deviceName = '';
  String _physicalSize = '';

  /// 接口下发的设备名称（公参 `beautifully`）；未查到前为空串。
  String get deviceName => _deviceName;

  /// 接口下发的物理尺寸（设备报文 `squattest`）；未查到前为空串。
  String get physicalSize => _physicalSize;

  /// 写入非空值；空值会被忽略，避免把已知结果覆盖成空。
  void update({String? deviceName, String? physicalSize}) {
    final name = deviceName?.trim();
    if (name != null && name.isNotEmpty) _deviceName = name;
    final size = physicalSize?.trim();
    if (size != null && size.isNotEmpty) _physicalSize = size;
  }

  @visibleForTesting
  void reset() {
    _deviceName = '';
    _physicalSize = '';
  }
}
