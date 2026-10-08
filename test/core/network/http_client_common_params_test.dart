import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/device/device_info_cache.dart';
import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/network/api_protocol.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';

void main() {
  setUp(DeviceInfoCache.shared.reset);
  tearDown(DeviceInfoCache.shared.reset);

  test('公参 beautifully 优先用接口下发的设备名称', () {
    DeviceInfoCache.shared.update(deviceName: 'iPhone 12');

    final params = _client().buildSignedQuery('/outsulk/solomon');

    expect(params[ApiProtocol.deviceName], 'iPhone 12');
  });

  test('接口查询完成前回退到本地设备型号', () {
    final params = _client().buildSignedQuery('/outsulk/solomon');

    expect(params[ApiProtocol.deviceName], 'iPhone');
  });
}

HttpClient _client() {
  return HttpClient(
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
