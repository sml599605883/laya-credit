import 'dart:async';
import 'dart:convert';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/report_repository.dart';
import '../push/push_bridge.dart';
import 'report_bridge.dart';
import 'report_data.dart';
import 'report_store.dart';

/// 数据上报服务。
///
/// 参考 Dali Cash 的 `DaliReportService`，按本项目接口文档落地。职责：
/// - 启动 / 恢复 / 登录成功时的定位、设备、google_market、Apple token 上报；
/// - 认证流程各页面的风控埋点（场景 1~10）；
/// - 同盾活体结果上报。
///
/// 约定：**所有上报失败都只打日志**，绝不向业务层抛异常——上报是旁路能力，
/// 不能因为它异常就影响登录、认证、借款这些主流程。
///
/// **不上报通讯录**：接口文档里的 `/outsulk/kailua` 不接入本项目。
class ReportService {
  ReportService(
    this.repository,
    this.bridge, {
    ReportStore? store,
    PushBridge? pushBridge,
    required this.encryptKey,
    required this.encryptIv,
    required this.accessToken,
    Stream<PushEvent>? pushEvents,
    int Function()? nowMillis,
    Future<void> Function(String token)? initializeAdjust,
  }) : store = store ?? ReportStore(),
       _pushBridge = pushBridge ?? PushBridge.shared,
       _events = pushEvents,
       _nowMillis = nowMillis ?? (() => DateTime.now().millisecondsSinceEpoch),
       _initializeAdjust = initializeAdjust ?? _startAdjust;

  static ReportService? current;

  /// 配置全局单例。重复调用返回已有实例（幂等）。
  static ReportService configure(
    ReportRepository repository,
    ReportBridge bridge, {
    ReportStore? store,
    PushBridge? pushBridge,
    required String encryptKey,
    required String encryptIv,
    required String? Function() accessToken,
    int Function()? nowMillis,
    Future<void> Function(String token)? initializeAdjust,
  }) {
    return current ??= ReportService(
      repository,
      bridge,
      store: store,
      pushBridge: pushBridge,
      encryptKey: encryptKey,
      encryptIv: encryptIv,
      accessToken: accessToken,
      nowMillis: nowMillis,
      initializeAdjust: initializeAdjust,
    );
  }

  /// 清除全局单例，仅供测试。
  @visibleForTesting
  static void reset() => current = null;

  static int nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final ReportRepository repository;
  final ReportBridge bridge;
  final ReportStore store;
  final String encryptKey;
  final String encryptIv;
  final String? Function() accessToken;
  final int Function() _nowMillis;
  final Future<void> Function(String token) _initializeAdjust;

  final PushBridge _pushBridge;
  final Stream<PushEvent>? _events;

  bool _started = false;
  bool _starting = false;
  bool _marketReporting = false;
  bool _startupGoogleReportTriggered = false;
  bool _adjustInitializing = false;
  final Set<String> _reportingAppleTokens = <String>{};
  final Set<String> _reportedAppleTokens = <String>{};
  Future<ReportLocationSnapshot?>? _pendingLocation;
  StreamSubscription<PushEvent>? _pushSubscription;

  /// App 启动时调用一次：清理会话态、开始监听推送 token、执行首轮上报。
  ///
  /// 与 Dali 一致：只有**非首次启动**才在这里直接上报 google_market；首次启动
  /// 时 ATT 还没弹窗，本次跳过，等启动权限流程跑完由
  /// [startupPermissionsResolved] 补报（Apple token 同理）。
  Future<void> start() async {
    if (_started || _starting) return;
    _starting = true;
    try {
      await store.clearSessionReportState();
      final isFirstLaunch = await store.markAppOpened();
      _listenToPushEvents();
      _started = true;
      if (!isFirstLaunch) unawaited(_reportStartupGoogleMarket());
      unawaited(reportLocationAndDevice());
    } catch (error) {
      _log(error);
    } finally {
      _starting = false;
    }
  }

  /// App 回到前台。对齐 Dali：没有必须重做的上报，ATT 重试由权限协调器负责。
  Future<void> resumed() async {}

  /// 启动权限流程（通知 + ATT）完成后调用：补一轮 google_market 与 Apple token 上报。
  ///
  /// 首次启动的 ATT 弹窗在 `start()` 之后才出现，这里才是真正的「可以上报归因」时机。
  Future<void> startupPermissionsResolved() async {
    await _reportStartupGoogleMarket();
    await reportAppleToken();
  }

  /// 登录成功后调用：记录登录时间，并补一轮定位 / 设备 / 归因 / 推送上报。
  Future<void> loginSucceeded() async {
    await store.saveLoginAt(_nowMillis());
    unawaited(reportGoogleMarket());
    unawaited(reportLocationAndDevice());
    unawaited(reportAppleToken(force: true));
  }

  /// 读取当前定位（带单飞：并发调用只触发一次原生定位）。
  Future<ReportLocationSnapshot?> currentLocation() {
    final pending = _pendingLocation;
    if (pending != null) return pending;
    final request = _loadLocation();
    _pendingLocation = request;
    return request.whenComplete(() => _pendingLocation = null);
  }

  Future<ReportLocationSnapshot?> _loadLocation() async {
    try {
      final location = await bridge.getReportLocation().timeout(
        const Duration(seconds: 5),
      );
      if (location == null || !location.isValid) return null;
      await store.saveLocation(location);
      return location;
    } catch (error) {
      _log(error);
      return null;
    }
  }

  /// 定位带兜底：优先用本次定位，超时 / 失败时退回上一次成功缓存。
  Future<ReportLocationSnapshot?> _locationWithFallback() async {
    try {
      final location = await currentLocation();
      if (location != null && location.isValid) return location;
    } catch (_) {}
    return store.cachedLocation();
  }

  Future<bool> _hasSession() async => (accessToken() ?? '').trim().isNotEmpty;

  /// 上报定位 + 设备信息（两者都需要登录态，未登录直接跳过）。
  Future<void> reportLocationAndDevice() async {
    try {
      if (!await _hasSession()) return;
      final location = await _locationWithFallback();
      if (location != null && location.isValid) {
        try {
          await repository.reportLocation(
            province: location.province,
            countryCode: location.countryCode,
            country: location.country,
            street: location.street,
            latitude: location.latitude,
            longitude: location.longitude,
            city: location.city,
          );
        } catch (error) {
          _log(error);
        }
      }
      await reportDevice();
    } catch (error) {
      _log(error);
    }
  }

  /// google_market 上报。
  ///
  /// 与 Dali 一致：**只读**ATT 状态，未决定就直接跳过——ATT 弹窗由
  /// 启动权限流程（`PermissionCoordinator.requestStartupPermissions`）负责，
  /// 上报路径不主动弹窗。没拿到 IDFV 或 adjust_token 时跳过，Adjust 只初始化
  /// 一次（跨启动用 [ReportStore.isAdjustInitialized] 去重）。
  Future<void> reportGoogleMarket() async {
    final status = await bridge.getTrackingStatus();
    if (!_isResolvedTrackingStatus(status)) return;
    await _reportResolvedGoogleMarket();
  }

  /// 启动时的一次性归因上报：每次启动最多触发一次，避免和
  /// [startupPermissionsResolved] 重复请求。
  Future<void> _reportStartupGoogleMarket() async {
    if (_startupGoogleReportTriggered) return;
    final status = await bridge.getTrackingStatus();
    if (!_isResolvedTrackingStatus(status)) return;
    _startupGoogleReportTriggered = true;
    await _reportResolvedGoogleMarket();
  }

  Future<void> _reportResolvedGoogleMarket() async {
    if (_marketReporting) return;
    _marketReporting = true;
    try {
      final snapshot = await bridge.getReportDeviceSnapshot();
      final idfv = reportText(snapshot.idfv);
      if (idfv.isEmpty) return;
      final response = await repository.reportGoogleMarket(
        idfv: idfv,
        idfa: reportText(snapshot.idfa),
      );
      final token = response.data.trim();
      if (token.isEmpty ||
          _adjustInitializing ||
          await store.isAdjustInitialized()) {
        return;
      }
      _adjustInitializing = true;
      try {
        await _initializeAdjust(token);
        await store.markAdjustInitialized();
      } finally {
        _adjustInitializing = false;
      }
    } catch (error) {
      _log(error);
    } finally {
      _marketReporting = false;
    }
  }

  /// 上报设备信息（AES 加密报文）。
  Future<void> reportDevice() async {
    try {
      if (!await _hasSession()) return;
      final snapshot = await bridge.getReportDeviceSnapshot();
      final deviceModel = await _resolveDeviceModel(snapshot);
      final encrypted = encryptReportDevicePayload(
        snapshot: snapshot,
        deviceModel: deviceModel,
        physicalSize: await store.physicalSize(),
        location: await _locationWithFallback(),
        lastLoginAtMillis: await store.loginAt(),
        nowMillis: _nowMillis(),
        key: encryptKey,
        iv: encryptIv,
      );
      await repository.reportDeviceInfo(encryptedPayload: encrypted);
    } catch (error) {
      _log(error);
    }
  }

  /// 设备报文里的 `chlor`：优先用缓存的型号名，没有则按型号标识查一次接口。
  Future<String> _resolveDeviceModel(ReportDeviceSnapshot snapshot) async {
    final cached = await store.deviceModel();
    if (cached.isNotEmpty) return cached;

    final identifier = reportText(snapshot.model);
    if (identifier.isEmpty) return '';
    try {
      final response = await repository.lookupDeviceInfo(
        identifier: identifier,
      );
      final info = response.data;
      if (!response.isSuccess || !info.isValid) return '';
      await store.saveDeviceModel(info.deviceModel);
      await store.savePhysicalSize(info.physicalSize);
      return info.deviceModel;
    } catch (error) {
      _log(error);
      return '';
    }
  }

  /// 上报 Apple 推送 token。
  ///
  /// 对齐 dali：token 为空也照常上报（原生还没拿到 deviceToken 时同样发一次），
  /// 不做「空值跳过」的额外校验。
  Future<void> reportAppleToken({bool force = false}) async {
    String? token;
    try {
      token = (await _pushBridge.getPushToken()).trim();
      if ((!force && _reportedAppleTokens.contains(token)) ||
          !_reportingAppleTokens.add(token)) {
        return;
      }
      await repository.reportApplePushToken(token: token);
      _reportedAppleTokens.add(token);
    } catch (error) {
      _log(error);
    } finally {
      if (token != null) _reportingAppleTokens.remove(token);
    }
  }

  /// 上报风控埋点。
  ///
  /// [scene] 取值见接口文档：1 注册 / 2 认证选择 / 3 证件信息 / 4 人脸照片 /
  /// 5 个人信息 / 6 工作信息 / 7 紧急联系人 / 8 银行卡信息 / 9 开始申贷 /
  /// 10 结束申贷。[startedAtSeconds] 是场景开始时间（秒）。
  Future<void> reportRisk({
    required String productId,
    required String scene,
    String orderNo = '',
    required int startedAtSeconds,
  }) async {
    try {
      final snapshot = await bridge.getReportDeviceSnapshot();
      final location = await _locationWithFallback();
      await repository.reportRisk(
        productId: productId.trim(),
        sceneType: scene.trim(),
        orderNo: orderNo.trim(),
        riskDeviceId: reportText(snapshot.riskDeviceId),
        idfa: reportText(snapshot.idfa),
        longitude: reportText(location?.longitude),
        latitude: reportText(location?.latitude),
        startTime: '$startedAtSeconds',
        endTime: '${_nowMillis() ~/ 1000}',
      );
    } catch (error) {
      _log(error);
    }
  }

  /// 上报同盾活体结果。只要有响应就上报，成功 / 失败都传原始结果。
  Future<void> reportTrustDecisionResult({
    required String livenessId,
    required String requestId,
    required int code,
    required String message,
  }) async {
    try {
      final resultCode = '$code';
      await repository.reportTrustDecisionResult(
        livenessId: livenessId,
        requestId: requestId,
        resultCode: resultCode,
        result: jsonEncode({
          'livenessId': livenessId,
          'requestId': requestId,
          'resultCode': resultCode,
          'resultMessage': message,
        }),
      );
    } catch (error) {
      _log(error);
    }
  }

  void _listenToPushEvents() {
    final events = _events ?? _pushBridge.events();
    _pushSubscription ??= events.listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type == 'push_token') unawaited(reportAppleToken());
    }, onError: _log);
  }

  bool _isResolvedTrackingStatus(String status) {
    final normalized = status.trim();
    return normalized.isNotEmpty && normalized != 'not_determined';
  }

  Future<void> dispose() async {
    await _pushSubscription?.cancel();
    _pushSubscription = null;
  }

  /// 用接口下发的 adjust_token 初始化 Adjust 归因 SDK（与 Dali 一致）。
  static Future<void> _startAdjust(String token) async {
    final config = AdjustConfig(token, AdjustEnvironment.production)
      ..logLevel = AdjustLogLevel.info;
    Adjust.initSdk(config);
  }

  static void _log(Object error) {
    debugPrint('[Report] ${error.runtimeType}: $error');
  }
}
