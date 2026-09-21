import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// 「账号」退出 / 注销的挽留弹窗。
///
/// 对应蓝湖稿 `07-01 - 个人中心-退出挽留弹窗` 与
/// `07-01 - 个人中心-注销挽留弹窗`：两个弹窗版式完全一致，只有文案不同。
///
/// 版式直接用用户提供的整卡切图（设计稿 `编组`，285x315，`@3x`）——
/// 信封插画、标题、正文都烘焙在切图里，与设计稿逐像素一致，
/// 也不受设备上 `Impact` / `Helvetica` 是否存在影响。切图里留在胶囊按钮
/// 上的文案（设计稿 `text_3`）和插画下方的次要行动（`text_4`）是空的，
/// 这两处由代码叠上去。
enum AccountRetentionAction { logout, deleteAccount }

/// 弹窗里由代码叠加的文案（设计稿 `text_3` / `text_4`，逐字照搬）。
class _RetentionCopy {
  const _RetentionCopy({
    required this.asset,
    required this.stayLabel,
    required this.exitLabel,
  });

  /// 整卡切图（标题 / 正文已烘焙在图里）。
  final String asset;

  /// 主按钮文案（设计稿 `text_3`）：留在 App，等同于关闭弹窗。
  final String stayLabel;

  /// 次要行动文案（设计稿 `text_4`）：真正退出 / 注销。
  final String exitLabel;
}

/// 退出登录挽留弹窗（`07-01 - 个人中心-退出挽留弹窗`，图内文案 `Wait!`）。
const _logoutCopy = _RetentionCopy(
  asset: AppAssets.mineLogoutRetention,
  stayLabel: 'Track Now',
  exitLabel: 'Log Out',
);

/// 注销账号挽留弹窗（`07-01 - 个人中心-注销挽留弹窗`，图内文案 `Are you sure?`）。
const _deleteAccountCopy = _RetentionCopy(
  asset: AppAssets.mineDeleteAccountRetention,
  stayLabel: 'Stay',
  exitLabel: 'Delete',
);

/// 弹出挽留弹窗。
///
/// [onExit] 是「仍然退出 / 注销」的真实动作，返回是否成功：
/// 返回 `false` 时弹窗保持打开（错误提示由调用方负责），返回 `true` 时关闭。
Future<void> showAccountRetentionDialog({
  required BuildContext context,
  required AccountRetentionAction action,
  required Future<bool> Function() onExit,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss account retention dialog',
    barrierColor: AppColors.dialogBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AccountRetentionDialog(action: action, onExit: onExit),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _AccountRetentionDialog extends StatefulWidget {
  const _AccountRetentionDialog({required this.action, required this.onExit});

  final AccountRetentionAction action;
  final Future<bool> Function() onExit;

  @override
  State<_AccountRetentionDialog> createState() =>
      _AccountRetentionDialogState();
}

class _AccountRetentionDialogState extends State<_AccountRetentionDialog> {
  /// 退出 / 注销请求进行中：防重复点击。
  bool _submitting = false;

  // 以下都是设计稿 375pt 基准下的尺寸，真机上由 `AppLayout.px` 换算。
  //
  // 整卡切图（设计稿 `编组`）铺满 285x315 的盒子。
  static const _cardWidth = 285.0;
  static const _cardHeight = 315.0;

  /// 主按钮热区：对着切图里那枚胶囊（实测 285x315 空间里
  /// x 59..225、y 250..291）。胶囊底是切图自带的，这里只叠文案。
  static const _stayButtonTop = 250.0;
  static const _stayButtonWidth = 166.0;
  static const _stayButtonHeight = 41.0;
  static const _stayFontSize = 18.0;
  static const _stayLineHeight = 22.0;

  /// 切图与次要行动之间的间距（设计稿 `text_4` 的 `margin-top: 18px`）。
  static const _exitGap = 18.0;
  static const _exitFontSize = 16.0;
  static const _exitLineHeight = 19.0;

  /// 次要行动文字的上下留白：加在 19pt 高的文字外撑出可点的热区，
  /// 视觉位置靠 `_exitGap` 减掉这部分补回来。
  static const _exitTapPadding = 8.0;

  _RetentionCopy get _copy => switch (widget.action) {
    AccountRetentionAction.logout => _logoutCopy,
    AccountRetentionAction.deleteAccount => _deleteAccountCopy,
  };

  Future<void> _confirmExit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final succeeded = await widget.onExit();
    if (!mounted) return;
    if (succeeded) {
      Navigator.of(context).pop();
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final copy = _copy;

    // 必须包一层 Material：`showGeneralDialog` 的页面子树没有 Material 祖先时，
    // `Text` 会退化成 Flutter 的 `_errorTextStyle`（红字 + 黄色双下划线）。
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: layout.px(_cardWidth),
              height: layout.px(_cardHeight),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(copy.asset, fit: BoxFit.fill),
                  ),
                  Positioned(
                    top: layout.px(_stayButtonTop),
                    left: layout.px((_cardWidth - _stayButtonWidth) / 2),
                    width: layout.px(_stayButtonWidth),
                    height: layout.px(_stayButtonHeight),
                    child: GestureDetector(
                      key: const Key('account-retention-stay'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Center(
                        child: Text(
                          copy.stayLabel,
                          maxLines: 1,
                          softWrap: false,
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
              key: const Key('account-retention-exit'),
              behavior: HitTestBehavior.opaque,
              onTap: _submitting ? null : _confirmExit,
              child: Padding(
                padding: layout.edgeInsets(
                  top: _exitTapPadding,
                  bottom: _exitTapPadding,
                ),
                child: Text(
                  copy.exitLabel,
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
