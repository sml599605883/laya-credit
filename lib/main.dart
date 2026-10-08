import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/navigation.dart';
import 'core/push/ios_notification_route_coordinator.dart';
import 'core/report/device_info_sync.dart';
import 'core/report/report_bridge.dart';
import 'core/report/report_lifecycle_host.dart';
import 'core/report/report_store.dart';
import 'core/startup/startup_network_gate.dart';
import 'data/repositories/report_repository.dart';
import 'providers/network_provider.dart';
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
      child: StartupNetworkGate(
        // 启动先探一次后端是否可达：不可达就停无网重试页，不进首页。
        // 探测会顺带把 HttpClient（设备信息 / 系统代理）就绪，等于把网络层
        // 的初始化提到首屏之前完成。
        probe: () async {
          final client = await container.read(httpClientProvider.future);
          final available = await client.probeTransport();
          if (!available) return false;
          // 对齐 Dali：网络可达后、进入首页前，串行按型号标识查一次设备信息。
          // 结果写入 ReportStore（设备报文 `chlor` / `squattest`）与
          // DeviceInfoCache（公参 `beautifully`）；失败只打日志，不阻塞启动。
          await DeviceInfoSync(
            repository: ReportRepository(client),
            bridge: ReportBridge.shared,
            store: ReportStore(),
          ).sync();
          return true;
        },
        // 网络就绪后才挂上报 / 权限宿主，与 fund_nexus「闸门通过再启动业务」一致。
        readyBuilder: () => const ReportLifecycleHost(child: LayaCreditApp()),
      ),
    ),
  );
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
