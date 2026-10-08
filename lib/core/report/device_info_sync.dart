import 'package:flutter/foundation.dart';

import '../../data/repositories/report_repository.dart';
import '../device/device_info_cache.dart';
import 'report_bridge.dart';
import 'report_data.dart';
import 'report_store.dart';

/// 按硬件型号标识查设备名称 / 物理尺寸（`POST /outsulk/omphacy`）。
///
/// 对齐 Dali Cash 的 `DeviceInfoSync`：**启动、进入首页前串行执行一次**，结果同时写入
/// [ReportStore]（跨启动持久化，供设备报文 `chlor` / `squattest` 使用）与
/// [DeviceInfoCache]（进程内同步缓存，供公参 `beautifully` 使用）。
///
/// 与 Dali 一样，查询是旁路能力：失败只打日志、返回空结果，绝不阻塞启动。
class DeviceInfoSync {
  const DeviceInfoSync({
    required this.repository,
    required this.bridge,
    required this.store,
  });

  final ReportRepository repository;
  final ReportBridge bridge;
  final ReportStore store;

  /// 查一次设备信息并落库 / 落缓存，返回本次结果（失败或标识为空时返回空）。
  Future<ReportDeviceInfo> sync() async {
    // 先用落库值预热进程内缓存：本次网络失败时公参仍能带上一次启动查到的设备名。
    await _hydrateFromStore();
    try {
      final snapshot = await bridge.getReportDeviceSnapshot();
      final identifier = reportText(snapshot.model);
      if (identifier.isEmpty) return ReportDeviceInfo.empty;
      final response = await repository.lookupDeviceInfo(
        identifier: identifier,
      );
      final info = response.data;
      if (!response.isSuccess || !info.isValid) return ReportDeviceInfo.empty;
      if (info.deviceModel.isNotEmpty) {
        await store.saveDeviceModel(info.deviceModel);
      }
      if (info.physicalSize.isNotEmpty) {
        await store.savePhysicalSize(info.physicalSize);
      }
      DeviceInfoCache.shared.update(
        deviceName: info.deviceModel,
        physicalSize: info.physicalSize,
      );
      return info;
    } catch (error) {
      debugPrint('[DeviceInfoSync] 查询设备信息失败: $error');
      return ReportDeviceInfo.empty;
    }
  }

  Future<void> _hydrateFromStore() async {
    DeviceInfoCache.shared.update(
      deviceName: await store.deviceModel(),
      physicalSize: await store.physicalSize(),
    );
  }
}
