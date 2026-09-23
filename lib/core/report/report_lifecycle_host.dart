import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/report_provider.dart';
import 'report_service.dart';

/// 上报服务的启动与生命周期宿主。
///
/// 挂在 App 根部：等 [reportServiceProvider]（依赖 HTTP 客户端就绪）后调用一次
/// [ReportService.start]，并在 App 回到前台时通知上报服务。放在根部是为了让
/// 「启动即上报」和「登录 / 认证页埋点」用的是同一个单例。
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
    if (state == AppLifecycleState.resumed) {
      unawaited(ReportService.current?.resumed() ?? Future<void>.value());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reportServiceProvider).whenData((service) {
      if (_started) return;
      _started = true;
      // 上报启动不必阻塞首帧，等本帧结束后再跑。
      scheduleMicrotask(() => unawaited(service.start()));
    });
    return widget.child;
  }
}
