import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// 启动网络探测：返回 true 表示后端传输层可达。
typedef StartupNetworkProbe = Future<bool> Function();

/// 探测通过后要构建的真正 App。
typedef StartupNetworkReadyBuilder = Widget Function();

/// 启动闸门（对齐 fund_nexus 的 `StartupNetworkGate`）。
///
/// 冷启动时先停在启动页，探测一次后端是否可达：
/// - 可达 → 构建 [readyBuilder]，正常进入首页；
/// - 不可达 → 停在无网重试页，用户点重试或 App 回到前台时再探一次。
///
/// 本组件挂在 [MaterialApp] 之上，所以启动页与无网页各自带一个 [MaterialApp]。
/// 好处是把「入口是否可用」和「业务首屏」解耦：网络没恢复前不会进首页触发
/// 一串注定失败的接口，用户也不会看到闪一下就报错的首页。
class StartupNetworkGate extends StatefulWidget {
  const StartupNetworkGate({
    required this.probe,
    required this.readyBuilder,
    this.retryOnResume = true,
    super.key,
  });

  final StartupNetworkProbe probe;
  final StartupNetworkReadyBuilder readyBuilder;

  /// 无网页停留期间，App 回到前台是否自动重试。
  final bool retryOnResume;

  @override
  State<StartupNetworkGate> createState() => _StartupNetworkGateState();
}

class _StartupNetworkGateState extends State<StartupNetworkGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _ready = false;
  bool _failed = false;
  bool _showLaunch = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首帧先把启动页画出来，探测放到帧末，避免探测耗时把启动页一起卡掉。
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.retryOnResume && state == AppLifecycleState.resumed && _failed) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_checking || _ready) return;
    setState(() {
      _checking = true;
      _failed = false;
    });
    try {
      final available = await widget.probe();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _showLaunch = false;
        _ready = available;
        _failed = !available;
      });
    } catch (_) {
      // 探测本身异常（而非返回 false）同样落到无网页，不能让它冒泡成崩溃。
      if (!mounted) return;
      setState(() {
        _checking = false;
        _showLaunch = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.readyBuilder();
    if (_showLaunch) return const StartupLaunchPage();
    return StartupNetworkUnavailablePage(checking: _checking, onRetry: _check);
  }
}

/// 启动页：通栏品牌启动图（Logo 与产品名已烘焙在图里）。
class StartupLaunchPage extends StatelessWidget {
  const StartupLaunchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: SizedBox.expand(
          child: Image.asset(
            AppAssets.launch,
            key: const Key('startup-launch'),
            fit: BoxFit.cover,
            // 与 fund_nexus 的启动页一致：居中裁切，屏幕比例不同时不偏移主体。
            alignment: Alignment.center,
            // 切图缺失时退化成纯品牌底色，启动页绝不能因为一张图崩掉。
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 无网 / 探测失败页：给出明确原因与重试入口。
class StartupNetworkUnavailablePage extends StatelessWidget {
  const StartupNetworkUnavailablePage({
    required this.checking,
    required this.onRetry,
    super.key,
  });

  final bool checking;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: layout.edgeInsets(left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: layout.px(96),
                    height: layout.px(96),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      key: const Key('startup-network-illustration'),
                      size: layout.px(44),
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: layout.px(AppSpacing.md)),
                  Text(
                    'Network error, please try again later',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: layout.px(16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: layout.px(AppSpacing.xs)),
                  Text(
                    'Please check your network settings and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: layout.px(14),
                    ),
                  ),
                  SizedBox(height: layout.px(AppSpacing.lg)),
                  SizedBox(
                    width: double.infinity,
                    height: layout.px(48),
                    child: FilledButton(
                      key: const Key('startup-network-retry'),
                      // 探测进行中禁用按钮，避免连点叠加多次探测。
                      onPressed: checking ? null : () => unawaited(onRetry()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.actionLime,
                        foregroundColor: AppColors.cardValue,
                        disabledBackgroundColor: AppColors.actionLime,
                        disabledForegroundColor: AppColors.cardValue,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: layout.radius(AppSpacing.radiusLg),
                        ),
                      ),
                      child: checking
                          ? SizedBox(
                              width: layout.px(20),
                              height: layout.px(20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.cardValue,
                              ),
                            )
                          : const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
