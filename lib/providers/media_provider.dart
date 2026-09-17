import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/media/identity_photo.dart';

/// 证件照取图 / 压缩服务。
///
/// 页面通过它拿图，不直接 new [IdentityPhotoService]，
/// 测试时可以覆盖成不会弹系统 UI 的假实现。
final identityPhotoServiceProvider = Provider<IdentityPhotoService>(
  (ref) => IdentityPhotoService(),
);
