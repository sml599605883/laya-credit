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
  private static let pushTokenKey = "laya_credit.report.apple_push_token"
  private static let registrationTimeout: TimeInterval = 5

  private var eventSink: FlutterEventSink?
  private var pendingNotificationRoutes: [String] = []
  private var pendingRegistrationResult: FlutterResult?
  private var registrationTimeoutWorkItem: DispatchWorkItem?

  /// APNs token 在原生侧持久化，Flutter 冷启动或登录补报时可以直接读取
  /// 最近一次成功注册的值，不必等待本次 `didRegister` 回调。
  private var pushToken: String {
    get {
      UserDefaults.standard.string(forKey: Self.pushTokenKey) ?? ""
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Self.pushTokenKey)
    }
  }

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
        DispatchQueue.main.async { [weak self] in
          guard let self else {
            result(
              FlutterError(
                code: "push_registrar_unavailable",
                message: "Push registrar is unavailable",
                details: nil
              )
            )
            return
          }
          self.requestRemoteNotificationRegistration(result: result)
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
    finishPendingRegistration()
    guard !token.isEmpty else { return }
    eventSink?(["type": "push_token", "token": token])
  }

  /// APNs 注册完成前保留 Flutter 的 method result，使 Dart 侧能等到本次
  /// `didRegister` / `didFail` 回调后再读取 token 并上报。
  func registrationDidFail(_ error: Error) {
    finishPendingRegistration()
  }

  private func requestRemoteNotificationRegistration(
    result: @escaping FlutterResult
  ) {
    // 重复调用时先释放旧 result，避免 Flutter method call 永久挂起。
    finishPendingRegistration()
    pendingRegistrationResult = result

    let timeout = DispatchWorkItem { [weak self] in
      self?.finishPendingRegistration()
    }
    registrationTimeoutWorkItem = timeout
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.registrationTimeout,
      execute: timeout
    )

    UIApplication.shared.registerForRemoteNotifications()
  }

  private func finishPendingRegistration() {
    registrationTimeoutWorkItem?.cancel()
    registrationTimeoutWorkItem = nil
    let result = pendingRegistrationResult
    pendingRegistrationResult = nil
    result?(nil)
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
