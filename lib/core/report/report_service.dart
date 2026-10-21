import 'dart:async';
import 'dart:convert';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/report_repository.dart';
import '../push/push_bridge.dart';
import 'device_info_sync.dart';
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
    Stream<ReportEvent>? reportEvents,
    int Function()? nowMillis,
    this.locationTimeout = defaultLocationTimeout,
    this.googleMarketRetryDelay = defaultGoogleMarketRetryDelay,
    Future<void> Function(String token)? initializeAdjust,
  }) : store = store ?? ReportStore(),
       _pushBridge = pushBridge ?? PushBridge.shared,
       _events = pushEvents,
       _reportEventStream = reportEvents,
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
    Stream<ReportEvent>? reportEvents,
    int Function()? nowMillis,
    Duration locationTimeout = defaultLocationTimeout,
    Duration googleMarketRetryDelay = defaultGoogleMarketRetryDelay,
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
      reportEvents: reportEvents,
      nowMillis: nowMillis,
      locationTimeout: locationTimeout,
      googleMarketRetryDelay: googleMarketRetryDelay,
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
  final Duration locationTimeout;
  final Duration googleMarketRetryDelay;
  final Future<void> Function(String token) _initializeAdjust;

  final PushBridge _pushBridge;
  final Stream<PushEvent>? _events;
  final Stream<ReportEvent>? _reportEventStream;

  /// 读取定位的兜底时长，对齐 peso_shield。
  static const defaultLocationTimeout = Duration(seconds: 3);

  /// Market 请求失败后的自动重试间隔。
  static const defaultGoogleMarketRetryDelay = Duration(seconds: 1);
  static const _maxGoogleMarketRetries = 2;

  bool _started = false;
  bool _starting = false;
  bool _googleMarketReportSucceeded = false;
  bool _waitingForTrackingDecision = false;
  bool _marketRetryPending = false;
  int _marketRetryAttempt = 0;
  bool _adjustInitializing = false;
  Future<ReportLocationSnapshot?>? _pendingLocation;
  Future<void>? _deviceInfoSync;
  Future<bool>? _marketReportInFlight;
  Timer? _marketRetryTimer;
  StreamSubscription<PushEvent>? _pushSubscription;
  StreamSubscription<ReportEvent>? _reportSubscription;
  final Set<String> _reportingAppleTokens = <String>{};
  final Set<String> _reportedAppleTokens = <String>{};
  Future<void>? _startupAppleTokenReport;
  bool _startupPermissionsResolved = false;

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
      _waitingForTrackingDecision = isFirstLaunch;
      _listenToPushEvents();
      _listenToReportEvents();
      _started = true;
      if (!isFirstLaunch) unawaited(_reportStartupGoogleMarket());
      // 设备信息已在网络探测（`StartupNetworkGate`）时串行查过一次并落库 / 落缓存，
      // 这里不再重复请求；[syncDeviceInfo] 仅作为上报路径的兜底重试保留。
      unawaited(reportLocationAndDevice());
    } catch (error) {
      _log(error);
    } finally {
      _starting = false;
    }
  }

  /// App 回到前台：ATT 重试仍由权限协调器负责，这里只补报待完成事项。
  Future<void> resumed() async {
    if (_marketRetryPending) {
      await reportGoogleMarket();
      return;
    }
    if (!_waitingForTrackingDecision) return;
    await _reportStartupGoogleMarket();
  }

  /// 启动权限流程（通知 + ATT）完成后调用：补一轮 google_market 与 Apple token 上报。
  ///
  /// 首次启动的 ATT 弹窗在 `start()` 之后才出现，这里才是真正的「可以上报归因」时机。
  Future<void> startupPermissionsResolved() async {
    await _reportStartupGoogleMarket();
    _startupPermissionsResolved = true;
    await _reportStartupAppleToken();
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
        locationTimeout,
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
      final location = await currentLocation().timeout(locationTimeout);
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
  /// 上报路径不主动弹窗。没拿到 IDFV 时跳过；adjust_token 为空时不初始化
  /// Adjust（跨启动用 [ReportStore.isAdjustInitialized] 去重）。
  Future<void> reportGoogleMarket() async {
    final status = await bridge.getTrackingStatus();
    if (!_isResolvedTrackingStatus(status)) {
      _waitingForTrackingDecision = true;
      _logMarketSkip('ATT status is unresolved', status);
      return;
    }
    _waitingForTrackingDecision = false;
    await _attemptResolvedGoogleMarket();
  }

  /// 启动归因上报。只有业务成功后才记为完成，失败后仍允许
  /// [tracking_status_changed]、登录和前台恢复继续重试。
  Future<void> _reportStartupGoogleMarket() async {
    if (_googleMarketReportSucceeded) return;
    final status = await bridge.getTrackingStatus();
    if (!_isResolvedTrackingStatus(status)) {
      _waitingForTrackingDecision = true;
      _logMarketSkip('ATT status is unresolved', status);
      return;
    }
    _waitingForTrackingDecision = false;
    await _attemptResolvedGoogleMarket();
  }

  Future<void> _attemptResolvedGoogleMarket() async {
    final succeeded = await _reportResolvedGoogleMarket();
    if (succeeded) {
      // 任一触发点的成功结果都能满足启动上报；登录触发的报错后重试成功时，
      // 后续权限完成事件也不应再发一条。
      _googleMarketReportSucceeded = true;
      _marketRetryPending = false;
      _marketRetryAttempt = 0;
      _marketRetryTimer?.cancel();
      _marketRetryTimer = null;
      return;
    }
    _marketRetryPending = true;
    _scheduleGoogleMarketRetry();
  }

  /// 同一次 Market 请求在多个触发点重叠时共享同一个 Future，避免后到的
  /// 登录 / 权限事件直接放弃上报。
  Future<bool> _reportResolvedGoogleMarket() {
    final pending = _marketReportInFlight;
    if (pending != null) return pending;

    late final Future<bool> request;
    request = _performGoogleMarketReport().whenComplete(() {
      if (identical(_marketReportInFlight, request)) {
        _marketReportInFlight = null;
      }
    });
    _marketReportInFlight = request;
    return request;
  }

  Future<bool> _performGoogleMarketReport() async {
    try {
      final snapshot = await bridge.getReportDeviceSnapshot();
      final idfv = reportText(snapshot.idfv);
      if (idfv.isEmpty) {
        _logMarketSkip('IDFV is empty');
        return false;
      }
      final response = await repository.reportGoogleMarket(
        idfv: idfv,
        idfa: reportText(snapshot.idfa),
      );
      if (!response.isSuccess) {
        debugPrint(
          '[Report] google_market failed: '
          'code=${response.code}, message=${response.message}',
        );
        return false;
      }
      final token = response.data.trim();
      if (token.isNotEmpty &&
          !_adjustInitializing &&
          !await store.isAdjustInitialized()) {
        _adjustInitializing = true;
        try {
          await _initializeAdjust(token);
          await store.markAdjustInitialized();
        } catch (error) {
          _log(error);
        } finally {
          _adjustInitializing = false;
        }
      }
      return true;
    } catch (error) {
      _log(error);
      return false;
    }
  }

  void _scheduleGoogleMarketRetry() {
    if (_marketRetryTimer != null ||
        _marketRetryAttempt >= _maxGoogleMarketRetries) {
      return;
    }
    _marketRetryAttempt++;
    _marketRetryTimer = Timer(googleMarketRetryDelay, () {
      _marketRetryTimer = null;
      if (!_started || !_marketRetryPending) return;
      unawaited(reportGoogleMarket());
    });
  }

  void _logMarketSkip(String reason, [String status = '']) {
    final suffix = status.trim().isEmpty ? '' : ', status=$status';
    debugPrint('[Report] google_market skipped: $reason$suffix');
  }

  /// 上报设备信息（AES 加密报文）。
  Future<void> reportDevice() async {
    try {
      if (!await _hasSession()) return;
      final snapshot = await bridge.getReportDeviceSnapshot();
      final deviceModel = await _resolveDeviceModel();
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

  /// 按设备型号标识查询 iOS 设备名称 / 物理尺寸并落库 + 落进程内缓存。
  ///
  /// 正常启动时该查询已由 `StartupNetworkGate` 在网络探测阶段串行执行过一次
  /// （对齐 Dali），这里只在缓存缺失时兜底重试：**不要求登录态**，失败只打日志。
  /// 与 [reportDevice] 共用单飞，避免同一进程内重复请求同一接口。
  Future<void> syncDeviceInfo() {
    return _deviceInfoSync ??= _syncDeviceInfo().whenComplete(() {
      _deviceInfoSync = null;
    });
  }

  Future<void> _syncDeviceInfo() async {
    await DeviceInfoSync(
      repository: repository,
      bridge: bridge,
      store: store,
    ).sync();
  }

  /// 设备报文里的 `chlor`：优先读缓存（启动预热已写入），没有则兜底再查一次。
  Future<String> _resolveDeviceModel() async {
    final cached = await store.deviceModel();
    if (cached.isNotEmpty) return cached;
    await syncDeviceInfo();
    return store.deviceModel();
  }

  /// 上报 Apple 推送 token。
  ///
  /// 启动阶段只允许一个上报批次。权限流程完成后由
  /// [startupPermissionsResolved] 发一次请求；期间到达的 `push_token` 事件只
  /// 更新原生缓存，不再独立发请求。登录成功仍通过 [force] 发起独立补报。
  Future<void> reportAppleToken({bool force = false}) async {
    await _reportAppleToken(force: force);
  }

  Future<void> _reportStartupAppleToken() {
    final pending = _startupAppleTokenReport;
    if (pending != null) return pending;

    final report = _reportAppleToken(force: false).then((success) {
      if (!success) {
        // 业务或网络失败不算本批次已完成，后续 token 事件仍可重试。
        _startupAppleTokenReport = null;
      }
    });
    _startupAppleTokenReport = report;
    return report;
  }

  Future<bool> _reportAppleToken({required bool force}) async {
    final token = (await _pushBridge.getPushToken()).trim();
    var claimed = false;
    try {
      if (!force && _reportedAppleTokens.contains(token)) return true;
      if (!_reportingAppleTokens.add(token)) return false;
      claimed = true;

      final response = await repository.reportApplePushToken(token: token);
      if (!response.isSuccess) return false;
      _reportedAppleTokens.add(token);
      return true;
    } catch (error) {
      _log(error);
      return false;
    } finally {
      if (claimed) _reportingAppleTokens.remove(token);
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
    // 场景耗时在调用埋点时立即封口。设备快照和定位都是异步的，
    // 等它们返回再取 now 会把相邻的 8 / 9 压到同一秒。
    final endedAtSeconds = _nowMillis() ~/ 1000;
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
        endTime: '$endedAtSeconds',
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
      if (type == 'push_token' && _startupPermissionsResolved) {
        unawaited(_reportStartupAppleToken());
      }
    }, onError: _log);
  }

  void _listenToReportEvents() {
    final events = _reportEventStream ?? bridge.events();
    _reportSubscription ??= events.listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type != 'tracking_status_changed') return;

      final status = event['status']?.toString().trim() ?? '';
      if (!_isResolvedTrackingStatus(status)) return;

      _waitingForTrackingDecision = false;
      if (_googleMarketReportSucceeded) {
        if (_marketRetryPending) unawaited(reportGoogleMarket());
        return;
      }
      // 事件里的 status 是原生刚读到的最终值，直接上报，避免再次查询时
      // 偶发返回旧的 not_determined 又把本次机会丢掉。
      unawaited(_attemptResolvedGoogleMarket());
    }, onError: _log);
  }

  bool _isResolvedTrackingStatus(String status) {
    final normalized = status.trim();
    return normalized.isNotEmpty && normalized != 'not_determined';
  }

  Future<void> dispose() async {
    _marketRetryTimer?.cancel();
    _marketRetryTimer = null;
    await _pushSubscription?.cancel();
    _pushSubscription = null;
    await _reportSubscription?.cancel();
    _reportSubscription = null;
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
