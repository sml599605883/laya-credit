import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生推送事件。目前有两类：
/// - `{type: 'push_token', token: String}`：APNs 下发 deviceToken；
/// - `{type: 'push_route', url: String}`：通知被点击时携带的跳转地址。
typedef PushEvent = Map<String, Object?>;

/// iOS 推送原生能力桥。
///
/// 独立 method/event channel（原生实现见 `ios/Runner/PushNotificationRegistrar.swift`），
/// 与评分、抓包、风控通道分开。仅 iOS 生效，方法缺失或调用失败时降级打日志，
/// 不让推送把启动流程拖崩。
class PushBridge {
  PushBridge({MethodChannel? channel, EventChannel? eventChannel})
    : _channel = channel ?? const MethodChannel(channelName),
      _eventChannel = eventChannel ?? const EventChannel(eventChannelName);

  /// 与 iOS 侧注册的 channel 名保持一致。
  static const channelName = 'laya_credit/push';
  static const eventChannelName = 'laya_credit/push_events';

  /// 原生注册的方法名。
  static const getPushTokenMethod = 'getPushToken';
  static const registerForRemoteNotificationsMethod =
      'registerForRemoteNotifications';

  static final shared = PushBridge();

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  Stream<PushEvent>? _events;

  bool get _supported => Platform.isIOS;

  /// 读取最近一次注册得到的 APNs deviceToken；尚未拿到时返回空串。
  Future<String> getPushToken() async {
    if (!_supported) return '';
    try {
      final value = await _channel.invokeMethod<Object?>(getPushTokenMethod);
      return value?.toString().trim() ?? '';
    } catch (error) {
      debugPrint('[PushBridge] getPushToken 失败: $error');
      return '';
    }
  }

  /// 向 APNs 注册以换取 deviceToken。仅 iOS 生效。
  Future<void> registerForRemoteNotifications() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(registerForRemoteNotificationsMethod);
    } catch (error) {
      debugPrint('[PushBridge] registerForRemoteNotifications 失败: $error');
    }
  }

  /// 原生事件流（推送 token / 通知点击路由）。
  Stream<PushEvent> events() {
    if (!_supported) return const Stream<PushEvent>.empty();
    return _events ??= _eventChannel
        .receiveBroadcastStream()
        .map(_toEvent)
        .handleError((_) {})
        .asBroadcastStream();
  }

  static PushEvent _toEvent(Object? raw) {
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return const <String, Object?>{};
  }
}
