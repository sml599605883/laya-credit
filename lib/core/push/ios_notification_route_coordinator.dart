import 'dart:async';

import 'package:flutter/widgets.dart';

import '../navigation/app_deep_link.dart';
import '../navigation/app_navigator.dart';
import '../ui/toast_helper.dart';
import 'push_bridge.dart';

typedef PushEventSource = Stream<PushEvent> Function();
typedef PushNavigationReady = bool Function();
typedef PushRouteOpener = Future<void> Function(String route);
typedef PushRouteDeferrer = void Function(VoidCallback callback);

/// 消费 iOS 推送事件并分发通知点击的路由。
///
/// 通知可能在冷启动阶段就到达（此时 Flutter 导航栈还没就绪），
/// 所以这里先缓存事件、逐帧等待导航可用后再串行分发，避免启动瞬间丢路由。
class IosNotificationRouteCoordinator {
  IosNotificationRouteCoordinator({
    PushEventSource? events,
    PushNavigationReady? navigationReady,
    PushRouteOpener? openRoute,
    PushRouteDeferrer? defer,
  }) : _events = events ?? PushBridge.shared.events,
       _navigationReady = navigationReady ?? _isNavigationReady,
       _openRoute = openRoute ?? openPushTarget,
       _defer = defer ?? _deferUntilNextFrame;

  static final instance = IosNotificationRouteCoordinator();

  final PushEventSource _events;
  final PushNavigationReady _navigationReady;
  final PushRouteOpener _openRoute;
  final PushRouteDeferrer _defer;

  StreamSubscription<PushEvent>? _subscription;
  Future<void> _deliveryChain = Future<void>.value();
  int _lifecycle = 0;

  void start() {
    if (_subscription != null) return;
    final lifecycle = ++_lifecycle;
    _subscription = _events().listen((event) => _accept(event, lifecycle));
  }

  Future<void> stop() async {
    _lifecycle++;
    await _subscription?.cancel();
    _subscription = null;
    _deliveryChain = Future<void>.value();
  }

  void _accept(PushEvent event, int lifecycle) {
    if (event['type'] != 'push_route') return;
    final route = event['url']?.toString().trim() ?? '';
    if (route.isEmpty) return;
    _deliveryChain = _deliveryChain.then((_) => _deliver(route, lifecycle));
  }

  Future<void> _deliver(String route, int lifecycle) async {
    try {
      while (lifecycle == _lifecycle && !_navigationReady()) {
        await _nextFrame();
      }
      if (lifecycle == _lifecycle) await _openRoute(route);
    } catch (_) {
      // 单条推送路由失败不能中断后续分发。
    }
  }

  static bool _isNavigationReady() =>
      AppNavigator.navigatorKey.currentState != null;

  Future<void> _nextFrame() {
    final frame = Completer<void>();
    _defer(frame.complete);
    return frame.future;
  }

  static void _deferUntilNextFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }
}

/// 默认的路由分发：把通知里的原始地址解析成深链目标再统一跳转。
///
/// 语义与首页 banner、准入结果一致；解析不出的目标（如设置页、未知别名）
/// 先给用户一个提示，页面补齐后在 [AppNavigator.openDeepLink] 的
/// `onUnhandled` 里接对应动作。
Future<void> openPushTarget(String route) async {
  final value = route.trim();
  if (value.isEmpty) return;
  await AppNavigator.openDeepLink(
    const AppDeepLinkParser().parse(value),
    onUnhandled: (link) {
      ToastHelper.showMessage('Notification target: ${link.raw}');
    },
  );
}
