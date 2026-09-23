import Flutter
import UIKit
import UserNotifications

/// iOS 推送能力桥：把 APNs 注册与通知点击转成 Flutter 侧事件。
///
/// - method channel `laya_credit/push`：`getPushToken` / `registerForRemoteNotifications`；
/// - event channel `laya_credit/push_events`：`push_token` 与 `push_route` 事件。
///
/// 冷启动时通知可能在 Flutter 引擎就绪前就到达，此时把路由暂存到
/// `pendingNotificationRoutes`，等 Dart 侧开始监听后再补发，避免丢首条路由。
final class PushNotificationRegistrar: NSObject, FlutterStreamHandler {
  static let shared = PushNotificationRegistrar()

  private static let channelName = "laya_credit/push"
  private static let eventChannelName = "laya_credit/push_events"

  private var eventSink: FlutterEventSink?
  private var pendingNotificationRoutes: [String] = []
  private var pushToken = ""

  private override init() {
    super.init()
  }

  func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    let eventChannel = FlutterEventChannel(
      name: Self.eventChannelName,
      binaryMessenger: binaryMessenger
    )
    eventChannel.setStreamHandler(self)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getPushToken":
        result(self?.pushToken ?? "")
      case "registerForRemoteNotifications":
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    if !pushToken.isEmpty {
      events(["type": "push_token", "token": pushToken])
    }
    while !pendingNotificationRoutes.isEmpty {
      let route = pendingNotificationRoutes.removeFirst()
      events(["type": "push_route", "url": route])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func updatePushToken(_ token: String) {
    pushToken = token
    guard !token.isEmpty else { return }
    eventSink?(["type": "push_token", "token": token])
  }

  /// 尝试从通知 payload 中取出跳转地址并下发；取不到地址时返回 false，
  /// 交给系统按普通通知展示。
  @discardableResult
  func acceptNotificationPayload(_ userInfo: [AnyHashable: Any]) -> Bool {
    guard let route = notificationRoute(from: userInfo) else {
      return false
    }
    guard let eventSink else {
      pendingNotificationRoutes.append(route)
      return true
    }
    eventSink(["type": "push_route", "url": route])
    return true
  }

  /// 跳转地址可能直接放在 `url`，也可能嵌在 `params.url`（对象或 JSON 串）里。
  private func notificationRoute(from userInfo: [AnyHashable: Any]) -> String? {
    if let route = normalizedNotificationRoute(userInfo["url"]) {
      return route
    }
    if let params = userInfo["params"] as? [AnyHashable: Any] {
      return normalizedNotificationRoute(params["url"])
    }
    guard
      let paramsText = userInfo["params"] as? String,
      let paramsData = paramsText.data(using: .utf8),
      let decoded = try? JSONSerialization.jsonObject(with: paramsData),
      let params = decoded as? [String: Any]
    else {
      return nil
    }
    return normalizedNotificationRoute(params["url"])
  }

  private func normalizedNotificationRoute(_ value: Any?) -> String? {
    guard let value = value as? String else {
      return nil
    }
    let route = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return route.isEmpty ? nil : route
  }
}
