import 'package:flutter/material.dart';

/// 全局路由观察者，挂在 `MaterialApp.navigatorObservers` 上。
///
/// 页面曝光埋点统一加在这里的 [_logRouteChange]，业务页面不需要各写一遍。
final appRouteObserver = AppRouteObserver();

class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _track('pop', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _track('replace', newRoute, oldRoute);
  }

  void _track(String action, Route<dynamic>? route, Route<dynamic>? previous) {
    final name = route?.settings.name ?? 'unknown';
    final from = previous?.settings.name ?? 'none';
    debugPrint('[Route] $action $from -> $name');

    // TODO(埋点): 接入 Firebase Analytics 后在此上报屏幕浏览事件。
  }
}
