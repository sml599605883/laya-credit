import 'dart:async';

import '../navigation/app_routes.dart';

/// 读取一次授信结果，`true` 表示授信已完成。
typedef RecreditStatusReader = Future<bool> Function();

/// 读取当前所在路由名（用于决定授信完成后的去向）。
typedef RecreditRouteReader = String? Function();

/// 授信完成时，如果用户已经回到首页，刷新首页数据。
typedef RecreditHomeRefresher = Future<void> Function();

/// 授信完成时，如果用户仍停留在等待授信页，用产品 id 重新走一次准入。
typedef RecreditAdmissionRunner = Future<void> Function(String productId);

typedef RecreditLogger = void Function(String message);

/// 等待授信页的轮询器。
///
/// 进入页面后调用 [start]，之后每 [interval] 请求一次授信接口：
/// - 授信成功：停止轮询，并按**当前路由**决定后续动作（回首页就刷新首页，
///   还在等待授信页就再走一次准入）；
/// - 暂无结果 / 请求异常：等 [interval] 后继续下一轮（异常只记日志，不弹窗、
///   不影响等待页的进度动画）；
/// - [stop] 或再次 [start]：当前轮次立即作废，晚到的响应不会再触发后续动作
///   （用递增的 `_generation` 做守卫，避免用户中途离开后页面被二次导航）。
///
/// 单次请求串行执行：上一轮没返回前不会发起下一轮。
class RecreditPollingCoordinator {
  RecreditPollingCoordinator({
    required this._readStatus,
    required this._currentRoute,
    required this._refreshHome,
    required this._runAdmission,
    RecreditLogger? logger,
    this.interval = const Duration(seconds: 10),
  }) : _logger = logger ?? _noopLogger;

  final RecreditStatusReader _readStatus;
  final RecreditRouteReader _currentRoute;
  final RecreditHomeRefresher _refreshHome;
  final RecreditAdmissionRunner _runAdmission;
  final RecreditLogger _logger;

  /// 两次轮询之间的间隔。
  final Duration interval;

  int _generation = 0;
  bool _running = false;
  String _productId = '';

  bool get isRunning => _running;

  /// 开始轮询；[productId] 为空时直接忽略（没有产品就无法在完成后续跑准入）。
  void start(String productId) {
    final normalized = productId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _productId = normalized;
    _running = true;
    final generation = ++_generation;
    unawaited(_poll(generation));
  }

  /// 停止轮询并作废当前轮次。
  void stop() {
    _generation++;
    _running = false;
  }

  Future<void> _poll(int generation) async {
    while (_isActive(generation)) {
      var granted = false;
      try {
        granted = await _readStatus();
      } catch (error) {
        _logger('recredit poll failed: $error');
      }
      if (!_isActive(generation)) {
        return;
      }
      if (granted) {
        await _finish(generation);
        return;
      }
      await Future<void>.delayed(interval);
    }
  }

  Future<void> _finish(int generation) async {
    if (!_isActive(generation)) {
      return;
    }
    late final String route;
    late final String productId;
    try {
      route = _currentRoute() ?? '';
      productId = _productId;
    } catch (error) {
      stop();
      _logger('recredit completion failed: $error');
      return;
    }
    stop();
    try {
      // 首页在底部 Tab 容器里（`/`），个人中心也是同一个容器；
      // 只要用户已经离开等待页回到容器，就把首页数据刷一遍。
      if (route == AppRoutes.root || route == AppRoutes.home) {
        await _refreshHome();
      } else if (route == AppRoutes.recredit) {
        await _runAdmission(productId);
      }
    } catch (error) {
      _logger('recredit completion failed: $error');
    }
  }

  bool _isActive(int generation) => _running && generation == _generation;

  static void _noopLogger(String message) {}
}
