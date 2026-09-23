import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/navigation/navigation.dart';
import 'core/push/ios_notification_route_coordinator.dart';
import 'core/push/push_bridge.dart';
import 'core/report/report_lifecycle_host.dart';
import 'providers/session_provider.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 推送路由必须在首帧前挂上：冷启动点通知时导航栈还没就绪，
  // 协调器会缓存事件、等导航可用后再串行分发，避免丢掉首条路由。
  IosNotificationRouteCoordinator.instance.start();

  // 先把登录态从本地读出来再首帧，避免启动瞬间闪一下未登录界面。
  final container = ProviderContainer();
  await container.read(userSessionProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ReportLifecycleHost(child: LayaCreditApp()),
    ),
  );

  unawaited(_registerForPushNotifications());
}

/// 请求通知权限并向 APNs 注册，换取 deviceToken。
///
/// 推送不是关键路径：权限被拒或注册失败都只记日志，不能影响启动。
Future<void> _registerForPushNotifications() async {
  if (!Platform.isIOS) return;
  try {
    await Permission.notification.request();
  } catch (error) {
    debugPrint('[Push] 通知权限请求失败: $error');
  }
  await PushBridge.shared.registerForRemoteNotifications();
}

class LayaCreditApp extends StatelessWidget {
  const LayaCreditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laya Credit',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      // 全局导航键：让无 context 的场景（支付回调、推送、会话过期）也能跳转。
      navigatorKey: AppNavigator.navigatorKey,
      navigatorObservers: [appRouteObserver, BotToastNavigatorObserver()],
      initialRoute: AppRoutes.root,
      // 路由表：页面与路由名的映射只在 AppRouteGenerator 里维护。
      onGenerateRoute: AppRouteGenerator.onGenerateRoute,
      builder: BotToastInit(),
    );
  }
}
