import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/certification/certification_retention_guard.dart';
import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/network/api_endpoints.dart';
import 'package:laya_credit/core/network/api_fields.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/data/models/certification_retention.dart';
import 'package:laya_credit/data/repositories/certification_repository.dart';
import 'package:laya_credit/providers/certification_retention_provider.dart';

HttpClient _placeholderClient() {
  return HttpClient(
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

/// 只记录请求、不发网络，用来校验仓库层传出的字段名。
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
  Future<ApiResponse<T>> post<T>(
    String path, {
    required Map<String, Object?> params,
    required T Function(Object? data) parse,
  }) async {
    calls.add((path, params));
    return ApiResponse<T>(code: 0, message: 'success', data: parse(null));
  }
}

/// 认证项仓库桩：只实现挽留弹窗接口，可返回素材或直接抛错。
class _StubRetentionRepository extends CertificationRepository {
  _StubRetentionRepository({this.retention, this.failure})
    : super(_placeholderClient());

  final CertificationRetention? retention;
  final Object? failure;

  final List<(String, String)> calls = [];

  @override
  Future<ApiResponse<CertificationRetention>> getRetentionPopup({
    required String productId,
    required String type,
  }) async {
    calls.add((productId, type));
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: retention ?? const CertificationRetention(),
    );
  }
}

/// 极简宿主：一个可用的 Navigator + 注入了空 Loading 的挽留拦截器。
///
/// 拦截器里的全局 Loading 遮罩换成空实现：它是 BotToast 的全局单例，
/// 用例之间会互相影响（对齐 `homeLoadingIndicatorProvider` 的测试口径）。
///
/// 返回容器与页面 `context`，用例用它触发返回拦截。
Future<(ProviderContainer, BuildContext)> _pumpHost(
  WidgetTester tester,
  _StubRetentionRepository repository,
) async {
  final container = ProviderContainer(
    overrides: [
      certificationRetentionGuardProvider.overrideWith(
        (ref) async => CertificationRetentionGuard(
          repository: repository,
          showLoading: () {},
          hideLoading: () {},
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SizedBox())),
    ),
  );
  return (container, tester.element(find.byType(Scaffold)));
}

void main() {
  group('CertificationRetention', () {
    test('按接口文档的混淆字段解析整卡图片与两个按钮文案', () {
      final retention = CertificationRetention.fromJson({
        ApiFields.retentionData: {
          'upbear': 'Please wait, it only takes ',
          'norseled': ' for you to complete all certifications!',
          'grassroots': 2000,
          'limbos': 'Continuar',
          'leonor': 'Exit',
          ApiFields.retentionImage: 'https://cdn.example/retention.png',
        },
      });

      expect(retention.imageUrl, 'https://cdn.example/retention.png');
      expect(retention.resolvedContinueText, 'Continuar');
      expect(retention.resolvedExitText, 'Exit');
      expect(retention.hasImage, isTrue);
    });

    test('没有下发素材时按「没有挽留」处理', () {
      expect(const CertificationRetention().hasImage, isFalse);
      expect(
        CertificationRetention.fromJson(const <String, dynamic>{}).hasImage,
        isFalse,
      );
    });

    test('文案缺失时用设计稿兜底', () {
      const retention = CertificationRetention(
        imageUrl: 'https://cdn.example/retention.png',
      );
      expect(retention.resolvedContinueText, 'Continue');
      expect(retention.resolvedExitText, 'Exit');
    });
  });

  group('CertificationRepository.getRetentionPopup', () {
    test('请求路径与参数名与接口文档一致', () async {
      final client = _RecordingClient();

      await CertificationRepository(client).getRetentionPopup(
        productId: '7',
        type: CertificationRetentionType.loanConfirm,
      );

      expect(client.calls, hasLength(1));
      final (path, params) = client.calls.single;
      expect(path, ApiEndpoints.retentionPopup);
      expect(params[ApiFields.retentionType], '5');
      expect(params[ApiFields.retentionProductId], '7');
      // 混淆字段每次请求随机，只要存在即可。
      expect(params[ApiFields.obfuscateRetention], isNotEmpty);
    });
  });

  group('CertificationRetentionGuard.handleBack', () {
    testWidgets('没有素材时直接放行返回，不弹窗', (tester) async {
      final repository = _StubRetentionRepository();
      final (container, context) = await _pumpHost(tester, repository);
      final guard = await container.read(
        certificationRetentionGuardProvider.future,
      );

      var exited = 0;
      await guard.handleBack(
        context: context,
        productId: '7',
        type: CertificationRetentionType.personal,
        onExit: () => exited++,
      );

      expect(repository.calls, [('7', '2')]);
      expect(exited, 1);
    });

    testWidgets('接口异常时直接放行返回，不弹窗', (tester) async {
      final repository = _StubRetentionRepository(
        failure: Exception('network down'),
      );
      final (container, context) = await _pumpHost(tester, repository);
      final guard = await container.read(
        certificationRetentionGuardProvider.future,
      );

      var exited = 0;
      await guard.handleBack(
        context: context,
        productId: '7',
        type: CertificationRetentionType.identity,
        onExit: () => exited++,
      );

      expect(repository.calls, [('7', '0')]);
      expect(exited, 1);
    });

    testWidgets('产品 id 为空时不发请求，直接放行返回', (tester) async {
      final repository = _StubRetentionRepository(
        retention: const CertificationRetention(
          imageUrl: 'https://cdn.example/retention.png',
        ),
      );
      final (container, context) = await _pumpHost(tester, repository);
      final guard = await container.read(
        certificationRetentionGuardProvider.future,
      );

      var exited = 0;
      await guard.handleBack(
        context: context,
        productId: '  ',
        type: CertificationRetentionType.work,
        onExit: () => exited++,
      );

      expect(repository.calls, isEmpty);
      expect(exited, 1);
    });

    testWidgets('弹窗里点 Continue 留在当前页，不触发返回', (tester) async {
      final repository = _StubRetentionRepository(
        retention: const CertificationRetention(
          imageUrl: 'https://cdn.example/retention.png',
          continueText: 'Continue',
          exitText: 'Exit',
        ),
      );
      final (container, context) = await _pumpHost(tester, repository);
      final guard = await container.read(
        certificationRetentionGuardProvider.future,
      );

      var exited = 0;
      unawaited(
        guard.handleBack(
          context: context,
          productId: '7',
          type: CertificationRetentionType.face,
          onExit: () => exited++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('certification-retention-card')), findsOne);
      expect(find.text('Continue'), findsOne);
      expect(find.text('Exit'), findsOne);

      await tester.tap(find.byKey(const Key('certification-retention-stay')));
      await tester.pumpAndSettle();

      expect(exited, 0);
      expect(
        find.byKey(const Key('certification-retention-card')),
        findsNothing,
      );
    });

    testWidgets('弹窗里点 Exit 才触发返回', (tester) async {
      final repository = _StubRetentionRepository(
        retention: const CertificationRetention(
          imageUrl: 'https://cdn.example/retention.png',
        ),
      );
      final (container, context) = await _pumpHost(tester, repository);
      final guard = await container.read(
        certificationRetentionGuardProvider.future,
      );

      var exited = 0;
      unawaited(
        guard.handleBack(
          context: context,
          productId: '7',
          type: CertificationRetentionType.emergencyContact,
          onExit: () => exited++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('certification-retention-exit')));
      await tester.pumpAndSettle();

      expect(exited, 1);
      expect(
        find.byKey(const Key('certification-retention-card')),
        findsNothing,
      );
    });
  });
}
