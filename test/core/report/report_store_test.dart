import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/report/report.dart';

void main() {
  group('ReportStore', () {
    test('markAppOpened 只有首次返回 true', () async {
      final store = ReportStore.memory();
      expect(await store.markAppOpened(), isTrue);
      expect(await store.markAppOpened(), isFalse);
    });

    test('登录时间默认 0，可读写', () async {
      final store = ReportStore.memory();
      expect(await store.loginAt(), 0);
      await store.saveLoginAt(1712345678901);
      expect(await store.loginAt(), 1712345678901);
    });

    test('定位缓存按有效值保存，clearSessionReportState 会清掉', () async {
      final store = ReportStore.memory();
      expect(await store.cachedLocation(), isNull);

      await store.saveLocation(
        const ReportLocationSnapshot(latitude: '14.6', longitude: '121.0'),
      );
      final cached = await store.cachedLocation();
      expect(cached?.latitude, '14.6');
      expect(cached?.longitude, '121.0');

      await store.clearSessionReportState();
      expect(await store.cachedLocation(), isNull);
    });

    test('设备型号 / 物理尺寸可读写', () async {
      final store = ReportStore.memory();
      expect(await store.deviceModel(), '');
      expect(await store.physicalSize(), '');

      await store.saveDeviceModel('iPhone 6s Plus');
      await store.savePhysicalSize('5.5');
      expect(await store.deviceModel(), 'iPhone 6s Plus');
      expect(await store.physicalSize(), '5.5');
    });
  });
}
