import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 证件照来源。
///
/// [code] 与上传接口 `POST /outsulk/fashioned` 的 `chromogenous` 取值一一对应，
/// 页面不要自己拼 `'1'` / `'2'`。
enum IdentityPhotoSource {
  album('1'),
  camera('2');

  const IdentityPhotoSource(this.code);

  final String code;
}

/// 取一张证件照并压到上传接口能接受的体积。
///
/// 页面只依赖这里的三个语义化方法，不直接碰 image_picker / 压缩库，
/// 测试时可以注入假实现替换掉会弹系统 UI 的真实实现。
class IdentityPhotoService {
  IdentityPhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// 单张图片的体积上限（500KB，产品约定）。
  static const maxBytes = 500 * 1024;

  /// 压缩档位：长边上限 + 质量。从高到低依次尝试，命中 500KB 就提前返回。
  ///
  /// 固定档位而不是「每轮 -5 质量」的循环，是为了让压缩结果可预期、
  /// 也避免在低端机上把同一张图反复编解码。
  static const _presets = <(int longSide, int quality)>[
    (1600, 85),
    (1200, 65),
    (900, 45),
  ];

  /// 从 [source] 取一张图，取消返回 null。
  Future<String?> pick(IdentityPhotoSource source) async {
    final camera = source == IdentityPhotoSource.camera;
    final picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
      // 相册取图不需要完整 EXIF，能少读一次照片元数据。
      requestFullMetadata: camera,
    );
    return picked?.path;
  }

  /// 把 [path] 压到 [maxBytes] 以内；压不到时返回体积最小的那次结果。
  Future<String?> compressToLimit(String path) async {
    final source = File(path);
    if (!source.existsSync()) return null;
    if (source.lengthSync() <= maxBytes) return path;

    final size = await _decodeSize(path);
    File? smallest;

    for (final (longSide, quality) in _presets) {
      final target = await _compress(
        source: path,
        size: size,
        longSide: longSide,
        quality: quality,
      );
      if (target == null) break;
      smallest = target;
      if (target.lengthSync() <= maxBytes) return target.path;
    }

    return smallest?.path;
  }

  Future<File?> _compress({
    required String source,
    required ui.Size? size,
    required int longSide,
    required int quality,
  }) async {
    final directory = await getTemporaryDirectory();
    final target =
        '${directory.path}/id_photo_${DateTime.now().microsecondsSinceEpoch}.jpg';

    // 原生实现用 `minWidth/minHeight` 做除数算缩放比，传 0 会除零崩溃；
    // 尺寸读不出来时退回插件默认值（只会等比缩小，不会放大）。
    var minWidth = 1920;
    var minHeight = 1080;
    if (size != null && size.width > 0 && size.height > 0) {
      final scale = size.longestSide <= longSide
          ? 1.0
          : longSide / size.longestSide;
      minWidth = math.max(1, (size.width * scale).round());
      minHeight = math.max(1, (size.height * scale).round());
    }

    final result = await FlutterImageCompress.compressAndGetFile(
      source,
      target,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    return result == null ? null : File(result.path);
  }

  Future<ui.Size?> _decodeSize(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      final size = ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      // 尺寸读不出来时按插件默认尺寸兜底（只会等比缩小，不会放大）。
      return null;
    }
  }
}
