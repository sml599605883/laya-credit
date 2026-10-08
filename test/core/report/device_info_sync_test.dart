import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/device/device_info_cache.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/report/report.dart';
import 'package:laya_credit/core/report/device_info_sync.dart';
import 'package:laya_credit/data/repositories/report_repository.dart';

void main() {
  setUp(DeviceInfoCache.shared.reset);
  tearDown(DeviceInfoCache.shared.reset);

  test('查询成功时同时写入 ReportStore 与 DeviceInfoCache', () async {
    final store = ReportStore.memory();
    final sync = DeviceInfoSync(
      repository: _StubRepository(
        const ReportDeviceInfo(deviceModel: 'iPhone 12', physicalSize: '6.1'),
      ),
      bridge: _StubBridge(),
      store: store,
    );

    await sync.sync();

    expect(await store.deviceModel(), 'iPhone 12');
    expect(await store.physicalSize(), '6.1');
    expect(DeviceInfoCache.shared.deviceName, 'iPhone 12');
    expect(DeviceInfoCache.shared.physicalSize, '6.1');
  });

  test('网络失败时用落库值预热缓存，公参仍能带上一次查到的设备名', () async {
    final store = ReportStore.memory();
    await store.saveDeviceModel('iPhone 11');
    await store.savePhysicalSize('6.1');
    final sync = DeviceInfoSync(
      repository: _StubRepository(null),
      bridge: _StubBridge(),
      store: store,
    );

    await sync.sync();

    expect(DeviceInfoCache.shared.deviceName, 'iPhone 11');
    expect(DeviceInfoCache.shared.physicalSize, '6.1');
  });

  test('标识为空时不发查询', () async {
    final repository = _StubRepository(
      const ReportDeviceInfo(deviceModel: 'iPhone 12', physicalSize: '6.1'),
    );
    final sync = DeviceInfoSync(
      repository: repository,
      bridge: _StubBridge(model: ''),
      store: ReportStore.memory(),
    );

    await sync.sync();

    expect(repository.lookups, isEmpty);
    expect(DeviceInfoCache.shared.deviceName, '');
  });
}

class _StubBridge extends ReportBridge {
  _StubBridge({this.model = 'iPhone11,8'});

  final String model;

  @override
  Future<ReportDeviceSnapshot> getReportDeviceSnapshot() async {
    return ReportDeviceSnapshot(model: model);
  }
}

class _StubRepository extends ReportRepository {
  _StubRepository(this.info) : super(_StubHttpClient());

  final ReportDeviceInfo? info;
  final List<String> lookups = [];

  @override
  Future<ApiResponse<ReportDeviceInfo>> lookupDeviceInfo({
    required String identifier,
  }) async {
    lookups.add(identifier);
    final info = this.info;
    if (info == null) throw Exception('offline');
    return ApiResponse<ReportDeviceInfo>(code: 0, message: '', data: info);
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
          modelName: 'iPhone',
          systemVersion: '1.0',
          advertisingId: '',
        ),
        getUserToken: () => null,
        onAuthExpired: () {},
      );
}
