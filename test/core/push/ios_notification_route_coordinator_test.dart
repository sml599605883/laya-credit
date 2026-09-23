import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/push/ios_notification_route_coordinator.dart';
import 'package:laya_credit/core/push/push_bridge.dart';

void main() {
  late StreamController<PushEvent> events;
  late List<String> openedRoutes;
  late List<VoidCallback> deferredCallbacks;
  late bool navigationReady;
  late IosNotificationRouteCoordinator coordinator;

  setUp(() {
    events = StreamController<PushEvent>.broadcast();
    openedRoutes = <String>[];
    deferredCallbacks = <VoidCallback>[];
    navigationReady = true;
    coordinator = IosNotificationRouteCoordinator(
      events: () => events.stream,
      navigationReady: () => navigationReady,
      openRoute: (route) async => openedRoutes.add(route),
      defer: deferredCallbacks.add,
    );
  });

  tearDown(() async {
    await coordinator.stop();
    await events.close();
  });

  test('filters unrelated events and trims push routes', () async {
    coordinator.start();
    events
      ..add(<String, Object?>{'type': 'push_token', 'token': 'abc'})
      ..add(<String, Object?>{'type': 'push_route', 'url': '  '})
      ..add(
        <String, Object?>{
          'type': 'push_route',
          'url': '  ph://laya-credit/ios/AsepticizingCriminalist?butterpaste=4  ',
        },
      );

    await _flushMicrotasks();

    expect(openedRoutes, <String>[
      'ph://laya-credit/ios/AsepticizingCriminalist?butterpaste=4',
    ]);
  });

  test('retains routes until navigation becomes ready', () async {
    navigationReady = false;
    coordinator.start();
    events.add(<String, Object?>{'type': 'push_route', 'url': 'first'});

    await _flushMicrotasks();

    expect(openedRoutes, isEmpty);
    expect(deferredCallbacks, hasLength(1));

    navigationReady = true;
    deferredCallbacks.removeAt(0)();
    await _flushMicrotasks();

    expect(openedRoutes, <String>['first']);
  });

  test('opens queued routes serially in arrival order', () async {
    final firstRouteDone = Completer<void>();
    coordinator = IosNotificationRouteCoordinator(
      events: () => events.stream,
      navigationReady: () => true,
      openRoute: (route) async {
        openedRoutes.add(route);
        if (route == 'first') await firstRouteDone.future;
      },
      defer: deferredCallbacks.add,
    )..start();

    events
      ..add(<String, Object?>{'type': 'push_route', 'url': 'first'})
      ..add(<String, Object?>{'type': 'push_route', 'url': 'second'});
    await _flushMicrotasks();
    expect(openedRoutes, <String>['first']);

    firstRouteDone.complete();
    await _flushMicrotasks();
    expect(openedRoutes, <String>['first', 'second']);
  });

  test('continues after a route opener throws', () async {
    coordinator = IosNotificationRouteCoordinator(
      events: () => events.stream,
      navigationReady: () => true,
      openRoute: (route) async {
        if (route == 'first') throw StateError('failed');
        openedRoutes.add(route);
      },
      defer: deferredCallbacks.add,
    )..start();

    events
      ..add(<String, Object?>{'type': 'push_route', 'url': 'first'})
      ..add(<String, Object?>{'type': 'push_route', 'url': 'second'});
    await _flushMicrotasks();

    expect(openedRoutes, <String>['second']);
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
