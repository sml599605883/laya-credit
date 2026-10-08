import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/network/api_endpoints.dart';
import 'package:laya_credit/core/network/api_fields.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/data/models/app_dialog.dart';
import 'package:laya_credit/data/repositories/app_repository.dart';
import 'package:laya_credit/pages/widgets/app_marketing_popup.dart';
import 'package:laya_credit/pages/widgets/app_upgrade_popup.dart';

/// 只记录请求、不发网络，用来校验仓库层传出的路径与字段名。
class _RecordingClient extends HttpClient {
  _RecordingClient()
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

  final List<(String, Map<String, Object?>)> calls = [];

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, Object?>? params,
    required T Function(Object? data) parse,
  }) async {
    calls.add((path, params ?? const {}));
    return ApiResponse<T>(code: 0, message: 'success', data: parse(null));
  }
}

void main() {
  group('AppDialog', () {
    test('按接口文档的混淆字段解析应用内升级弹窗', () {
      final dialog = AppDialog.fromJson({
        ApiFields.popupType: 1,
        ApiFields.popupData: {
          ApiFields.popupUpgradeVersion: '1.1.4',
          ApiFields.popupUpgradeMessage: 'New version 1.1.4 is now available',
          ApiFields.popupUrl: 'https://cdn.example/app',
        },
      });

      expect(dialog.type, AppPopupType.appUpgrade);
      expect(dialog.hasPopup, isTrue);
      expect(dialog.displayVersion, 'V1.1.4');
      expect(dialog.message, 'New version 1.1.4 is now available');
      expect(dialog.targetUrl, 'https://cdn.example/app');
    });

    test('版本号已带 V 前缀时不重复拼接', () {
      final dialog = AppDialog.fromJson({
        ApiFields.popupType: 1,
        ApiFields.popupData: {ApiFields.popupUpgradeVersion: 'V2.0.0'},
      });
      expect(dialog.displayVersion, 'V2.0.0');
    });

    test('按接口文档的混淆字段解析营销弹窗', () {
      final dialog = AppDialog.fromJson({
        ApiFields.popupType: 3,
        ApiFields.popupData: {
          ApiFields.popupMarketingImage: 'https://cdn.example/marketing.png',
          ApiFields.popupUrl: 'https://h5.example/recommend',
        },
      });

      expect(dialog.type, AppPopupType.marketing);
      expect(dialog.hasPopup, isTrue);
      expect(dialog.imageUrl, 'https://cdn.example/marketing.png');
      expect(dialog.targetUrl, 'https://h5.example/recommend');
    });

    test('营销弹窗没有下发图片时按无弹窗处理', () {
      final dialog = AppDialog.fromJson({
        ApiFields.popupType: 3,
        ApiFields.popupData: {ApiFields.popupUrl: 'https://h5.example'},
      });
      expect(dialog.type, AppPopupType.marketing);
      expect(dialog.hasPopup, isFalse);
    });

    test('会员升级弹窗暂按无弹窗处理', () {
      expect(AppDialog.fromJson({ApiFields.popupType: 2}).hasPopup, isFalse);
    });

    test('未知类型按暂不支持处理', () {
      final dialog = AppDialog.fromJson({ApiFields.popupType: 9});
      expect(dialog.type, AppPopupType.unsupported);
      expect(dialog.hasPopup, isFalse);
    });

    test('无弹窗时类型为 0 且内容为空', () {
      final dialog = AppDialog.fromJson({
        ApiFields.popupType: 0,
        ApiFields.popupData: null,
      });
      expect(dialog.type, AppPopupType.none);
      expect(dialog.hasPopup, isFalse);
      expect(dialog.payload, isNull);
    });

    test('字段缺失时按无弹窗兜底', () {
      expect(AppDialog.fromJson(const <String, dynamic>{}).hasPopup, isFalse);
    });
  });

  group('AppRepository.getDialog', () {
    test('请求路径与场景参数名与接口文档一致', () async {
      final client = _RecordingClient();

      await AppRepository(client).getDialog(scene: 2);

      expect(client.calls, hasLength(1));
      final (path, params) = client.calls.single;
      expect(path, ApiEndpoints.dialog);
      expect(params[ApiFields.popupScene], 2);
    });
  });

  group('showAppUpgradePopup', () {
    Future<void> pumpPopup(
      WidgetTester tester, {
      required AppDialog dialog,
      Future<bool> Function(Uri uri)? opener,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAppUpgradePopup(
                    context: context,
                    dialog: dialog,
                    externalOpener: opener,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('渲染版本号胶囊、正文与 Update Now 按钮', (tester) async {
      await pumpPopup(
        tester,
        dialog: const AppDialog(
          type: AppPopupType.appUpgrade,
          version: '1.1.4',
          message: 'New version 1.1.4 is now available',
          targetUrl: 'https://example.com/app',
        ),
      );

      expect(find.text('V1.1.4'), findsOne);
      expect(find.text('New version 1.1.4 is now available'), findsOne);
      expect(find.text('Update Now'), findsOne);

      // 收尾，避免弹窗残留导致后续用例的 _showing 守卫失效。
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });

    testWidgets('点 Update Now 打开下载链接并关闭弹窗', (tester) async {
      final opened = <Uri>[];
      await pumpPopup(
        tester,
        dialog: const AppDialog(
          type: AppPopupType.appUpgrade,
          version: '1.1.4',
          message: 'New version is now available',
          targetUrl: 'https://example.com/app',
        ),
        opener: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      await tester.tap(find.byKey(const Key('app-upgrade-update')));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://example.com/app')]);
      expect(find.text('Update Now'), findsNothing);
    });
  });
  group('showAppMarketingPopup', () {
    Future<void> pumpPopup(
      WidgetTester tester, {
      required AppDialog dialog,
      Future<bool> Function(Uri uri)? opener,
    }) async {
      tester.view.physicalSize = const Size(750, 1624);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAppMarketingPopup(
                    context: context,
                    dialog: dialog,
                    externalOpener: opener,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    const dialog = AppDialog(
      type: AppPopupType.marketing,
      imageUrl: 'https://cdn.example/marketing.png',
      targetUrl: 'https://h5.example/recommend',
    );

    testWidgets('卡片宽度为屏幕宽度减 32，并带关闭按钮', (tester) async {
      await pumpPopup(tester, dialog: dialog);

      // 750/2 = 375 逻辑宽，卡片 = 375 - 32 = 343。
      expect(
        tester.getSize(find.byKey(const Key('app-marketing-image'))).width,
        343,
      );
      expect(find.byKey(const Key('app-marketing-close')), findsOne);

      await tester.tap(find.byKey(const Key('app-marketing-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-marketing-close')), findsNothing);
    });

    testWidgets('点卡片进落地页并关闭弹窗', (tester) async {
      final opened = <Uri>[];
      await pumpPopup(
        tester,
        dialog: dialog,
        opener: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      // 测试环境里网络图加载失败、卡片高度为 0，命中不到；直接触发点击回调。
      final image = tester.widget<GestureDetector>(
        find.byKey(const Key('app-marketing-image')),
      );
      image.onTap!.call();
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://h5.example/recommend')]);
      expect(find.byKey(const Key('app-marketing-image')), findsNothing);
    });
  });
}
