import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'report_data.dart';

/// 上报模块的本地状态。
///
/// 只存「跨启动需要记住」的东西：上次登录时间、定位缓存、设备型号/物理尺寸、
/// 是否首次启动。读写失败一律降级为空值，不让上报影响启动或登录。
class ReportStore {
  ReportStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync(),
      _memory = null;

  /// 仅供单元测试使用的内存实现。
  ReportStore.memory() : _preferences = null, _memory = <String, Object?>{};

  static const _loginAtKey = 'laya_credit.report.login_at';
  static const _locationKey = 'laya_credit.report.location';
  static const _deviceModelKey = 'laya_credit.report.device_model';
  static const _physicalSizeKey = 'laya_credit.report.physical_size';
  static const _hasOpenedKey = 'laya_credit.report.has_opened';
  static const _adjustInitializedKey =
      'laya_credit.report.attribution_initialized';

  final SharedPreferencesAsync? _preferences;
  final Map<String, Object?>? _memory;

  /// 上次登录成功时间（毫秒）。设备报文里的 `hyalite`。
  Future<int> loginAt() => _int(_loginAtKey);

  Future<void> saveLoginAt(int value) => _setInt(_loginAtKey, value);

  /// 是否已经上报过（弹出过）定位授权。文档要求：登录后先完成授权再上报。
  Future<bool> hasOpenedBefore() => _bool(_hasOpenedKey);

  /// Adjust 归因 SDK 是否已初始化（跨启动只初始化一次）。
  Future<bool> isAdjustInitialized() => _bool(_adjustInitializedKey);

  Future<void> markAdjustInitialized() => _setBool(_adjustInitializedKey, true);

  /// 标记 App 已启动过一次，返回「本次是否是首次启动」。
  Future<bool> markAppOpened() async {
    final isFirstLaunch = !await _bool(_hasOpenedKey);
    await _setBool(_hasOpenedKey, true);
    return isFirstLaunch;
  }

  /// 设备型号（接口 `omphacy.beautifully`）与物理尺寸（`omphacy.squattest`），
  /// 供设备报文里的 `chlor` / `squattest` 使用。
  Future<String> deviceModel() => _string(_deviceModelKey);

  Future<String> physicalSize() => _string(_physicalSizeKey);

  Future<void> saveDeviceModel(String value) =>
      _setString(_deviceModelKey, value);

  Future<void> savePhysicalSize(String value) =>
      _setString(_physicalSizeKey, value);

  Future<void> saveLocation(ReportLocationSnapshot location) {
    return _setString(_locationKey, jsonEncode(location.toMap()));
  }

  /// 每次启动清掉上一次的定位缓存，避免用旧位置顶替本次授权结果。
  Future<void> clearSessionReportState() => _remove(_locationKey);

  Future<ReportLocationSnapshot?> cachedLocation() async {
    final raw = await _string(_locationKey);
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final location = ReportLocationSnapshot.fromMap(decoded);
      return location.isValid ? location : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _string(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key] as String? ?? '';
    try {
      return await _preferences!.getString(key) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<int> _int(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key] as int? ?? 0;
    try {
      return await _preferences!.getInt(key) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> _bool(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key] as bool? ?? false;
    try {
      return await _preferences!.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setString(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    try {
      await _preferences!.setString(key, value);
    } catch (_) {}
  }

  Future<void> _setInt(String key, int value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    try {
      await _preferences!.setInt(key, value);
    } catch (_) {}
  }

  Future<void> _setBool(String key, bool value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    try {
      await _preferences!.setBool(key, value);
    } catch (_) {}
  }

  Future<void> _remove(String key) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(key);
      return;
    }
    try {
      await _preferences!.remove(key);
    } catch (_) {}
  }
}
