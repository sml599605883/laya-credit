import Flutter
import UIKit
import CFNetwork
import StoreKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize device-risk collection as early as possible during launch.
    TrustDecisionRegistrar.shared.activate()
    // 推送：接管通知回调；冷启动点通知时先把路由暂存，等 Flutter 侧监听后补发。
    UNUserNotificationCenter.current().delegate = self
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      PushNotificationRegistrar.shared.acceptNotificationPayload(payload)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 推送通道：APNs token 注册与通知点击路由。
    if let pushRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LayaCreditPush"
    ) {
      PushNotificationRegistrar.shared.register(with: pushRegistrar.messenger())
    }

    // 上报采集通道：定位 / 设备快照 / 跟踪授权（推送 token 走上面的推送通道）。
    if let reportRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LayaCreditReport"
    ) {
      ReportRegistrar.shared.register(with: reportRegistrar.messenger())
    }

    // 抓包代理通道：读 iOS 系统代理设置下发给 Dart 侧（dart:io 不会自动读系统代理）。
    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "LayaCreditCaptureProxy"
      )
    else {
      return
    }

    TrustDecisionRegistrar.shared.register(with: registrar.messenger())

    let channel = FlutterMethodChannel(
      name: "laya_credit/capture_proxy",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getSystemProxy" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
          as? [String: Any],
        (settings[kCFNetworkProxiesHTTPEnable as String] as? NSNumber)?.boolValue == true,
        let host = settings[kCFNetworkProxiesHTTPProxy as String] as? String,
        let port = (settings[kCFNetworkProxiesHTTPPort as String] as? NSNumber)?.intValue,
        !host.isEmpty,
        port > 0
      else {
        result(nil as Any?)
        return
      }
      result(["host": host, "port": port])
    }

    // App Store 评分通道：H5 通过 WebView 桥的 `grade` 动作请求评分。
    // 与风控/活体通道分开，避免把 StoreKit 逻辑混进风控 SDK。
    let reviewChannel = FlutterMethodChannel(
      name: "laya_credit/app_review",
      binaryMessenger: registrar.messenger()
    )
    reviewChannel.setMethodCallHandler { call, result in
      guard call.method == "requestAppReview" else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        guard
          let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
          result(nil)
          return
        }
        SKStoreReviewController.requestReview(in: scene)
        result(nil)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    PushNotificationRegistrar.shared.updatePushToken(token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // 带跳转地址的通知由 App 内自行处理，不再重复弹系统横幅。
    let routed = PushNotificationRegistrar.shared.acceptNotificationPayload(
      notification.request.content.userInfo
    )
    completionHandler(routed ? [] : [.banner, .badge, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    PushNotificationRegistrar.shared.acceptNotificationPayload(
      response.notification.request.content.userInfo
    )
    completionHandler()
  }
}
