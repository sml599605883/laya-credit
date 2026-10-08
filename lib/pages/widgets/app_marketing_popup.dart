import 'package:flutter/material.dart';

import '../../data/models/app_dialog.dart';
import '../../theme/theme.dart';
import '../../widgets/remote_image.dart';
import 'popup_target_opener.dart';

/// 首页 / 个人中心「营销」弹窗（蓝湖稿 `08-03 - 弹窗-新产品`）。
///
/// 整块卡片（插画 / 文案 / `Apply Now` 按钮）由接口下发的图片渲染：
/// 宽度取「屏幕宽度 - 32」（设计稿左右各 16），高度按图片原始比例自适应。
/// 卡片下方 20pt 处是一枚 32x32 的关闭按钮（[AppAssets.homePopupMarketingClose]）。
/// 点卡片进落地页（[AppDialog.targetUrl]），点关闭按钮只关弹窗。
Future<void> showAppMarketingPopup({
  required BuildContext context,
  required AppDialog dialog,
  ExternalUriOpener? externalOpener,
}) {
  if (_showing) return Future<void>.value();
  _showing = true;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss marketing popup',
    barrierColor: AppColors.dialogBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AppMarketingPopup(dialog: dialog, externalOpener: externalOpener),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  ).whenComplete(() => _showing = false);
}

bool _showing = false;

class _AppMarketingPopup extends StatelessWidget {
  const _AppMarketingPopup({required this.dialog, this.externalOpener});

  final AppDialog dialog;
  final ExternalUriOpener? externalOpener;

  /// 卡片左右外边距合计（设计稿左右各 16）。
  static const _horizontalMargin = 32.0;

  /// 卡片下方到关闭按钮的间距（设计稿 `image-wrapper_1` padding-top 20）。
  static const _closeGap = 20.0;

  /// 关闭按钮尺寸（设计稿 `label_1` 32x32）。
  static const _closeSize = 32.0;

  /// 卡片圆角（设计稿 `box_1` radius 12）。
  static const _cardRadius = 12.0;

  void _onImage(BuildContext context) {
    Navigator.of(context).pop();
    openPopupTarget(dialog.targetUrl, externalOpener: externalOpener);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final popupWidth =
        MediaQuery.sizeOf(context).width - layout.px(_horizontalMargin);

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          padding: layout.edgeInsets(top: 16, bottom: 16),
          child: SizedBox(
            width: popupWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  key: const Key('app-marketing-image'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onImage(context),
                  child: ClipRRect(
                    borderRadius: layout.radius(_cardRadius),
                    child: RemoteImage(
                      url: dialog.imageUrl,
                      width: popupWidth,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
                SizedBox(height: layout.px(_closeGap)),
                GestureDetector(
                  key: const Key('app-marketing-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Image.asset(
                    AppAssets.homePopupMarketingClose,
                    width: layout.px(_closeSize),
                    height: layout.px(_closeSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
