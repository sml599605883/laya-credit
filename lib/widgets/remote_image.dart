import 'package:flutter/material.dart';

/// 后端下发的图片（banner、产品 logo、入口图标）。
///
/// 加载失败不能留空白：banner 之类的运营位回退到本地兜底图，
/// 图标则直接隐藏，避免出现破图占位。
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    required this.url,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackAsset,
    this.color,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// 加载失败时使用的本地切图。
  final String? fallbackAsset;

  /// 单色图标的着色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback();

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (_, _, _) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(width: width, height: height);
      },
    );
  }

  Widget _fallback() {
    final asset = fallbackAsset;
    if (asset == null) return SizedBox(width: width, height: height);
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      color: color,
    );
  }
}
