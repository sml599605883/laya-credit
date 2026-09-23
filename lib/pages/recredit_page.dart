import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recredit_provider.dart';
import '../theme/theme.dart';

/// 等待授信 loading 页（蓝湖稿 `04-02 - 等待授信`，路由 `/recredit`）。
///
/// 准入接口返回「重新授信」（深链别名 `IntervesicularSauder`）时进入：
/// 页面一边跑本地进度动画，一边由 [recreditPollingCoordinatorProvider] 轮询
/// 授信接口；授信完成后由轮询器决定后续去向（回首页刷新 / 重走准入），
/// 页面本身不做任何跳转。
class RecreditPage extends ConsumerStatefulWidget {
  const RecreditPage({super.key, required this.productId});

  /// 产品 id，来自准入跳转地址的 `productId`；为空时只展示动画不轮询。
  final String productId;

  @override
  ConsumerState<RecreditPage> createState() => _RecreditPageState();
}

class _RecreditPageState extends ConsumerState<RecreditPage> {
  /// 进度只跑到 99%：真正的 100% 要等接口返回授信成功。
  static const _progressCeiling = 99;

  static final Random _random = Random();

  Timer? _ticker;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNextTick();
    ref.read(recreditPollingCoordinatorProvider).start(widget.productId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 每个台阶之间停顿 1~3 秒，走完一小步再排下一次，节奏接近真实等待。
  void _scheduleNextTick() {
    if (_progress >= _progressCeiling) {
      return;
    }
    _ticker = Timer(Duration(seconds: 1 + _random.nextInt(3)), _stepForward);
  }

  void _stepForward() {
    if (!mounted) {
      return;
    }
    setState(() {
      _progress = min(_progressCeiling, _progress + 5 + _random.nextInt(11));
    });
    _scheduleNextTick();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Scaffold(
      // 设计稿 `page` 底色 rgba(236,250,220,1)，与进度列表页同一色。
      backgroundColor: AppColors.surfaceMint,
      body: SingleChildScrollView(
        // 设计稿内容区上边距 290pt：整块内容（209pt 高）在 812pt 画布上略高于中线。
        padding: layout.edgeInsets(top: 290, bottom: 313),
        child: Column(
          children: [
            Image.asset(
              AppAssets.recreditIllustration,
              key: const Key('recredit-illustration'),
              width: layout.px(120),
              height: layout.px(102),
              fit: BoxFit.contain,
            ),
            SizedBox(height: layout.px(18)),
            _RecreditMessage(layout: layout),
            SizedBox(height: layout.px(11)),
            _RecreditProgress(layout: layout, progress: _progress),
          ],
        ),
      ),
    );
  }
}

/// 两行提示文案：第一行的高亮片段用品牌红，其余走主文字色。
class _RecreditMessage extends StatelessWidget {
  const _RecreditMessage({required this.layout});

  final AppLayout layout;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: AppColors.recreditMessageText,
      fontFamily: 'Helvetica',
      fontSize: layout.px(14),
      fontWeight: FontWeight.w400,
      // 设计稿 `text-group_1`：font-size 14px / line-height 18px。
      height: 18 / 14,
    );
    return SizedBox(
      width: layout.px(279),
      // 设成固定宽度后按需等比缩小：Helvetica / 系统字体在不同平台的字宽略有差异，
      // 万一整句比 279pt 宽也只会轻微缩放，不会出现裁切或溢出条纹。
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: base,
                children: [
                  const TextSpan(text: 'Calculating your credit limit, just '),
                  TextSpan(
                    text: '30 seconds',
                    style: base.copyWith(color: AppColors.recreditAccentText),
                  ),
                ],
              ),
            ),
            Text(
              'Please wait patiently',
              textAlign: TextAlign.center,
              style: base,
            ),
          ],
        ),
      ),
    );
  }
}

/// 白色胶囊进度槽 + 深色填充条 + 百分比。
///
/// 槽底走设计导出的切图（287x12），填充条按当前进度覆盖在槽内：
/// 四周内缩 2pt、条高 8pt、圆角 4pt，与设计稿实测尺寸一致。
class _RecreditProgress extends StatelessWidget {
  const _RecreditProgress({required this.layout, required this.progress});

  final AppLayout layout;
  final int progress;

  static const _trackSize = Size(287, 12);
  static const _fillInset = 2.0;
  static const _fillHeight = 8.0;
  static const _fillRadius = 4.0;

  @override
  Widget build(BuildContext context) {
    final trackWidth = layout.px(_trackSize.width);
    final inset = layout.px(_fillInset);
    final trackInnerWidth = trackWidth - inset * 2;

    return Column(
      children: [
        SizedBox(
          key: const Key('recredit-progress-track'),
          width: trackWidth,
          height: layout.px(_trackSize.height),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Image.asset(
                  AppAssets.recreditProgressTrack,
                  fit: BoxFit.fill,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(layout.px(_fillRadius)),
                  child: SizedBox(
                    width: max(0, trackInnerWidth * progress / 100),
                    height: layout.px(_fillHeight),
                    child: const ColoredBox(
                      color: AppColors.recreditProgressFill,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: layout.px(10)),
        Text(
          '$progress%',
          key: const Key('recredit-progress-label'),
          style: TextStyle(
            color: AppColors.recreditProgressFill,
            fontSize: layout.px(14),
            fontWeight: FontWeight.w500,
            // 设计稿 `text_5`：font-size 14px / line-height 20px。
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}
