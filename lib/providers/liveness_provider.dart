import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/face/liveness_gateway.dart';

/// 活体检测网关。
///
/// 页面通过它拉起 TrustDecision SDK，不直接依赖 [MethodChannel]；
/// widget 测试里覆盖成假实现即可跑到「检测通过 -> 上传」之后的分支。
final livenessGatewayProvider = Provider<LivenessGateway>(
  (ref) => LivenessGateway(),
);
