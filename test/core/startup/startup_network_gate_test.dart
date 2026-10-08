import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laya_credit/core/startup/startup_network_gate.dart';

Widget _ready() =>
    const MaterialApp(home: Scaffold(body: Text('HOME')));

void main() {
  testWidgets('探测返回前停在启动页', (tester) async {
    final completer = Completer<bool>();
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () => completer.future,
        readyBuilder: _ready,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('startup-launch')), findsOneWidget);

    completer.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('探测通过后进入业务首屏', (tester) async {
    await tester.pumpWidget(
      StartupNetworkGate(probe: () async => true, readyBuilder: _ready),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('探测失败停在无网页，点重试成功后进入业务首屏', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () async {
          calls++;
          return calls >= 2;
        },
        readyBuilder: _ready,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup-network-illustration')), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    await tester.tap(find.byKey(const Key('startup-network-retry')));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('探测抛异常也落到无网页', (tester) async {
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () async => throw StateError('boom'),
        readyBuilder: _ready,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('无网页停留时回到前台自动重试', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () async {
          calls++;
          return calls >= 2;
        },
        readyBuilder: _ready,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });
}
