import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// 一次活体检测的结果。
///
/// 字段与原生 `TrustDecisionRegistrar` 回传的字典一一对应；原生侧对齐过 key，
/// Dart 侧只做类型兜底，不改写内容。
class LivenessOutcome {
  const LivenessOutcome({
    this.passed = false,
    this.code = -1,
    this.message = '',
    this.imageBase64 = '',
    this.livenessId = '',
    this.sequenceId = '',
  });

  /// 是否通过活体检测。
  final bool passed;

  /// SDK 结果码，失败时可用于排查。
  final int code;

  /// SDK 文案 / 失败原因。
  final String message;

  /// 抓拍的人脸图（base64，可能带 `data:image/...;base64,` 前缀）。
  final String imageBase64;

  /// SDK 生成的活体编号，上传接口 `gargantua` 需要它。
  final String livenessId;

  /// SDK 的流水号（只用于排查，不上传）。
  final String sequenceId;

  /// 抓拍图和活体编号都拿到了，才能上传。
  bool get hasUploadPayload => imageBase64.isNotEmpty && livenessId.isNotEmpty;
}

/// 把信任决策（TrustDecision）活体 SDK 接到 Dart 侧。
///
/// 原生实现见 `ios/Runner/TrustDecisionRegistrar.swift`：同一个 method channel
/// 也承载设备风控初始化，这里只调活体那一个方法。
///
/// 单独抽成类是为了两件事：
/// 1. 页面不直接碰 [MethodChannel]，方便测试时整体替换成假实现；
/// 2. SDK 可能不返回、也可能因为没有原生插件直接抛异常，统一在这里翻译成
///    [LivenessOutcome]，别让金融页因为 SDK 异常闪退。
class LivenessGateway {
  LivenessGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// 与 iOS 侧注册的 channel 名保持一致。
  static const channelName = 'laya_credit/client_bridge';

  /// 原生注册的活体方法名。
  static const methodName = 'showTrustDecisionLiveness';

  final MethodChannel _channel;

  /// 拉起活体 SDK。
  ///
  /// [license] 是 `POST /outsulk/carline` 下发的活体授权码（活体类型 7 时
  /// 就是响应里的 `inducted`）。
  Future<LivenessOutcome> run(String license) async {
    if (!Platform.isIOS) {
      return const LivenessOutcome(
        message: 'Liveness verification is only available on iOS.',
      );
    }

    try {
      final payload = await _channel.invokeMapMethod<Object?, Object?>(
        methodName,
        license,
      );
      if (payload == null) {
        return const LivenessOutcome(message: 'Liveness returned no result.');
      }
      return _fromPayload(payload);
    } on PlatformException catch (error) {
      return LivenessOutcome(
        code: error.code.isEmpty ? -1 : int.tryParse(error.code) ?? -1,
        message: error.message ?? 'Unable to start liveness verification.',
      );
    } on MissingPluginException {
      // 单元测试 / 未接入原生插件的环境会走到这里。
      return const LivenessOutcome(
        message: 'Liveness verification is unavailable.',
      );
    }
  }

  LivenessOutcome _fromPayload(Map<Object?, Object?> payload) {
    return LivenessOutcome(
      passed: _boolOf(payload['success']),
      code: _intOf(payload['code']),
      message: _stringOf(payload['message']),
      imageBase64: _stringOf(payload['image']),
      livenessId: _stringOf(payload['liveness_id']),
      sequenceId: _stringOf(payload['sequence_id']),
    );
  }

  bool _boolOf(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().trim().toLowerCase() == 'true';
  }

  int _intOf(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? -1;
  }

  String _stringOf(Object? value) => value?.toString().trim() ?? '';
}
