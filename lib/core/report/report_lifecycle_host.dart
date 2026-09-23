import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/report_provider.dart';
import '../permissions/permission_coordinator.dart';
import 'report_service.dart';

/// 上报与权限的启动 / 生命周期宿主。
///
/// 挂在 App 根部（对齐 Dali 的 `DaliCashStartup` + `PermissionLifecycleObserver`）：
/// 等 [reportServiceProvider]（依赖 HTTP 客户端就绪）后按顺序执行
/// ① 启动上报 → ② 通知 / ATT 权限流程 → ③ 权限就绪后再补一轮归因上报；
/// App 回到前台时重试 ATT 并通知上报服务。放在根部是为了让「启动即上报」
/// 和「登录 / 认证页埋点」用的是同一个单例。
class ReportLifecycleHost extends ConsumerStatefulWidget {
  const ReportLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReportLifecycleHost> createState() =>
      _ReportLifecycleHostState();
}

class _ReportLifecycleHostState extends ConsumerState<ReportLifecycleHost>
    with WidgetsBindingObserver {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(PermissionCoordinator.instance.requestResumeTrackingPermission());
    unawaited(ReportService.current?.resumed() ?? Future<void>.value());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reportServiceProvider).whenData((service) {
      if (_started) return;
      _started = true;
      // 上报启动不必阻塞首帧，等本帧结束后再跑。
      scheduleMicrotask(() => unawaited(_runStartup(service)));
    });
    return widget.child;
  }

  /// 启动序列与 Dali 的 `PermissionLifecycleObserver` 一致：任何一步失败都继续
  /// 下一步，权限失败绝不能把启动上报卡死。
  Future<void> _runStartup(ReportService service) async {
    try {
      await service.start();
    } catch (_) {}
    try {
      await PermissionCoordinator.instance.requestStartupPermissions();
    } catch (_) {}
    try {
      await service.startupPermissionsResolved();
    } catch (_) {}
  }
}
