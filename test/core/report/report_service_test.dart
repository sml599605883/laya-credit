import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/core/push/push_bridge.dart';
import 'package:laya_credit/core/report/report.dart';
import 'package:laya_credit/data/repositories/report_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ReportService.reset);
  tearDown(ReportService.reset);

  test('拒绝后空 token 只报一次', () async {
    final repository = _RecordingRepository();
    final service = _service(repository, pushToken: '');

    await service.reportAppleToken();
    await service.reportAppleToken();

    expect(repository.appleTokens, ['']);
  });

  test('同一 token 进程内只成功上报一次，登录成功强制补报', () async {
    final repository = _RecordingRepository();
    final service = _service(repository, pushToken: 'token-1');

    await service.reportAppleToken();
    await service.reportAppleToken();
    await service.reportAppleToken();
    expect(repository.appleTokens, ['token-1']);

    await service.reportAppleToken(force: true);
    expect(repository.appleTokens, ['token-1', 'token-1']);

    await service.reportAppleToken();
    expect(repository.appleTokens, ['token-1', 'token-1']);
  });

  test('并发调用只会真正发出一条请求', () async {
    final repository = _RecordingRepository()..releaseFirstCall = Completer();
    final service = _service(repository, pushToken: 'token-1');

    final first = service.reportAppleToken();
    final second = service.reportAppleToken();
    repository.releaseFirstCall!.complete();
    await Future.wait([first, second]);

    expect(repository.appleTokens, ['token-1']);
  });

  test('启动权限完成前的 token 事件不单独上报，只报最终真值', () async {
    final repository = _RecordingRepository();
    final pushBridge = _StubPushBridge('');
    final events = StreamController<PushEvent>.broadcast();
    addTearDown(events.close);
    final service = _service(
      repository,
      pushToken: '',
      pushBridge: pushBridge,
      events: events.stream,
    );

    await service.start();
    pushBridge.setToken('token-early');
    events.add(const {'type': 'push_token', 'token': 'token-early'});
    await pumpEventQueue();
    expect(repository.appleTokens, isEmpty);

    pushBridge.setToken('token-latest');
    events.add(const {'type': 'push_token', 'token': 'token-latest'});
    await pumpEventQueue();
    expect(repository.appleTokens, isEmpty);

    await service.startupPermissionsResolved();
    expect(repository.appleTokens, ['token-latest']);

    pushBridge.setToken('token-after-startup');
    events.add(const {'type': 'push_token', 'token': 'token-after-startup'});
    await pumpEventQueue();
    expect(repository.appleTokens, ['token-latest']);
    await service.dispose();
  });

  test('ATT 状态延迟变化后由 tracking_status_changed 补报 Market', () async {
    final repository = _RecordingRepository();
    final reportEvents = StreamController<ReportEvent>.broadcast();
    addTearDown(reportEvents.close);
    final bridge = _StubReportBridge(
      trackingStatus: 'not_determined',
      idfv: 'idfv-1',
    );
    final service = _service(
      repository,
      pushToken: 'token-1',
      bridge: bridge,
      reportEvents: reportEvents.stream,
    );

    await service.start();
    await service.startupPermissionsResolved();
    expect(repository.marketCalls, 0);
    expect(repository.appleTokens, ['token-1']);

    // 故意保留旧的 not_determined：事件里的最终状态应当直接驱动上报，
    // 不能再次查询时被旧值挡住。
    reportEvents.add(const {
      'type': 'tracking_status_changed',
      'status': 'authorized',
    });
    await pumpEventQueue();

    expect(repository.marketCalls, 1);
    expect(repository.marketIdfvs, ['idfv-1']);

    reportEvents.add(const {
      'type': 'tracking_status_changed',
      'status': 'authorized',
    });
    await pumpEventQueue();
    expect(repository.marketCalls, 1);

    await service.dispose();
  });

  test('Market 网络和业务失败后自动重试，成功前不记为完成', () async {
    final repository = _RecordingRepository()
      ..marketFailuresToThrow = 1
      ..marketResponseCodes.addAll([400, 0]);
    final bridge = _StubReportBridge(
      trackingStatus: 'authorized',
      idfv: 'idfv-retry',
    );
    final service = _service(
      repository,
      pushToken: 'token-1',
      bridge: bridge,
      googleMarketRetryDelay: Duration.zero,
    );

    await service.start();
    await service.startupPermissionsResolved();
    await pumpEventQueue();

    expect(repository.marketCalls, 3);
    expect(repository.marketIdfvs, ['idfv-retry', 'idfv-retry', 'idfv-retry']);

    await service.dispose();
  });

  test('push_token 事件与启动补报重叠时只上报一次', () async {
    final repository = _RecordingRepository();
    final events = StreamController<PushEvent>.broadcast();
    addTearDown(events.close);
    final service = _service(
      repository,
      pushToken: 'token-2',
      events: events.stream,
    );

    await service.start();
    events.add(const {'type': 'push_token', 'token': 'token-2'});
    await pumpEventQueue();
    // 启动权限流程结束时的补报（ATT 已决定时仅差几百毫秒）。
    await service.startupPermissionsResolved();
    await pumpEventQueue();

    expect(repository.appleTokens, ['token-2']);
    await service.dispose();
  });

  test('启动上报业务失败后，后续 token 事件可以重试', () async {
    final repository = _RecordingRepository();
    repository.appleReportSucceeds = false;
    final pushBridge = _StubPushBridge('token-retry');
    final events = StreamController<PushEvent>.broadcast();
    addTearDown(events.close);
    final service = _service(
      repository,
      pushToken: 'token-retry',
      pushBridge: pushBridge,
      events: events.stream,
    );

    await service.start();
    await service.startupPermissionsResolved();
    expect(repository.appleTokens, ['token-retry']);

    repository.appleReportSucceeds = true;
    events.add(const {'type': 'push_token', 'token': 'token-retry'});
    await pumpEventQueue();

    expect(repository.appleTokens, ['token-retry', 'token-retry']);
    await service.dispose();
  });

  test('推送上报业务失败不进入长期去重，后续事件可以重试', () async {
    final repository = _RecordingRepository()..appleReportSucceeds = false;
    final service = _service(repository, pushToken: 'token-retry');

    await service.reportAppleToken();
    expect(repository.appleTokens, ['token-retry']);

    repository.appleReportSucceeds = true;
    await service.reportAppleToken();
    await service.reportAppleToken();
    expect(repository.appleTokens, ['token-retry', 'token-retry']);
  });

  test('每次启动都按型号查设备信息并落库（不看登录态、不看缓存）', () async {
    final repository = _RecordingRepository();
    final store = ReportStore.memory();
    // 故意先塞一份旧缓存：新逻辑必须照查照写，不能被缓存挡住。
    await store.saveDeviceModel('stale-model');
    final service = _service(
      repository,
      pushToken: '',
      bridge: _StubReportBridge(),
      store: store,
      accessToken: '',
    );

    await service.syncDeviceInfo();

    expect(repository.deviceLookups, ['iPhone11,8']);
    expect(await store.deviceModel(), 'iPhone 12');
    expect(await store.physicalSize(), '6.1');
  });

  test('启动预热与设备上报并发时只查一次设备信息', () async {
    final repository = _RecordingRepository()
      ..releaseDeviceLookup = Completer();
    final service = _service(
      repository,
      pushToken: '',
      bridge: _StubReportBridge(),
      accessToken: 'token',
    );

    final first = service.syncDeviceInfo();
    final second = service.syncDeviceInfo();
    repository.releaseDeviceLookup!.complete();
    await Future.wait([first, second]);

    expect(repository.deviceLookups, ['iPhone11,8']);
  });

  test('埋点结束时间在调用时冻结，不受异步设备读取影响', () async {
    var now = 1000000;
    final repository = _RecordingRepository();
    final service = _service(
      repository,
      pushToken: '',
      bridge: _SlowReportBridge(() => now += 30000),
      nowMillis: () => now,
    );

    await service.reportRisk(
      productId: '1',
      scene: '8',
      orderNo: 'ORDER-1',
      startedAtSeconds: 900000,
    );

    expect(repository.riskEndTimes, ['1000']);
  });

  test('定位挂起时埋点在兜底时间内发出，结束时间不会穿越', () async {
    var now = 2000000;
    final repository = _RecordingRepository();
    final service = _service(
      repository,
      pushToken: '',
      bridge: _HangingLocationReportBridge(),
      nowMillis: () => now,
      locationTimeout: const Duration(milliseconds: 20),
    );

    await service.reportRisk(
      productId: '1',
      scene: '6',
      orderNo: 'ORDER-1',
      startedAtSeconds: 1900000,
    );

    expect(repository.riskEndTimes, ['2000']);
  });
}

ReportService _service(
  ReportRepository repository, {
  required String pushToken,
  ReportBridge? bridge,
  ReportStore? store,
  String accessToken = 'token',
  Stream<PushEvent>? events,
  Stream<ReportEvent>? reportEvents,
  int Function()? nowMillis,
  PushBridge? pushBridge,
  Duration locationTimeout = ReportService.defaultLocationTimeout,
  Duration googleMarketRetryDelay = ReportService.defaultGoogleMarketRetryDelay,
  Future<void> Function(String token)? initializeAdjust,
}) {
  return ReportService(
    repository,
    bridge ?? ReportBridge(),
    store: store ?? ReportStore.memory(),
    pushBridge: pushBridge ?? _StubPushBridge(pushToken),
    encryptKey: '0123456789abcdef',
    encryptIv: '0123456789abcdef',
    accessToken: () => accessToken,
    pushEvents: events,
    reportEvents: reportEvents,
    nowMillis: nowMillis,
    locationTimeout: locationTimeout,
    googleMarketRetryDelay: googleMarketRetryDelay,
    initializeAdjust: initializeAdjust ?? (_) async {},
  );
}

class _StubReportBridge extends ReportBridge {
  _StubReportBridge({this.trackingStatus = '', this.idfv = ''});

  String trackingStatus;
  final String idfv;

  @override
  Future<ReportDeviceSnapshot> getReportDeviceSnapshot() async {
    return ReportDeviceSnapshot(
      model: 'iPhone11,8',
      idfv: idfv,
      idfa: idfv.isEmpty ? '' : 'idfa-1',
    );
  }

  @override
  Future<String> getTrackingStatus() async => trackingStatus;
}

class _SlowReportBridge extends ReportBridge {
  _SlowReportBridge(this.advanceClock);

  final void Function() advanceClock;

  @override
  Future<ReportDeviceSnapshot> getReportDeviceSnapshot() async {
    advanceClock();
    return const ReportDeviceSnapshot(model: 'iPhone11,8');
  }
}

class _HangingLocationReportBridge extends ReportBridge {
  final Completer<ReportLocationSnapshot?> _location =
      Completer<ReportLocationSnapshot?>();

  @override
  Future<ReportDeviceSnapshot> getReportDeviceSnapshot() async {
    return const ReportDeviceSnapshot(model: 'iPhone11,8');
  }

  @override
  Future<ReportLocationSnapshot?> getReportLocation() => _location.future;
}

class _StubPushBridge extends PushBridge {
  _StubPushBridge(this._token);

  String _token;

  /// 模拟原生 APNs 注册完成、真 token 到达。
  void setToken(String token) => _token = token;

  @override
  Future<String> getPushToken() async => _token;
}

class _RecordingRepository extends ReportRepository {
  _RecordingRepository() : super(_StubHttpClient());

  final List<String> appleTokens = [];
  final List<String> marketIdfvs = [];
  final List<int> marketResponseCodes = [];
  final List<String> deviceLookups = [];
  final List<String> riskEndTimes = [];
  bool appleReportSucceeds = true;
  int marketCalls = 0;
  int marketFailuresToThrow = 0;

  /// 非空时第一条上报会等它完成，用来构造并发场景。
  Completer<void>? releaseFirstCall;

  /// 非空时第一条设备查询会等它完成，用来构造并发场景。
  Completer<void>? releaseDeviceLookup;

  @override
  Future<ApiResponse<ReportDeviceInfo>> lookupDeviceInfo({
    required String identifier,
  }) async {
    final release = releaseDeviceLookup;
    if (release != null) {
      releaseDeviceLookup = null;
      await release.future;
    }
    deviceLookups.add(identifier);
    return const ApiResponse<ReportDeviceInfo>(
      code: 0,
      message: '',
      data: ReportDeviceInfo(deviceModel: 'iPhone 12', physicalSize: '6.1'),
    );
  }

  @override
  Future<ApiResponse<void>> reportApplePushToken({
    required String token,
  }) async {
    final release = releaseFirstCall;
    if (release != null) {
      releaseFirstCall = null;
      await release.future;
    }
    appleTokens.add(token);
    return ApiResponse<void>(
      code: appleReportSucceeds ? 0 : 400,
      message: '',
      data: null,
    );
  }

  @override
  Future<ApiResponse<String>> reportGoogleMarket({
    required String idfv,
    required String idfa,
  }) async {
    marketCalls++;
    marketIdfvs.add(idfv);
    if (marketFailuresToThrow > 0) {
      marketFailuresToThrow--;
      throw StateError('market network failed');
    }
    final code = marketResponseCodes.isEmpty
        ? 0
        : marketResponseCodes.removeAt(0);
    return ApiResponse<String>(
      code: code,
      message: code == 0 ? '' : 'market failed',
      data: code == 0 ? 'adjust-token' : '',
    );
  }

  @override
  Future<ApiResponse<void>> reportRisk({
    required String productId,
    required String sceneType,
    required String orderNo,
    required String riskDeviceId,
    required String idfa,
    required String longitude,
    required String latitude,
    required String startTime,
    required String endTime,
  }) async {
    riskEndTimes.add(endTime);
    return const ApiResponse<void>(code: 200, message: '', data: null);
  }
}

class _StubHttpClient extends HttpClient {
  _StubHttpClient()
    : super(
        config: NetworkConfig(
          apiBase: Uri.parse('https://localhost/'),
          signSecret: 'test',
          marketIdentifier: 'test',
        ),
        device: const DeviceParams(
          deviceId: 'test-device',
          appVersion: '1.0.0',
          modelName: 'test',
          systemVersion: '1.0',
          advertisingId: '',
        ),
        getUserToken: () => null,
        onAuthExpired: () {},
      );
}
