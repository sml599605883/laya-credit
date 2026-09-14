import 'package:flutter/material.dart';

/// 设计令牌：颜色。
///
/// 数值取自蓝湖导出切图（`assets/`）的取色结果，代码中禁止再出现硬编码 Hex，
/// 一律引用这里的常量。新增颜色请按「用途」命名，而不是按色值命名。
abstract final class AppColors {
  /// 品牌主色（深墨绿--青绿渐变卡片的中间色）。
  static const primary = Color(0xFF195D42);

  /// 页面浅色底（个人中心、Tab 栏底色）。
  static const surfaceMint = Color(0xFFECFADC);

  /// 深色底（首页往上滚动区域）。
  static const surfaceDark = Color(0xFF191F1F);

  /// 深色高光（首页顶部金色光晕）。
  static const darkGlow = Color(0xFF59542A);

  /// 抽屉/纯白底。
  static const surface = Color(0xFFFFFFFF);

  /// 主文字色。
  static const textPrimary = Color(0xFF334141);

  /// 次级文字色。
  static const textSecondary = Color(0xFF606060);

  /// 提示性文字/图标（箭头）。
  static const textHint = Color(0xFF989898);

  /// 浅色图标（深色底上的未选中态）。
  static const iconLight = Color(0xFFF8F8F8);

  /// 深色图标（浅色底上的选中态）。
  static const iconDark = Color(0xFF101010);

  /// Tab 栏底槽色。
  static const tabBarTrack = Color(0xFF334141);

  /// 首页运营位渐变（左 -> 右）。
  static const bannerStart = Color(0xFFEA3B26);
  static const bannerEnd = Color(0xFFDA202D);

  /// 订单卡片渐变（左 -> 右）。
  static const orderCardStart = Color(0xFF0E494F);
  static const orderCardEnd = Color(0xFF237035);

  /// 弹窗遮罩。
  static const dialogBarrier = Color(0x73000000);

  /// 分割线。
  static const divider = Color(0xFFE6E6E6);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
}
