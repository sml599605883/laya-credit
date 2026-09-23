import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/navigation/app_deep_link.dart';
import 'package:laya_credit/core/navigation/navigation.dart';
import 'package:laya_credit/core/network/api_fields.dart';
import 'package:laya_credit/core/product/recredit_polling_coordinator.dart';
import 'package:laya_credit/data/models/recredit_result.dart';
import 'package:laya_credit/pages/recredit_page.dart';
import 'package:laya_credit/providers/recredit_provider.dart';

/// 一直不返回的授信请求：页面测试里只验证渲染，不让轮询真的跑起来。
Future<bool> _neverResolves() => Completer<bool>().future;

RecreditPollingCoordinator _idleCoordinator() {
  return RecreditPollingCoordinator(
    readStatus: _neverResolves,
    currentRoute: () => AppRoutes.recredit,
    refreshHome: () async {},
    runAdmission: (_) async {},
  );
}

/// 轮询到 [predicate] 成立为止（用于 interval 为 0 的协调器测试）。
Future<void> _settleUntil(bool Function() predicate) async {
  for (var i = 0; i < 200 && !predicate(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('RecreditResult', () {
    test('countercharged 为 1 表示授信成功', () {
      final result = RecreditResult.fromJson({ApiFields.recreditResultCode: 1});
      expect(result.isGranted, isTrue);
    });

    test('countercharged 为 2 表示暂无结果', () {
      final result = RecreditResult.fromJson({ApiFields.recreditResultCode: 2});
      expect(result.isGranted, isFalse);
    });

    test('未知取值按未出结果处理，不会误判成功', () {
      final result = RecreditResult.fromJson({
        ApiFields.recreditResultCode: '9',
      });
      expect(result.isGranted, isFalse);
    });
  });

  group('RecreditPollingCoordinator', () {
    test('授信成功且仍停在等待页时重走准入', () async {
      final calls = <String>[];
      var attempts = 0;
      final coordinator = RecreditPollingCoordinator(
        readStatus: () async => ++attempts >= 2,
        currentRoute: () => AppRoutes.recredit,
        refreshHome: () async => calls.add('home'),
        runAdmission: (productId) async => calls.add('admission:$productId'),
        interval: Duration.zero,
      );

      coordinator.start('P-1');
      await _settleUntil(() => calls.isNotEmpty);

      expect(calls, ['admission:P-1']);
      expect(coordinator.isRunning, isFalse);
      expect(attempts, 2);
    });

    test('授信完成时用户已回到容器页则刷新首页', () async {
      final calls = <String>[];
      final coordinator = RecreditPollingCoordinator(
        readStatus: () async => true,
        currentRoute: () => AppRoutes.root,
        refreshHome: () async => calls.add('home'),
        runAdmission: (productId) async => calls.add('admission:$productId'),
        interval: Duration.zero,
      );

      coordinator.start('P-1');
      await _settleUntil(() => calls.isNotEmpty);

      expect(calls, ['home']);
    });

    test('授信完成时用户停在其它页面则不打扰', () async {
      final calls = <String>[];
      final coordinator = RecreditPollingCoordinator(
        readStatus: () async => true,
        currentRoute: () => AppRoutes.mine,
        refreshHome: () async => calls.add('home'),
        runAdmission: (productId) async => calls.add('admission:$productId'),
        interval: Duration.zero,
      );

      coordinator.start('P-1');
      await _settleUntil(() => !coordinator.isRunning);

      expect(calls, isEmpty);
      expect(coordinator.isRunning, isFalse);
    });

    test('请求异常只记日志，下一轮仍会继续轮询', () async {
      final calls = <String>[];
      var attempts = 0;
      final coordinator = RecreditPollingCoordinator(
        readStatus: () async {
          attempts++;
          if (attempts == 1) {
            throw const FormatException('boom');
          }
          return true;
        },
        currentRoute: () => AppRoutes.recredit,
        refreshHome: () async => calls.add('home'),
        runAdmission: (productId) async => calls.add('admission:$productId'),
        interval: Duration.zero,
      );

      coordinator.start('P-2');
      await _settleUntil(() => calls.isNotEmpty);

      expect(attempts, 2);
      expect(calls, ['admission:P-2']);
    });

    test('stop 之后晚到的授信结果不会再触发后续动作', () async {
      final calls = <String>[];
      final gate = Completer<bool>();
      final coordinator = RecreditPollingCoordinator(
        readStatus: () => gate.future,
        currentRoute: () => AppRoutes.recredit,
        refreshHome: () async => calls.add('home'),
        runAdmission: (productId) async => calls.add('admission:$productId'),
        interval: Duration.zero,
      );

      coordinator.start('P-3');
      coordinator.stop();
      gate.complete(true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, isEmpty);
    });

    test('产品 id 为空时不启动轮询', () async {
      var attempts = 0;
      final coordinator = RecreditPollingCoordinator(
        readStatus: () async {
          attempts++;
          return true;
        },
        currentRoute: () => AppRoutes.recredit,
        refreshHome: () async {},
        runAdmission: (_) async {},
        interval: Duration.zero,
      );

      coordinator.start('  ');
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isRunning, isFalse);
      expect(attempts, 0);
    });
  });

  group('等待授信页', () {
    Future<void> pumpPage(WidgetTester tester, String productId) async {
      final container = ProviderContainer(
        overrides: [
          recreditPollingCoordinatorProvider.overrideWithValue(
            _idleCoordinator(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RecreditPage(productId: productId)),
        ),
      );
      await tester.pump();
    }

    testWidgets('按设计稿渲染插画、两行文案与进度槽', (tester) async {
      await pumpPage(tester, 'P-1');

      expect(find.byKey(const Key('recredit-illustration')), findsOneWidget);
      expect(
        find.text(
          'Calculating your credit limit, just 30 seconds',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Please wait patiently'), findsOneWidget);
      expect(find.byKey(const Key('recredit-progress-track')), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('进度动画会向上推进且不超过 99%', (tester) async {
      await pumpPage(tester, 'P-1');

      // 单步停顿最长 3 秒，推 3 秒必定走出第一步。
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('0%'), findsNothing);

      // 连续推进足够久后封顶在 99%，不会显示 100%。
      await tester.pump(const Duration(seconds: 60));
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('授信深链路由到等待页并带产品 id', (tester) async {
      final container = ProviderContainer(
        overrides: [
          recreditPollingCoordinatorProvider.overrideWithValue(
            _idleCoordinator(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: AppNavigator.navigatorKey,
            onGenerateRoute: AppRouteGenerator.onGenerateRoute,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );

      unawaited(
        AppNavigator.openDeepLink(
          const AppDeepLinkParser().parse(
            'ph://laya-credit/ios/IntervesicularSauder?productId=P-9',
          ),
          onUnhandled: (link) async {},
        ),
      );
      await tester.pump();
      await tester.pump();

      final page = tester.widget<RecreditPage>(find.byType(RecreditPage));
      expect(page.productId, 'P-9');
    });
  });

  test('等待授信深链支持混淆产品 id 参数名 tartarizing', () {
    final link = const AppDeepLinkParser().parse(
      'ph://laya-credit/ios/IntervesicularSauder?tartarizing=P-7',
    );

    expect(link.kind, AppDeepLinkKind.recredit);
    expect(link.productId, 'P-7');
  });

  test('等待授信深链同时兼容 productId 参数名', () {
    final link = const AppDeepLinkParser().parse(
      'ph://laya-credit/ios/IntervesicularSauder?productId=P-8',
    );

    expect(link.kind, AppDeepLinkKind.recredit);
    expect(link.productId, 'P-8');
  });

  testWidgets('已在等待页时重复下发同目标不再压栈', (tester) async {
    // 观察者是全局单例，先把栈顶置成非等待授信页，避免受其他用例影响。
    appRouteObserver.didPush(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.root),
        builder: (_) => const SizedBox.shrink(),
      ),
      null,
    );

    final container = ProviderContainer(
      overrides: [
        recreditPollingCoordinatorProvider.overrideWithValue(
          _idleCoordinator(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: AppNavigator.navigatorKey,
          navigatorObservers: [appRouteObserver],
          onGenerateRoute: AppRouteGenerator.onGenerateRoute,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    for (final productId in ['P-1', 'P-2']) {
      unawaited(
        AppNavigator.openDeepLink(
          const AppDeepLinkParser().parse(
            'ph://laya-credit/ios/IntervesicularSauder?tartarizing=$productId',
          ),
          onUnhandled: (link) async {},
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    expect(find.byType(RecreditPage), findsOneWidget);
    expect(
      tester.widget<RecreditPage>(find.byType(RecreditPage)).productId,
      'P-1',
    );
  });

  test('等待授信路由已注册', () {
    expect(AppRoutes.isValid(AppRoutes.recredit), isTrue);
  });

  test('路由观察者记录栈顶路由名', () {
    final observer = AppRouteObserver();
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.recredit),
      builder: (_) => const SizedBox.shrink(),
    );

    observer.didPush(route, null);

    expect(observer.currentRouteName, AppRoutes.recredit);
  });
}
