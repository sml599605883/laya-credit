import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/navigation.dart';
import 'providers/session_provider.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 先把登录态从本地读出来再首帧，避免启动瞬间闪一下未登录界面。
  final container = ProviderContainer();
  await container.read(userSessionProvider.notifier).restore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LayaCreditApp(),
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
