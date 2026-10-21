import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 数据上报相关的原生约定。
///
/// 与 `ios_permission_config_test.dart` 同一套做法：直接读 Swift 源码断言关键
/// 约定，避免这两条口径（设备 ID 来源、board 取值）在后续改动里被改回去。
void main() {
  test('设备报文 board 固定传占位值，不回传真实板号', () {
    final collector = File('ios/Runner/ReportDeviceSnapshotCollector.swift')
        .readAsStringSync();

    expect(collector, contains('"board": Self.boardPlaceholder'));
    expect(collector, contains('"QC_Reference_Phone"'));
    // 真机板号（`hw.model`，如 `N71mAP`）不再上报。
    expect(collector, isNot(contains('sysctlbyname("hw.model"')));
  });

  test('设备 ID 优先取 keychain，并由 Flutter 公参与设备报文共用', () {
    final registrar = File('ios/Runner/ReportRegistrar.swift')
        .readAsStringSync();
    final body = registrar.substring(
      registrar.indexOf('private func stableVendorIdentifier()'),
      registrar.indexOf('private func deviceModelName()'),
    );

    // 先读 Keychain，首次安装再以当前 IDFV 初始化。Flutter 侧也必须通过
    // `getStableDeviceId` 读取同一值，否则重装后公参与设备报文会不一致。
    expect(
      body.indexOf('keychainValue'),
      lessThan(body.indexOf('identifierForVendor')),
    );
    expect(registrar, contains('case "getStableDeviceId"'));

    final deviceParams = File('lib/core/device/device_params.dart')
        .readAsStringSync();
    expect(deviceParams, contains('getStableDeviceId'));
  });

  test('ATT 决策和 App 重新激活都会广播 tracking_status_changed', () {
    final registrar = File('ios/Runner/ReportRegistrar.swift')
        .readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final reportBridge = File('lib/core/report/report_bridge.dart')
        .readAsStringSync();

    expect(registrar, contains('laya_credit/report_events'));
    expect(registrar, contains('FlutterStreamHandler'));
    expect(registrar, contains('"tracking_status_changed"'));
    expect(registrar, contains('self.publishTrackingStatus()'));
    expect(appDelegate, contains('applicationDidBecomeActive'));
    expect(
      appDelegate,
      contains('ReportRegistrar.shared.publishTrackingStatus()'),
    );
    expect(reportBridge, contains('laya_credit/report_events'));
  });
}
