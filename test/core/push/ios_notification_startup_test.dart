import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts iOS notification routing before runApp', () {
    final content = File('lib/main.dart').readAsStringSync();
    final coordinatorStart = content.indexOf(
      'IosNotificationRouteCoordinator.instance.start()',
    );
    final runApp = content.indexOf('runApp(', coordinatorStart);

    expect(coordinatorStart, isNonNegative);
    expect(runApp, greaterThan(coordinatorStart));
  });

  test('requests notification permission and registers for APNs', () {
    final content = File('lib/main.dart').readAsStringSync();

    expect(content, contains('Permission.notification.request()'));
    expect(
      content,
      contains('PushBridge.shared.registerForRemoteNotifications()'),
    );
  });

  test('native app delegate forwards notification payloads', () {
    final content = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(content, contains('import UserNotifications'));
    expect(content, contains('UNUserNotificationCenter.current().delegate'));
    expect(content, contains('willPresent notification'));
    expect(content, contains('didReceive response'));
    expect(content, contains('acceptNotificationPayload'));
    expect(content, contains('PushNotificationRegistrar.shared.updatePushToken'));
    expect(
      content,
      isNot(contains('application.registerForRemoteNotifications()')),
    );
  });

  test('native push bridge queues routes and supports nested params payloads', () {
    final content = File(
      'ios/Runner/PushNotificationRegistrar.swift',
    ).readAsStringSync();

    expect(content, contains('pendingNotificationRoutes'));
    expect(content, contains('"push_route"'));
    expect(content, contains('userInfo["url"]'));
    expect(content, contains('userInfo["params"]'));
    expect(content, contains('JSONSerialization.jsonObject'));
  });
}
