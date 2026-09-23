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

  test('Apple 推送 token 为空时照常上报（对齐 dali，不做空值跳过）', () async {
    final repository = _RecordingRepository();
    final service = _service(repository, pushToken: '');

    await service.reportAppleToken();

    expect(repository.appleTokens, ['']);
  });

  test('完全不去重：每次调用都上报一次', () async {
    final repository = _RecordingRepository();
    final service = _service(repository, pushToken: 'token-1');

    await service.reportAppleToken();
    await service.reportAppleToken();
    await service.reportAppleToken();

    expect(repository.appleTokens, ['token-1', 'token-1', 'token-1']);
  });

  test('原生 push_token 事件触发一次上报', () async {
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

    expect(repository.appleTokens, ['token-2']);
    await service.dispose();
  });
}

ReportService _service(
  ReportRepository repository, {
  required String pushToken,
  Stream<PushEvent>? events,
}) {
  return ReportService(
    repository,
    ReportBridge(),
    store: ReportStore.memory(),
    pushBridge: _StubPushBridge(pushToken),
    encryptKey: '0123456789abcdef',
    encryptIv: '0123456789abcdef',
    accessToken: () => 'token',
    pushEvents: events,
  );
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

  @override
  Future<ApiResponse<void>> reportApplePushToken({
    required String token,
  }) async {
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
