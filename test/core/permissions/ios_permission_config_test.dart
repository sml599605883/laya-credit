import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Info.plist declares every iOS permission purpose', () {
    final content = File('ios/Runner/Info.plist').readAsStringSync();

    expect(content, contains('NSCameraUsageDescription'));
    expect(content, contains('NSLocationWhenInUseUsageDescription'));
    expect(content, contains('NSUserTrackingUsageDescription'));
  });

  test('Podfile compiles the permission handler features the app requests', () {
    final content = File('ios/Podfile').readAsStringSync();

    expect(content, contains('PERMISSION_CAMERA=1'));
    expect(content, contains('PERMISSION_LOCATION_WHENINUSE=1'));
    expect(content, contains('PERMISSION_NOTIFICATIONS=1'));
  });

  test('iOS registers for APNs only through the push channel', () {
    final registrar = File('ios/Runner/PushNotificationRegistrar.swift')
        .readAsStringSync();

    expect(registrar, contains('case "registerForRemoteNotifications":'));
    expect(
      registrar,
      contains('UIApplication.shared.registerForRemoteNotifications()'),
    );
  });

  test('iOS report location never prompts on its own', () {
    final registrar = File('ios/Runner/ReportRegistrar.swift')
        .readAsStringSync();

    expect(registrar, contains('case "requestLocationPermission":'));
    expect(registrar, contains('case "requestTrackingAuthorization":'));
    expect(registrar, contains('manager.requestWhenInUseAuthorization()'));
  });
}
