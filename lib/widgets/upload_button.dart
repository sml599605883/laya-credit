import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// 认证流程里的主行动按钮（蓝湖稿 `text-wrapper_3` / `text-wrapper_4`）。
///
/// 底图是设计导出的柠檬绿胶囊（`assets/id_verify/id_verify_upload_button.png`，
/// 343x48 + 24 圆角），文案由代码叠上去，证件上传页与证件信息确认页共用，
/// 避免两份实现各自漂移。
class UploadButton extends StatelessWidget {
  const UploadButton({
    required this.layout,
    required this.onTap,
    super.key,
    this.enabled = true,
    this.fontSize = 16.0,
    this.lineHeight = 22.0,
  });

  /// 按钮高度（设计稿 `text-wrapper_4`：13 + 22 + 13）。
  static const height = 48.0;

  final AppLayout layout;
  final VoidCallback onTap;

  /// 请求进行中置灰，既挡住重复点击，也避免用户以为没点上。
  final bool enabled;

  /// 文案字号与行高。默认取证件上传页稿的 16 / 22；借款确认页稿是 14 / 17。
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: layout.px(height),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 底图：柠檬绿胶囊 + 24 圆角。
          Image.asset(AppAssets.idVerifyUploadButton, fit: BoxFit.fill),
          Center(
            child: Text(
              'Upload',
              style: TextStyle(
                color: AppColors.idVerifyUploadButtonText,
                fontSize: layout.px(fontSize),
                fontWeight: FontWeight.w500,
                // 设计稿：证件上传页 `font-size: 16px; line-height: 22px`。
                height: lineHeight / fontSize,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              customBorder: RoundedRectangleBorder(
                borderRadius: layout.radius(height / 2),
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
