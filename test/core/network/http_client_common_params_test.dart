import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/device/device_info_cache.dart';
import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/network/api_exception.dart';
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

  test('认证失效优先透传后端英文文案并触发全局登出', () async {
    var expiredCalls = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          '{"${ApiProtocol.codeField}":'
          '"${ApiProtocol.authErrorCode}",'
          '"${ApiProtocol.messageField}":"Login has expired. Please log in again",'
          '"${ApiProtocol.dataField}":{}}',
        )
        ..close();
    });

    final networkClient = HttpClient(
      config: NetworkConfig(
        apiBase: Uri.parse('http://${server.address.host}:${server.port}/'),
        signSecret: 'test',
        marketIdentifier: 'test',
      ),
      device: _device,
      getUserToken: () => null,
      onAuthExpired: () => expiredCalls++,
    );

    await expectLater(
      networkClient.get<void>('/expired', parse: (_) {}),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.type,
              'type',
              ApiFailureType.authentication,
            )
            .having(
              (error) => error.message,
              'message',
              'Login has expired. Please log in again',
            ),
      ),
    );
    expect(expiredCalls, 1);
  });

  test('认证失效缺少后端文案时使用固定英文兜底', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          '{"${ApiProtocol.codeField}":'
          '"${ApiProtocol.authErrorCode}",'
          '"${ApiProtocol.messageField}":"",'
          '"${ApiProtocol.dataField}":{}}',
        )
        ..close();
    });
    final client = HttpClient(
      config: NetworkConfig(
        apiBase: Uri.parse('http://${server.address.host}:${server.port}/'),
        signSecret: 'test',
        marketIdentifier: 'test',
      ),
      device: _device,
      getUserToken: () => null,
      onAuthExpired: () {},
    );

    await expectLater(
      client.get<void>('/expired', parse: (_) {}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          authExpiredFallbackMessage,
        ),
      ),
    );
  });

  test('网络错误固定使用英文提示', () async {
    final client = HttpClient(
      config: NetworkConfig(
        apiBase: Uri.parse('http://127.0.0.1:1/'),
        signSecret: 'test',
        marketIdentifier: 'test',
        connectionTimeout: const Duration(milliseconds: 300),
      ),
      device: _device,
      getUserToken: () => null,
      onAuthExpired: () {},
    );

    await expectLater(
      client.get<void>('/offline', parse: (_) {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.type, 'type', ApiFailureType.noConnection)
            .having(
              (error) => error.message,
              'message',
              'No internet connection. Please check your network.',
            ),
      ),
    );
  });
}

const _device = DeviceParams(
  deviceId: 'test-device',
  appVersion: '1.0.0',
  modelName: 'iPhone',
  systemVersion: '1.0',
  advertisingId: '',
);

HttpClient _client({void Function()? onAuthExpired}) {
  return HttpClient(
    config: NetworkConfig(
      apiBase: Uri.parse('https://localhost/'),
      signSecret: 'test',
      marketIdentifier: 'test',
    ),
    device: _device,
    getUserToken: () => null,
    onAuthExpired: onAuthExpired ?? () {},
  );
}
