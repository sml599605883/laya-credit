import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/network/api_crypto.dart';
import 'package:laya_credit/core/report/report.dart';

const _key = '27f7dd9897297dbd';
const _iv = '9feade03e8f337e2';

void main() {
  group('reportText', () {
    test('空值 / 空串 / 字面量 null 都回落到兜底值', () {
      expect(reportText(null), '');
      expect(reportText('  '), '');
      expect(reportText('null'), '');
      expect(reportText(null, fallback: '0'), '0');
    });

    test('正常值去掉首尾空白后原样返回', () {
      expect(reportText('  iPhone  '), 'iPhone');
    });
  });

  group('ReportLocationSnapshot', () {
    test('只要任一定位字段有值就判定为有效', () {
      expect(const ReportLocationSnapshot().isValid, isFalse);
      expect(const ReportLocationSnapshot(latitude: '1.1').isValid, isTrue);
      expect(const ReportLocationSnapshot(city: 'Manila').isValid, isTrue);
    });

    test('fromMap 读取原生回传的字段并兼容 subAdminArea', () {
      final snapshot = ReportLocationSnapshot.fromMap({
        'province': 'Metro Manila',
        'subAdminArea': 'Quezon City',
        'countryCode': 'PH',
        'latitude': '14.6',
        'longitude': '121.0',
        'permissionStatus': 'authorized_when_in_use',
      });
      expect(snapshot.province, 'Metro Manila');
      expect(snapshot.locality, 'Quezon City');
      expect(snapshot.countryCode, 'PH');
      expect(snapshot.permissionStatus, 'authorized_when_in_use');
    });
  });

  group('encryptReportDevicePayload', () {
    const snapshot = ReportDeviceSnapshot(
      idfv: 'idfv-1',
      board: 'D79AP',
      idfa: 'idfa-1',
      deviceName: 'QC_Reference_Phone',
      modelName: 'iPhone',
      brand: 'iPhone',
      model: 'iPhone11,8',
      systemVersion: '15.6.2',
      packageName: 'com.credit.instant.ios',
      batteryLevel: 70,
      isCharging: 1,
      uptimeMillis: '74553635',
      elapsedMillis: 33162972,
      cpuCoreCount: 8,
      screenHeight: 736,
      screenWidth: 414,
      currentWifiName: 'Shu_Xing',
      currentWifiBssid: '68:d7:9a:7b:71:36',
      wifiCount: 1,
      language: 'en',
      carrier: 'MTN',
      networkType: 'WIFI',
      timeZoneName: 'GMT+8',
      innerIp: '10.0.226.79',
      availableStorage: '44522557440',
      totalStorage: '63968497664',
      totalMemory: '2085601280',
      availableMemory: '639598592',
    );

    const location = ReportLocationSnapshot(
      province: 'Metro Manila',
      city: 'Manila',
      country: 'Philippines',
      countryCode: 'PH',
      street: 'Ayala',
      latitude: '14.6',
      longitude: '121.0',
    );

    test('加密报文可解密且关键字段按接口文档映射', () {
      final encrypted = encryptReportDevicePayload(
        snapshot: snapshot,
        deviceModel: 'iPhone 6s Plus',
        physicalSize: '5.5',
        location: location,
        lastLoginAtMillis: 1677412062512,
        nowMillis: 1677486615496,
        key: _key,
        iv: _iv,
      );

      final decoded = jsonDecode(
        ApiCrypto(key: _key, iv: _iv).decryptText(encrypted),
      ) as Map<String, dynamic>;

      // 文档标注已弃用的 deceleron 不传。
      expect(decoded.containsKey('deceleron'), isFalse);
      expect(decoded['deporting'], '15.6.2');
      expect(decoded['hyalite'], 1677412062512);
      expect(decoded['alarmable'], 'com.credit.instant.ios');

      final parson = decoded['parson'] as Map<String, dynamic>;
      expect(parson['untighten'], 70);
      expect(parson['nonmeasurability'], 1);

      final scalloper = decoded['scalloper'] as Map<String, dynamic>;
      expect(scalloper['print'], '121.0');
      expect(scalloper['martite'], '14.6');
      final conceive = scalloper['conceive'] as Map<String, dynamic>;
      expect(conceive['halona'], 'Philippines');
      expect(conceive['introduction'], 'PH');
      expect(conceive['dsri'], 'Metro Manila');
      expect(conceive['loud'], 'Manila');

      final preelectronic = decoded['preelectronic'] as Map<String, dynamic>;
      expect(preelectronic['midshipmanship'], 'idfv-1');
      expect(preelectronic['diamagnetism'], 'idfa-1');
      expect(preelectronic['hieromachy'], 1677486615496);
      expect(preelectronic['capanne'], isEmpty);

      final device = decoded['herculanensian'] as Map<String, dynamic>;
      expect(device['amativeness'], 'D79AP');
      expect(device['compensatingly'], 'QC_Reference_Phone');
      expect(device['hammer'], 'iPhone');
      expect(device['chlor'], 'iPhone 6s Plus');
      expect(device['squattest'], '5.5');
      expect(device['unforbidden'], '15.6.2');

      final demits = decoded['demits'] as Map<String, dynamic>;
      final wifi = (demits['between'] as List).first as Map<String, dynamic>;
      expect(wifi['harbingers'], 'Shu_Xing');
      expect(wifi['spd'], '68:d7:9a:7b:71:36');
      expect(demits['allmouths'], 1);

      final storage = decoded['heretical'] as Map<String, dynamic>;
      expect(storage['unsnobbish'], '44522557440');
      expect(storage['ez'], '63968497664');
      expect(storage['ge'], '2085601280');
      expect(storage['semmes'], '639598592');
    });

    test('定位缺失时位置字段回落为空串而不是 null', () {
      final encrypted = encryptReportDevicePayload(
        snapshot: snapshot,
        deviceModel: '',
        physicalSize: '',
        location: null,
        lastLoginAtMillis: 0,
        nowMillis: 0,
        key: _key,
        iv: _iv,
      );

      final decoded = jsonDecode(
        ApiCrypto(key: _key, iv: _iv).decryptText(encrypted),
      ) as Map<String, dynamic>;
      final scalloper = decoded['scalloper'] as Map<String, dynamic>;
      expect(scalloper['print'], '');
      expect(scalloper['martite'], '');
      expect(scalloper['stonefort'], '');
    });
  });
}
