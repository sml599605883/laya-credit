import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'report_data.dart';

/// 上报采集项的原生桥。
///
/// 原生实现见 `ios/Runner/ReportRegistrar.swift`，独立 channel
/// `laya_credit/report`。只做「读取系统采集项」：定位、设备快照、跟踪授权状态；
/// 推送 token 走已有的 [PushBridge]，不在这里重复。
///
/// 所有方法都做降级：方法缺失（未集成原生 / 单元测试）或不支持平台时返回空值，
/// 绝不让上报把业务流程拖崩。
class ReportBridge {
  ReportBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'laya_credit/report';

  static const getReportLocationMethod = 'getReportLocation';
  static const requestLocationPermissionMethod = 'requestLocationPermission';
  static const getReportDeviceSnapshotMethod = 'getReportDeviceSnapshot';
  static const getTrackingStatusMethod = 'getTrackingStatus';
  static const requestTrackingAuthorizationMethod =
      'requestTrackingAuthorization';

  static final shared = ReportBridge();

  final MethodChannel _channel;

  bool get _supported => Platform.isIOS;

  /// 读取当前定位。未授权 / 未决定 / 定位失败时返回 null。
  ///
  /// 只读不弹权限：授权时机对齐 dali，由 [requestLocationPermission] 在
  /// 「点击申请」时显式拉起。
  Future<ReportLocationSnapshot?> getReportLocation() async {
    final result = await _safeInvokeMap(getReportLocationMethod);
    if (result == null) return null;
    final location = ReportLocationSnapshot.fromMap(result);
    return location.isValid ? location : null;
  }

  /// 主动请求定位授权，返回授权状态描述（仅日志用）。
  Future<String> requestLocationPermission() =>
      _safeInvokeString(requestLocationPermissionMethod);

  /// 读取设备快照。失败时返回一个全空的快照，字段值由上层兜底。
  Future<ReportDeviceSnapshot> getReportDeviceSnapshot() async {
    final result = await _safeInvokeMap(getReportDeviceSnapshotMethod);
    return ReportDeviceSnapshot.fromMap(result ?? const <Object?, Object?>{});
  }

  /// 读取 ATT 跟踪授权状态。
  ///
  /// 取值：`not_determined` / `restricted` / `denied` / `authorized`，
  /// 原生缺失时返回空串。
  Future<String> getTrackingStatus() =>
      _safeInvokeString(getTrackingStatusMethod);

  /// 拉起 ATT 授权弹窗（未决定时才有弹窗），返回授权后的状态。
  Future<String> requestTrackingAuthorization() =>
      _safeInvokeString(requestTrackingAuthorizationMethod);

  Future<Map<Object?, Object?>?> _safeInvokeMap(String method) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMapMethod<Object?, Object?>(method);
    } on PlatformException catch (error) {
      debugPrint('[ReportBridge] $method 失败: $error');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<String> _safeInvokeString(String method) async {
    if (!_supported) return '';
    try {
      final value = await _channel.invokeMethod<Object?>(method);
      return value?.toString().trim() ?? '';
    } on PlatformException catch (error) {
      debugPrint('[ReportBridge] $method 失败: $error');
      return '';
    } on MissingPluginException {
      return '';
    }
  }
}
