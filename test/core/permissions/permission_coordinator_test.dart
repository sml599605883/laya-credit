import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/permissions/permission_coordinator.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test(
    'startup requests notification, APNs and tracking exactly once',
    () async {
      final events = <String>[];
      final coordinator = PermissionCoordinator(
        requestNotificationPermission: () async {
          events.add('notification');
          return 'denied';
        },
        requestTrackingPermission: () async {
          events.add('tracking');
          return 'authorized';
        },
        registerForRemoteNotifications: () async {
          events.add('register');
        },
        delay: (_) async {
          events.add('delay');
        },
      );

      final first = coordinator.requestStartupPermissions();
      final second = coordinator.requestStartupPermissions();
      await Future.wait([first, second]);
      await coordinator.requestStartupPermissions();

      expect(events, [
        'delay',
        'notification',
        'register',
        'delay',
        'tracking',
      ]);
    },
  );

  test(
    'startup permission failures do not escape nor block tracking',
    () async {
      var trackingRequests = 0;
      final coordinator = PermissionCoordinator(
        requestNotificationPermission: () async => throw StateError('failed'),
        requestTrackingPermission: () async {
          trackingRequests++;
          return 'authorized';
        },
        requestDelay: Duration.zero,
      );

      await expectLater(coordinator.requestStartupPermissions(), completes);

      expect(trackingRequests, 0);
    },
  );

  test('every resume waits before requesting tracking permission', () async {
    final events = <String>[];
    final coordinator = PermissionCoordinator(
      requestNotificationPermission: () async => 'authorized',
      requestTrackingPermission: () async {
        events.add('tracking');
        return 'authorized';
      },
      delay: (_) async {
        events.add('delay');
      },
    );

    await coordinator.requestResumeTrackingPermission();
    await coordinator.requestResumeTrackingPermission();

    expect(events, ['delay', 'tracking', 'delay', 'tracking']);
  });

  test(
    'disabled location service requires the service settings prompt',
    () async {
      final coordinator = _locationCoordinator(
        serviceStatus: ServiceStatus.disabled,
        permissionStatus: PermissionStatus.granted,
      );

      expect(
        await coordinator.requestCertificationLocation(),
        CertificationLocationDecision.serviceDisabled,
      );
    },
  );

  test('granted location proceeds without requesting again', () async {
    var requests = 0;
    final coordinator = _locationCoordinator(
      serviceStatus: ServiceStatus.enabled,
      permissionStatus: PermissionStatus.granted,
      onRequest: () => requests++,
    );

    expect(
      await coordinator.requestCertificationLocation(),
      CertificationLocationDecision.granted,
    );
    expect(requests, 0);
  });

  test('a fresh denial falls through to the settings prompt', () async {
    final coordinator = _locationCoordinator(
      serviceStatus: ServiceStatus.enabled,
      permissionStatus: PermissionStatus.denied,
      requestedStatus: PermissionStatus.denied,
    );

    expect(
      await coordinator.requestCertificationLocation(),
      CertificationLocationDecision.settingsRequired,
    );
  });

  test('permanently denied location requires app settings', () async {
    final coordinator = _locationCoordinator(
      serviceStatus: ServiceStatus.enabled,
      permissionStatus: PermissionStatus.permanentlyDenied,
    );

    expect(
      await coordinator.requestCertificationLocation(),
      CertificationLocationDecision.settingsRequired,
    );
  });

  test('restricted location requires app settings', () async {
    final coordinator = _locationCoordinator(
      serviceStatus: ServiceStatus.enabled,
      permissionStatus: PermissionStatus.restricted,
    );

    expect(
      await coordinator.requestCertificationLocation(),
      CertificationLocationDecision.settingsRequired,
    );
  });

  test('concurrent certification entries share one location check', () async {
    var serviceChecks = 0;
    var statusChecks = 0;
    final releaseStatus = Completer<void>();
    final coordinator = PermissionCoordinator(
      requestNotificationPermission: () async => 'authorized',
      requestTrackingPermission: () async => 'authorized',
      requestDelay: Duration.zero,
      locationServiceStatusProvider: () async {
        serviceChecks++;
        return ServiceStatus.enabled;
      },
      locationPermissionStatusProvider: () async {
        statusChecks++;
        await releaseStatus.future;
        return PermissionStatus.granted;
      },
    );

    final first = coordinator.requestCertificationLocation();
    final second = coordinator.requestCertificationLocation();
    releaseStatus.complete();

    expect(await Future.wait([first, second]), [
      CertificationLocationDecision.granted,
      CertificationLocationDecision.granted,
    ]);
    expect(serviceChecks, 1);
    expect(statusChecks, 1);
  });

  testWidgets('paused location request releases the flow for a retry', (
    tester,
  ) async {
    final firstRequestStarted = Completer<void>();
    final firstNativeResult = Completer<void>();
    var requests = 0;
    final coordinator = PermissionCoordinator(
      requestNotificationPermission: () async => 'authorized',
      requestTrackingPermission: () async => 'authorized',
      requestDelay: Duration.zero,
      locationServiceStatusProvider: () async => ServiceStatus.enabled,
      locationPermissionStatusProvider: () async => PermissionStatus.denied,
      requestedLocationStatusProvider: () async => PermissionStatus.granted,
      requestLocationPermission: () {
        requests++;
        if (requests == 1) {
          firstRequestStarted.complete();
          return firstNativeResult.future;
        }
        return Future<void>.value();
      },
    );

    final first = coordinator.requestCertificationLocation();
    await firstRequestStarted.future;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    expect(await first, CertificationLocationDecision.denied);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(
      await coordinator.requestCertificationLocation(),
      CertificationLocationDecision.granted,
    );
    firstNativeResult.complete();
  });
}

PermissionCoordinator _locationCoordinator({
  required ServiceStatus serviceStatus,
  required PermissionStatus permissionStatus,
  PermissionStatus? requestedStatus,
  void Function()? onRequest,
}) {
  return PermissionCoordinator(
    requestNotificationPermission: () async => 'authorized',
    requestTrackingPermission: () async => 'authorized',
    requestDelay: Duration.zero,
    locationServiceStatusProvider: () async => serviceStatus,
    locationPermissionStatusProvider: () async => permissionStatus,
    requestedLocationStatusProvider: () async =>
        requestedStatus ?? permissionStatus,
    requestLocationPermission: () async => onRequest?.call(),
  );
}
