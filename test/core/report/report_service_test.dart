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
  setUp(ReportService.reset);
  tearDown(ReportService.reset);

  test('Apple 推送 token 为空时照常上报', () async {
    final repository = _RecordingRepository();
    final service = _service(repository, pushToken: '');

    await service.reportAppleToken();

    expect(repository.appleTokens, ['']);
  });

  test('突发窗口内同一 token 只上报一次，窗口过后重新上报', () async {
    var now = DateTime.now().millisecondsSinceEpoch;
    final repository = _RecordingRepository();
    final service = _service(
      repository,
      pushToken: 'token-1',
      nowMillis: () => now,
    );

    await service.reportAppleToken();
    await service.reportAppleToken();
    await service.reportAppleToken();
    expect(repository.appleTokens, ['token-1']);

    now += ReportService.appleTokenBurstWindow.inMilliseconds + 1;
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

  test('push_token 事件与启动补报重叠时只上报一次', () async {
    var now = DateTime.now().millisecondsSinceEpoch;
    final repository = _RecordingRepository();
    final events = StreamController<PushEvent>.broadcast();
    addTearDown(events.close);
    final service = _service(
      repository,
      pushToken: 'token-2',
      events: events.stream,
      nowMillis: () => now,
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
    final repository = _RecordingRepository()..releaseDeviceLookup = Completer();
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
}

ReportService _service(
  ReportRepository repository, {
  required String pushToken,
  ReportBridge? bridge,
  ReportStore? store,
  String accessToken = 'token',
  Stream<PushEvent>? events,
  int Function()? nowMillis,
}) {
  return ReportService(
    repository,
    bridge ?? ReportBridge(),
    store: store ?? ReportStore.memory(),
    pushBridge: _StubPushBridge(pushToken),
    encryptKey: '0123456789abcdef',
    encryptIv: '0123456789abcdef',
    accessToken: () => accessToken,
    pushEvents: events,
    nowMillis: nowMillis,
  );
}

class _StubReportBridge extends ReportBridge {
  @override
  Future<ReportDeviceSnapshot> getReportDeviceSnapshot() async {
    return const ReportDeviceSnapshot(model: 'iPhone11,8');
  }
}

class _StubPushBridge extends PushBridge {
  _StubPushBridge(this._token);

  final String _token;

  @override
  Future<String> getPushToken() async => _token;
}

class _RecordingRepository extends ReportRepository {
  _RecordingRepository() : super(_StubHttpClient());

  final List<String> appleTokens = [];
  final List<String> deviceLookups = [];

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
