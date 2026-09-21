import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 通用原生能力桥。
///
/// 独立 method channel `laya_credit/app_review`（原生实现见
/// `ios/Runner/AppDelegate.swift`），与风控/活体通道分开。这里只封装
/// 「WebView 请求 App Store 评分」这一个能力，方法缺失或不支持时降级打日志，
/// 不让 H5 的评分请求把页面拖崩。
class ClientBridge {
  ClientBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// 与 iOS 侧注册的 channel 名保持一致。
  static const channelName = 'laya_credit/app_review';

  /// 原生注册的评分方法名。
  static const requestAppReviewMethod = 'requestAppReview';

  final MethodChannel _channel;

  /// 请求 App Store 评分。仅 iOS 生效，Android 直接忽略。
  Future<void> requestAppReview() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>(requestAppReviewMethod);
    } catch (error) {
      debugPrint('[ClientBridge] requestAppReview 失败: $error');
    }
  }
}
