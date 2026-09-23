import 'package:flutter/material.dart';

import '../../data/models/certification_retention.dart';
import '../../theme/theme.dart';
import '../../widgets/remote_image.dart';

/// 认证流程「返回挽留」弹窗（蓝湖稿 `03-01 - 身份认证-挽留弹窗` /
/// `03-01 - 身份认证-活体挽留弹框` / `03-02 - 个人信息-挽留弹框` /
/// `03-03 - 工作信息-挽留弹框` / `03-04 - 联系人信息-挽留弹框` /
/// `04-01 - 确认借款-挽留弹窗`，6 张稿版式完全一致，只有整卡图片与文案不同）。
///
/// 版式与个人中心的退出 / 注销挽留弹窗一致：**整卡图片由接口下发**
/// （信封插画 / 标题 / 正文 / 胶囊按钮底色都烘焙在图里），
/// 代码只叠两个按钮：
/// - 主按钮 [CertificationRetention.resolvedContinueText] 叠在整卡的胶囊上，
///   点了关掉弹窗、留在当前认证页；
/// - 次要行动 [CertificationRetention.resolvedExitText] 在整卡下方的遮罩上，
///   点了关掉弹窗并执行 [onExit]（真正的返回）。
Future<void> showCertificationRetentionDialog({
  required BuildContext context,
  required CertificationRetention retention,
  required VoidCallback onExit,
}) {
  return showGeneralDialog<void>(
    context: context,
    // 只允许通过两个按钮关闭：点遮罩关掉容易被用户当成「已经返回了」，
    // 反而绕过了挽留（对齐 dali_cash 的 `barrierDismissible: false`）。
    barrierDismissible: false,
    barrierLabel: 'Certification retention dialog',
    barrierColor: AppColors.dialogBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _CertificationRetentionDialog(retention: retention, onExit: onExit),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _CertificationRetentionDialog extends StatelessWidget {
  const _CertificationRetentionDialog({
    required this.retention,
    required this.onExit,
  });

  /// 整卡图片的盒子（设计稿 375pt 基准：卡片 285x315）。
  static const _cardWidth = 285.0;
  static const _cardHeight = 315.0;

  /// 主按钮热区：对着整卡里那枚胶囊（实测 285x315 空间里
  /// x 59..225、y 250..291）。胶囊底是图片自带的，这里只叠文案。
  static const _stayButtonTop = 250.0;
  static const _stayButtonWidth = 166.0;
  static const _stayButtonHeight = 41.0;
  static const _stayFontSize = 18.0;
  static const _stayLineHeight = 22.0;

  /// 整卡与次要行动之间的间距（设计稿 `text_4` 的 `margin-top: 18px`）。
  static const _exitGap = 18.0;
  static const _exitFontSize = 16.0;
  static const _exitLineHeight = 19.0;

  /// 次要行动文字的上下留白：加在 19pt 高的文字外撑出可点的热区，
  /// 视觉位置靠 `_exitGap` 减掉这部分补回来。
  static const _exitTapPadding = 8.0;

  final CertificationRetention retention;
  final VoidCallback onExit;

  /// 先关弹窗再返回：两步都走同一个 Navigator，
  /// 不先 pop 掉弹窗的话 `onExit` 弹出的会是弹窗自己。
  void _exit(BuildContext context) {
    Navigator.of(context).pop();
    onExit();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    // 必须包一层 Material：`showGeneralDialog` 的页面子树没有 Material 祖先时，
    // `Text` 会退化成 Flutter 的 `_errorTextStyle`（红字 + 黄色双下划线）。
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const Key('certification-retention-card'),
              width: layout.px(_cardWidth),
              height: layout.px(_cardHeight),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RemoteImage(
                      url: retention.imageUrl,
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned(
                    top: layout.px(_stayButtonTop),
                    left: layout.px((_cardWidth - _stayButtonWidth) / 2),
                    width: layout.px(_stayButtonWidth),
                    height: layout.px(_stayButtonHeight),
                    child: GestureDetector(
                      key: const Key('certification-retention-stay'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Center(
                        child: Text(
                          retention.resolvedContinueText,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.retentionPrimaryText,
                            fontFamily: 'Helvetica',
                            fontSize: layout.px(_stayFontSize),
                            fontWeight: FontWeight.w700,
                            height: _stayLineHeight / _stayFontSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: layout.px(_exitGap - _exitTapPadding)),
            GestureDetector(
              key: const Key('certification-retention-exit'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _exit(context),
              child: Padding(
                padding: layout.edgeInsets(
                  top: _exitTapPadding,
                  bottom: _exitTapPadding,
                ),
                child: Text(
                  retention.resolvedExitText,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    // 设计稿 `text_4` 是纯白，直接复用通用白色令牌。
                    color: AppColors.white,
                    fontFamily: 'Helvetica',
                    fontSize: layout.px(_exitFontSize),
                    fontWeight: FontWeight.w700,
                    height: _exitLineHeight / _exitFontSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
