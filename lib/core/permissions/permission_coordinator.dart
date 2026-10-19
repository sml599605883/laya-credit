import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../push/push_bridge.dart';
import '../report/report_bridge.dart';

/// 权限请求动作：返回值只用于幂等 / 日志，不参与业务判定。
typedef PermissionRequester = Future<Object?> Function();

/// 无返回值的权限动作（注册 APNs、拉起定位授权等）。
typedef PermissionAction = Future<void> Function();

/// 可注入的延迟实现，方便单测把 400ms 收敛掉。
typedef PermissionDelay = Future<void> Function(Duration duration);

/// 定位授权状态读取器。
typedef LocationPermissionStatusProvider = Future<PermissionStatus> Function();

/// 系统定位服务开关读取器。
typedef LocationServiceStatusProvider = Future<ServiceStatus> Function();

/// 定位授权结果，决定「立即申请」是放行还是先引导用户去系统设置。
///
/// 取值对齐 Dali 的 `CertificationLocationDecision`。
enum CertificationLocationDecision {
  granted,
  denied,
  settingsRequired,
  serviceDisabled,
}

/// 启动 / 恢复 / 申请借款三个时机的权限协调器（对齐 Dali 的
/// `PermissionCoordinator`）。
///
/// - 启动：延迟后依次申请通知权限 → 注册 APNs → 再延迟后申请 ATT；
/// - 回到前台：重试一次 ATT（首次启动用户可能把授权弹窗留在后台没处理）；
/// - 点击「立即申请」：先确认定位服务与授权状态，再决定放行 / 引导去设置。
///
/// 所有权限调用失败都只吞掉：权限是旁路能力，绝不能影响启动与申请主流程。
class PermissionCoordinator {
  PermissionCoordinator({
    required this.requestNotificationPermission,
    required this.requestTrackingPermission,
    PermissionAction? registerForRemoteNotifications,
    PermissionAction? requestLocationPermission,
    LocationServiceStatusProvider? locationServiceStatusProvider,
    LocationPermissionStatusProvider? locationPermissionStatusProvider,
    LocationPermissionStatusProvider? requestedLocationStatusProvider,
    this.requestDelay = const Duration(milliseconds: 400),
    PermissionDelay? delay,
  }) : _registerForRemoteNotifications =
           registerForRemoteNotifications ?? _noopAction,
       _requestLocationPermission = requestLocationPermission ?? _noopAction,
       _locationServiceStatusProvider =
           locationServiceStatusProvider ?? _defaultLocationServiceStatus,
       _locationPermissionStatusProvider =
           locationPermissionStatusProvider ?? _defaultLocationStatus,
       _requestedLocationStatusProvider =
           requestedLocationStatusProvider ?? _defaultLocationStatus,
       _delay = delay ?? Future<void>.delayed;

  factory PermissionCoordinator.defaultInstance() {
    return PermissionCoordinator(
      requestNotificationPermission: () => Permission.notification.request(),
      registerForRemoteNotifications: () async {
        if (Platform.isIOS) {
          await PushBridge.shared.registerForRemoteNotifications();
        }
      },
      requestTrackingPermission: () {
        if (!Platform.isIOS) {
          return Future<Object?>.value('not_supported');
        }
        // 走原生 ATTrackingManager（与 `getTrackingStatus` 同一来源），
        // 避免 Dart 侧再依赖一份 ATT 权限实现。
        return ReportBridge.shared.requestTrackingAuthorization();
      },
      requestLocationPermission: () async {
        if (!Platform.isIOS) {
          await Permission.locationWhenInUse.request();
          return;
        }
        await ReportBridge.shared.requestLocationPermission();
      },
    );
  }

  static PermissionCoordinator _instance =
      PermissionCoordinator.defaultInstance();

  static PermissionCoordinator get instance => _instance;

  /// 仅供测试替换单例（与 `ReportService.current` / `reset` 同一套路）。
  @visibleForTesting
  static void overrideInstance(PermissionCoordinator coordinator) {
    _instance = coordinator;
  }

  /// 仅供测试恢复默认单例。
  @visibleForTesting
  static void resetInstance() {
    _instance = PermissionCoordinator.defaultInstance();
  }

  final PermissionRequester requestNotificationPermission;
  final PermissionRequester requestTrackingPermission;
  final PermissionAction _registerForRemoteNotifications;
  final PermissionAction _requestLocationPermission;
  final LocationServiceStatusProvider _locationServiceStatusProvider;
  final LocationPermissionStatusProvider _locationPermissionStatusProvider;
  final LocationPermissionStatusProvider _requestedLocationStatusProvider;
  final PermissionDelay _delay;

  /// 与 Dali 一致：留出首帧渲染时间再弹权限，避免启动瞬间连弹多个系统框。
  final Duration requestDelay;

  Future<void>? _startupRequest;
  Future<void>? _resumeRequest;
  Future<CertificationLocationDecision>? _locationRequest;
  bool _startupPermissionsRequested = false;
  bool _requestingLocationPermission = false;

  /// 「立即申请」的定位授权是否正在申请中（含系统弹窗期间）。
  ///
  /// 首页容器用它忽略「系统定位弹窗关闭」带来的生命周期恢复刷新（对齐 dali 的
  /// `MainController._ignoreLocationPermissionResume`）：那一刻准入接口马上要
  /// 自动发出，再刷一次首页 + 弹窗接口既重复请求，弹窗还可能顶进认证流程里。
  bool get isRequestingLocationPermission => _requestingLocationPermission;

  /// 启动权限序列：通知 → 注册 APNs → ATT，整套只会真正跑一次。
  Future<void> requestStartupPermissions() {
    if (_startupPermissionsRequested) return Future<void>.value();
    return _startupRequest ??= _requestStartupPermissions();
  }

  Future<void> _requestStartupPermissions() async {
    try {
      await _delay(requestDelay);
      await requestNotificationPermission();
      await _registerForRemoteNotifications();
      await _delay(requestDelay);
      await requestTrackingPermission();
    } catch (_) {
      // 权限失败不能中断启动流程。
    } finally {
      _startupPermissionsRequested = true;
      _startupRequest = null;
    }
  }

  /// 回到前台时重试一次 ATT，每次恢复都允许重试。
  Future<void> requestResumeTrackingPermission() {
    return _resumeRequest ??= _requestResumeTrackingPermission().whenComplete(
      () => _resumeRequest = null,
    );
  }

  Future<void> _requestResumeTrackingPermission() async {
    try {
      await _delay(requestDelay);
      await requestTrackingPermission();
    } catch (_) {
      // 权限失败不能中断恢复流程。
    }
  }

  /// 「立即申请」前的定位检查，返回放行 / 拒绝 / 需要去设置。
  ///
  /// 并发调用共享同一次请求（`_locationRequest` 单飞）。
  Future<CertificationLocationDecision> requestCertificationLocation() {
    return _locationRequest ??= _requestCertificationLocation().whenComplete(
      () => _locationRequest = null,
    );
  }

  Future<CertificationLocationDecision> _requestCertificationLocation() async {
    try {
      final serviceStatus = await _locationServiceStatusProvider();
      if (serviceStatus != ServiceStatus.enabled) {
        return CertificationLocationDecision.serviceDisabled;
      }

      final status = await _locationPermissionStatusProvider();
      if (_isGranted(status)) return CertificationLocationDecision.granted;
      if (_requiresSettings(status)) {
        return CertificationLocationDecision.settingsRequired;
      }

      // 系统定位弹窗只在这段里出现：期间标记「正在申请」，让首页容器忽略
      // 弹窗关闭后的那次生命周期恢复刷新。
      _requestingLocationPermission = true;
      final PermissionStatus? requestedStatus;
      try {
        requestedStatus = await _requestLocationPermissionUntilInterrupted();
      } finally {
        _requestingLocationPermission = false;
      }
      if (requestedStatus == null) return CertificationLocationDecision.denied;
      if (_isGranted(requestedStatus)) {
        return CertificationLocationDecision.granted;
      }
      if (_requiresSettings(requestedStatus)) {
        return CertificationLocationDecision.settingsRequired;
      }
      return CertificationLocationDecision.settingsRequired;
    } catch (_) {
      return CertificationLocationDecision.denied;
    }
  }

  bool _isGranted(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  bool _requiresSettings(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;

  /// 拉起定位授权，并在 App 被切到后台（例如用户跳去设置）时中断等待，
  /// 让流程可以重新发起一次检查，而不是卡在永远不返回的系统回调上。
  Future<PermissionStatus?> _requestLocationPermissionUntilInterrupted() async {
    final interrupted = Completer<PermissionStatus?>();
    final observer = _LocationPermissionLifecycleObserver(() {
      if (!interrupted.isCompleted) interrupted.complete();
    });
    WidgetsBinding.instance.addObserver(observer);
    try {
      return await Future.any<PermissionStatus?>([
        _requestLocationPermission().then<PermissionStatus?>(
          (_) => _requestedLocationStatusProvider(),
        ),
        interrupted.future,
      ]);
    } finally {
      WidgetsBinding.instance.removeObserver(observer);
    }
  }
}

class _LocationPermissionLifecycleObserver extends WidgetsBindingObserver {
  _LocationPermissionLifecycleObserver(this.onInterrupted);

  final VoidCallback onInterrupted;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      onInterrupted();
    }
  }
}

Future<ServiceStatus> _defaultLocationServiceStatus() =>
    Permission.locationWhenInUse.serviceStatus;

Future<PermissionStatus> _defaultLocationStatus() =>
    Permission.locationWhenInUse.status;

Future<void> _noopAction() async {}
