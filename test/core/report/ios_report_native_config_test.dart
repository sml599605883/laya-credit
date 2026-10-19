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

  test('设备 ID 取当前 idfv，keychain 只作兜底', () {
    final registrar = File('ios/Runner/ReportRegistrar.swift')
        .readAsStringSync();
    final body = registrar.substring(
      registrar.indexOf('private func stableVendorIdentifier()'),
      registrar.indexOf('private func deviceModelName()'),
    );

    // 先读当前 idfv（卸载重装后会变），keychain 只在 idfv 拿不到时兜底；
    // 反过来的话，公参 `genuflection` / `shapely` 会和设备报文里的 idfv 对不上。
    expect(
      body.indexOf('identifierForVendor'),
      lessThan(body.indexOf('keychainValue')),
    );
  });
}
