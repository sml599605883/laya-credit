import 'package:flutter/material.dart';

import '../core/navigation/navigation.dart';
import '../core/ui/toast_helper.dart';
import '../theme/theme.dart';
import '../widgets/back_nav_bar.dart';

/// 导航标题（设计稿 `text_10`）。
const _navTitle = 'ID Verification';

/// 头图高度（设计稿 `section_1`，375x213）。
const _headerHeight = 213.0;

/// 引导段落相对导航行的下移量（设计稿：导航行底边 78 -> 段落顶边 104）。
const _promptGap = 18.0;

/// 引导段落宽度与行数（设计稿 `text_4 { width: 204px }`，四行）。
const _promptWidth = 204.0;

/// 引导段落文案（设计稿 `text_4`）。
///
/// 四行就是设计稿的换行位置：204pt 宽下 Helvetica-Bold 16 的断行结果，
/// 换成系统字体后断点会漂移，所以按设计稿写死换行符。
/// TODO(接口): 身份信息响应里还有一组 `befleas`（引导文案，低版本 / 未灰度用户不下发），
/// 文档没写清它属于哪一页，真机联调确认是这段文案后改成接口下发。
const _prompt =
    'Valid official credentials\n'
    'avoid rejection and\n'
    'quickly unlock your loan\n'
    'service access.';

/// 引导块顶边（设计稿 `text-wrapper_5 { top: 194 }`）：
/// 比头图底边高 19pt，白卡顶边压在头图下沿上。
const _demoTop = 194.0;

/// 引导块宽高比（切图 343x420，等于设计稿里两张卡片的等比尺寸）。
const _demoAspectRatio = 343 / 420;

/// 引导块与 `Upload` 按钮之间的间距（设计稿 614 -> 714）。
const _demoToButtonGap = 100.0;

/// `Upload` 按钮高度（设计稿 `text-wrapper_4`：13 + 22 + 13）。
const _buttonHeight = 48.0;

/// 按钮下沿到页面底边的留白（设计稿 762 -> 812，比手势条高，不用再补安全区）。
const _buttonBottom = 50.0;

/// 证件上传页（蓝湖稿 `03-01 - 身份认证-上传身份证`），认证流程第二步。
///
/// 页面分三段，与设计稿一一对应：
/// 1. 通栏头图（`section_1`）：绿色渐变 + 吉祥物。切图不带标题，导航标题与
///    引导段落由页面叠上去，返回按钮复用 [BackNavBar]。
/// 2. 上传引导整块切图（`section_3` + `group_1` 合起来 343x420）：
///    `Demonstration` / `Wrong Demonstration` 两张白卡、示范图与三张错误示例。
/// 3. 底部 `Upload` 主按钮（`text-wrapper_4`）：柠檬绿胶囊，点击后弹出
///    [UploadMethodSheet] 让用户选相机 / 相册。
///
/// 卡类型 [cardType] 就是证件选择页的行文案，上传 / 保存接口都用它取值。
class IdUploadPage extends StatelessWidget {
  const IdUploadPage({
    super.key,
    required this.productId,
    required this.cardType,
  });

  /// 产品 id。
  final String productId;

  /// 选中的证件类型文案。
  final String cardType;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      // 设计稿 `page` 底色 `rgba(245,245,245)`。
      backgroundColor: AppColors.idVerifyBackground,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Stack(
              children: [
                // 头图通栏：宽度铺满，高度按 375pt 设计稿等比换算。
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    AppAssets.idVerifyHeaderBlank,
                    height: layout.px(_headerHeight),
                    fit: BoxFit.cover,
                  ),
                ),
                // 引导段落浮在头图上：设计稿的顶边 104 是「设计稿状态栏 + 导航行 + 18」，
                // 导航行自己让开了安全区，所以这里也把安全区补回来。
                Positioned(
                  top: safeTop + layout.px(BackNavBar.height + _promptGap),
                  left: layout.px(AppSpacing.pageHorizontal),
                  child: SizedBox(
                    width: layout.px(_promptWidth),
                    child: Text(
                      _prompt,
                      style: TextStyle(
                        color: AppColors.idVerifyHeaderText,
                        fontSize: layout.px(16),
                        fontWeight: FontWeight.w700,
                        // 设计稿：`font-size: 16px; line-height: 19px`。
                        height: 19 / 16,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: layout.px(_demoTop)),
                    Padding(
                      padding: layout.edgeInsets(
                        left: AppSpacing.pageHorizontal,
                        right: AppSpacing.pageHorizontal,
                      ),
                      child: AspectRatio(
                        aspectRatio: _demoAspectRatio,
                        child: Image.asset(
                          AppAssets.idVerifyUploadDemo,
                          fit: BoxFit.fill,
                          semanticLabel: _prompt,
                        ),
                      ),
                    ),
                    SizedBox(height: layout.px(_demoToButtonGap)),
                    Padding(
                      padding: layout.edgeInsets(
                        left: AppSpacing.pageHorizontal,
                        right: AppSpacing.pageHorizontal,
                      ),
                      child: _UploadButton(
                        layout: layout,
                        onTap: () => _showUploadMethods(context, layout),
                      ),
                    ),
                    SizedBox(height: layout.px(_buttonBottom)),
                  ],
                ),
              ],
            ),
          ),
          BackNavBar(
            layout: layout,
            title: _navTitle,
            onBack: () => AppNavigator.pop(),
          ),
        ],
      ),
    );
  }

  /// 弹出「选择上传方式」面板。
  Future<void> _showUploadMethods(
    BuildContext context,
    AppLayout layout,
  ) async {
    final method = await showModalBottomSheet<UploadMethod>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.dialogBarrier,
      elevation: 0,
      // 设计稿的面板顶部是直角。
      shape: const RoundedRectangleBorder(),
      builder: (context) => UploadMethodSheet(layout: layout),
    );
    if (method == null || !context.mounted) return;

    switch (method) {
      case UploadMethod.camera:
      case UploadMethod.album:
        // TODO(依赖): 取图需要新增 image_picker / permission_handler /
        // flutter_image_compress（peso_shield 用的是这三个），iOS 还要补相册的
        // NSPhotoLibraryUsageDescription。
        // TODO(接口): 上传接口 `/outsulk/fashioned` 的字段映射还没拿到
        // （见 README「其余接口未接入」）。混淆字段名写错不会报错、只会静默读到 null，
        // 所以这里先给占位提示；拿到 `7.map.html` 的映射后照 peso_shield 的
        // `IdentityUploadPage._pickCompressAndUpload` 接：
        // 权限 -> 取图 -> 压缩到 500KB -> multipart 上传
        // （卡类型 = [cardType]，来源：相册 1 / 相机 2）-> 成功后进证件确认页。
        ToastHelper.showMessage('${method.label} is not available yet');
      case UploadMethod.quit:
        // 设计稿里 Quit 是次要行动（灰色），按「关掉面板」处理。
        break;
    }
  }
}

/// 底部 `Upload` 主按钮（设计稿 `text-wrapper_4`）。
class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.layout, required this.onTap});

  final AppLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.px(_buttonHeight),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 底图：柠檬绿胶囊 + 24 圆角（用户提供的 `矩形@3x.png`）。
          Image.asset(AppAssets.idVerifyUploadButton, fit: BoxFit.fill),
          Center(
            child: Text(
              'Upload',
              style: TextStyle(
                color: AppColors.idVerifyUploadButtonText,
                fontSize: layout.px(16),
                fontWeight: FontWeight.w500,
                // 设计稿：`font-size: 16px; line-height: 22px`。
                height: 22 / 16,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: RoundedRectangleBorder(
                borderRadius: layout.radius(_buttonHeight / 2),
              ),
              // 底图是浅柠檬绿，水波纹用深色才看得出来。
              splashColor: AppColors.idVerifyUploadButtonText.withValues(
                alpha: 0.08,
              ),
              highlightColor: AppColors.idVerifyUploadButtonText.withValues(
                alpha: 0.04,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「选择上传方式」面板里的行动项（蓝湖稿 `03-01 - 身份认证-选择上传方式`）。
enum UploadMethod {
  camera('Camera'),
  album('Album'),
  quit('Quit');

  const UploadMethod(this.label);

  final String label;
}

/// `Upload` 按钮点击后从底部弹出的上传方式面板。
///
/// 设计稿（375x812）：面板顶边 630、通栏直角白底；`Camera` / `Album` 两行各 57pt，
/// 中间 1pt 分隔线；`Quit` 前面垫 8pt 灰色分组间隔带，行高 59pt
/// （上下各 20pt 内边距 + 19pt 行高），文案居中且最后一行贴着屏幕底边，
/// 真机上由 [SafeArea] 补手势条。
class UploadMethodSheet extends StatelessWidget {
  const UploadMethodSheet({required this.layout, super.key});

  final AppLayout layout;

  /// `Camera` / `Album` 行高（设计稿 630 -> 687、688 -> 745）。
  static const _itemHeight = 57.0;

  /// 分组间隔带高度（设计稿 745 -> 753）。
  static const _groupGap = 8.0;

  /// `Quit` 行高（设计稿 753 -> 812）。
  static const _quitHeight = 59.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 设计稿的面板按 812pt 通栏画到底、没留手势条位置（`text_13` 底边 792 + 20 = 812），
      // 真机上必须自己让开：`top: false` 只补底部，面板顶部仍贴着设计稿的位置。
      // showModalBottomSheet 默认 `useSafeArea: false`，它只 removePadding(removeTop: true)，
      // 底部 inset 还在，所以这里能拿到真实的手势条高度。
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _item(context, UploadMethod.camera, _itemHeight, 14),
          Divider(
            height: layout.px(1),
            thickness: layout.px(1),
            color: AppColors.actionSheetDivider,
          ),
          _item(context, UploadMethod.album, _itemHeight, 14),
          SizedBox(
            height: layout.px(_groupGap),
            child: const ColoredBox(color: AppColors.actionSheetGap),
          ),
          _item(context, UploadMethod.quit, _quitHeight, 16),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    UploadMethod method,
    double height,
    double fontSize,
  ) {
    // 设计稿里 Quit 是次要行动（灰色），Camera / Album 是主行动（深色）。
    final primary = method != UploadMethod.quit;

    return SizedBox(
      height: layout.px(height),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(method),
        child: Center(
          child: Text(
            method.label,
            style: TextStyle(
              color: primary
                  ? AppColors.actionSheetText
                  : AppColors.actionSheetTextSecondary,
              fontSize: layout.px(fontSize),
              // 设计稿：`text_11` / `text_12` 行高 17，`text_13` 行高 19。
              height: (primary ? 17 : 19) / fontSize,
            ),
          ),
        ),
      ),
    );
  }
}
