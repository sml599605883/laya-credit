import 'package:flutter/material.dart';

import '../../data/models/app_dialog.dart';
import '../../theme/theme.dart';
import 'popup_target_opener.dart';

/// 首页 / 个人中心「应用内升级」弹窗（蓝湖稿 `08-03 - 弹窗-升级提示`）。
///
/// 版式（375pt 基准）：白色卡片 343x279，卡片上方压一张 343x141 的头部切图
/// （[AppAssets.homePopupUpgradeHeader]，`New version released` 标题、绿色斜切
/// 装饰与火箭插画都烘焙在图里），火箭顶端要溢出到白卡上方——切图里透明区的
/// 高度就是溢出高度，白色部分正好盖住卡片顶部。
///
/// 卡片内由代码绘制三块内容：版本号胶囊（`V1.1.4`）、升级文案与 `Update Now`
/// 按钮。版本号与文案来自接口（[AppDialog.version] / [AppDialog.message]），
/// 按钮点了打开 [AppDialog.targetUrl]。
Future<void> showAppUpgradePopup({
  required BuildContext context,
  required AppDialog dialog,
  ExternalUriOpener? externalOpener,
}) {
  if (_showing) return Future<void>.value();
  _showing = true;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss app upgrade popup',
    barrierColor: AppColors.dialogBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AppUpgradePopup(dialog: dialog, externalOpener: externalOpener),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  ).whenComplete(() => _showing = false);
}

bool _showing = false;

class _AppUpgradePopup extends StatelessWidget {
  const _AppUpgradePopup({required this.dialog, this.externalOpener});

  final AppDialog dialog;
  final ExternalUriOpener? externalOpener;

  /// 弹窗卡片宽度（设计稿 `group_2` 343x279）。
  static const _cardWidth = 343.0;

  /// 头部切图尺寸（设计稿 `image_1` 所在组的 343x141）。
  static const _headerHeight = 141.0;

  /// 头部切图里透明区（火箭溢出）的高度：白色卡顶从切图的该位置开始，
  /// 也就是卡片相对整个弹窗的下移量（实测 1029x423 切图白色边缘在 y=71）。
  static const _cardTop = 71.0;

  /// 卡片正文起始位置（设计稿版本号胶囊 `text-wrapper_1` 距卡顶 64）。
  static const _contentTop = 64.0;

  /// 版本号胶囊圆角（设计稿 `text-wrapper_1` radius 11）。
  static const _pillRadius = 11.0;
  static const _pillFontSize = 14.0;
  static const _pillLineHeight = 17.0;

  /// 版本号胶囊到正文的间距（设计稿 `text_3` margin-top 29）。
  static const _messageGap = 29.0;
  static const _messageFontSize = 16.0;
  static const _messageLineHeight = 19.0;

  /// 正文到按钮的间距（设计稿 `text-wrapper_2` margin-top 24）。
  static const _buttonGap = 24.0;
  static const _buttonHeight = 40.0;
  static const _buttonRadius = 20.0;

  /// 卡片左右内边距（设计稿 `group_2` padding 左 11 右 17）。
  static const _cardPaddingLeft = 11.0;
  static const _cardPaddingRight = 17.0;

  /// 卡片底部圆角（设计稿实测 12）。
  static const _cardRadius = 12.0;

  /// 按钮左侧缩进（设计稿 `text-wrapper_2` margin-left 20）。
  static const _buttonLeftInset = 20.0;
  static const _buttonText = 'Update Now';

  void _onUpdate(BuildContext context) {
    Navigator.of(context).pop();
    openPopupTarget(dialog.targetUrl, externalOpener: externalOpener);
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: layout.px(_cardWidth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1) 卡片底色（只圆底部两角，顶部圆角由头部切图提供）。
              Positioned(
                left: 0,
                right: 0,
                top: layout.px(_cardTop),
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(layout.px(_cardRadius)),
                    ),
                  ),
                ),
              ),
              // 2) 头部切图（标题 + 装饰 + 火箭，火箭溢出到卡片上方）。
              Positioned(
                left: 0,
                top: 0,
                width: layout.px(_cardWidth),
                height: layout.px(_headerHeight),
                child: Image.asset(
                  AppAssets.homePopupUpgradeHeader,
                  fit: BoxFit.fill,
                ),
              ),
              // 3) 卡片内容（画在头部切图之上，版本号胶囊会压住切图白色下缘）。
              Padding(
                padding: layout.edgeInsets(
                  left: _cardPaddingLeft,
                  top: _cardTop + _contentTop,
                  right: _cardPaddingRight,
                  bottom: 16,
                ),
                child: _content(context, layout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppLayout layout) {
    final message = dialog.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: layout.edgeInsets(left: _buttonLeftInset),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _VersionPill(layout: layout, text: dialog.displayVersion),
          ),
        ),
        if (message.isNotEmpty) ...[
          SizedBox(height: layout.px(_messageGap)),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.popupUpgradeMessageText,
              fontFamily: 'Helvetica',
              fontSize: layout.px(_messageFontSize),
              height: _messageLineHeight / _messageFontSize,
            ),
          ),
        ],
        SizedBox(height: layout.px(_buttonGap)),
        Padding(
          padding: layout.edgeInsets(left: _buttonLeftInset),
          child: _UpdateButton(layout: layout, onTap: () => _onUpdate(context)),
        ),
      ],
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({required this.layout, required this.text});

  final AppLayout layout;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: layout.edgeInsets(left: 16, top: 2, right: 15, bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.popupUpgradeVersionBackground,
        borderRadius: layout.radius(_AppUpgradePopup._pillRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.white,
          fontFamily: 'Helvetica',
          fontSize: layout.px(_AppUpgradePopup._pillFontSize),
          fontWeight: FontWeight.w700,
          height:
              _AppUpgradePopup._pillLineHeight / _AppUpgradePopup._pillFontSize,
        ),
      ),
    );
  }
}

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({required this.layout, required this.onTap});

  final AppLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('app-upgrade-update'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: layout.px(_AppUpgradePopup._buttonHeight),
        decoration: BoxDecoration(
          color: AppColors.popupUpgradeButton,
          borderRadius: layout.radius(_AppUpgradePopup._buttonRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          _AppUpgradePopup._buttonText,
          style: TextStyle(
            color: AppColors.popupUpgradeButtonText,
            fontFamily: 'Helvetica',
            fontSize: layout.px(_AppUpgradePopup._pillFontSize),
            fontWeight: FontWeight.w700,
            height:
                _AppUpgradePopup._pillLineHeight /
                _AppUpgradePopup._pillFontSize,
          ),
        ),
      ),
    );
  }
}
