import 'package:flutter/material.dart';

import '../core/navigation/navigation.dart';
import '../theme/theme.dart';
import 'back_nav_bar.dart';

/// 认证流程各页统一的顶部布局：通栏头图 + 悬浮导航标题 + 引导段落。
///
/// 证件选择 / 证件上传 / 证件确认 / 人脸核验 / 个人信息 / 绑定银行卡 / 紧急联系人
/// 这几张蓝湖稿的顶部是同一套结构（设计稿 `section_1` 头图 + `block_2` 导航行 +
/// `text_4` 引导段），差异只在导航标题、引导文案、段落排版和头图切图。
/// 这里把这层骨架收拢成一个组件，页面只传入自己的文案与内容，避免每页重抄一遍
/// Stack 定位公式。
///
/// 用法：页面把自己的内容（第一屏顶边用 `SizedBox` 顶开）作为 [child]，
/// 组件会把它接在头图与引导段下方、同一个滚动容器里。
class CertificationScaffold extends StatelessWidget {
  /// 引导段落顶部与导航行之间的固定间距（设计稿 pt）。
  static const double _promptTopGap = 6.0;

  /// 引导段落底边到头图下沿的固定间距（设计稿 pt）。
  static const double _promptBottomInset = 34.0;

  const CertificationScaffold({
    required this.navTitle,
    required this.child,
    this.prompt,
    this.promptGap = 18.0,
    this.promptWidth = 204.0,
    this.promptFontSize = 16.0,
    this.promptLineHeight = 19.0,
    this.headerAsset = AppAssets.idVerifyHeaderBlank,
    this.headerHeight = 213.0,
    this.dismissKeyboardOnTap = false,
    this.dismissKeyboardOnDrag = false,
    this.bottomNavigationBar,
    super.key,
  });

  /// 导航行居中标题（设计稿 `block_2`）。
  final String navTitle;

  /// 头图下方的页面内容，通常是一个 `Column`。
  final Widget child;

  /// 头图上的引导段落；为 null 时不渲染（如头图自带标题的证件选择页）。
  final String? prompt;

  /// 引导段落相对导航行的下移量（设计稿：导航行底边 -> 段落顶边）。
  final double promptGap;

  /// 引导段落宽度（设计稿 `text_4` 的 `width`）。
  final double promptWidth;

  /// 引导段字号 / 行高；行高按字号折算成 `TextStyle.height`。
  final double promptFontSize;
  final double promptLineHeight;

  /// 通栏头图切图与高度（设计稿 `section_1`，375x213）。
  final String headerAsset;
  final double headerHeight;

  /// 点击空白是否收起键盘（个人信息 / 绑定银行卡 / 紧急联系人稿需要）。
  final bool dismissKeyboardOnTap;

  /// 拖动滚动容器是否收起键盘，与 [dismissKeyboardOnTap] 配合使用。
  final bool dismissKeyboardOnDrag;

  /// 页面底部固定操作条（如个人信息页的 `Upload` 条）。
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final prompt = this.prompt;

    final body = Stack(
      children: [
        SingleChildScrollView(
          keyboardDismissBehavior: dismissKeyboardOnDrag
              ? ScrollViewKeyboardDismissBehavior.onDrag
              : ScrollViewKeyboardDismissBehavior.manual,
          child: Stack(
            children: [
              // 头图区域：固定高度（375pt 设计稿等比换算），引导段落用 top / bottom
              // 约束在这个区域内，超出可用高度时整段等比缩小而非被下方内容遮挡。
              SizedBox(
                height: layout.px(headerHeight),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(headerAsset, fit: BoxFit.cover),
                    ),
                    if (prompt != null)
                      Positioned(
                        // 顶边固定在导航行下方 [_promptTopGap]；导航行自己让开了
                        // 安全区，这里把安全区补回来。
                        top:
                            safeTop +
                            layout.px(
                              BackNavBar.height + _promptTopGap,
                            ),
                        left: layout.px(AppSpacing.pageHorizontal),
                        bottom: layout.px(_promptBottomInset),
                        child: SizedBox(
                          width: layout.px(promptWidth),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomLeft,
                            child: SizedBox(
                              width: layout.px(promptWidth),
                              child: Text(
                                prompt,
                                style: TextStyle(
                                  color: AppColors.idVerifyHeaderText,
                                  fontSize: layout.px(promptFontSize),
                                  fontWeight: FontWeight.w700,
                                  height: promptLineHeight / promptFontSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
        // 导航浮层固定在头图上：设计稿内容正好一屏放得下，小屏滚动时返回按钮
        // 也不能跟着滚出屏幕，否则用户没有出口。
        BackNavBar(
          layout: layout,
          title: navTitle,
          onBack: () => AppNavigator.pop(),
        ),
      ],
    );

    return Scaffold(
      // 设计稿 `page` 底色 `rgba(245,245,245)`。
      backgroundColor: AppColors.idVerifyBackground,
      body: dismissKeyboardOnTap
          ? GestureDetector(
              // 空白区域点击收起键盘，子级（输入框 / 字段 / 按钮）优先响应。
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: body,
            )
          : body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
