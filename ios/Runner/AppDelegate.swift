import Flutter
import UIKit
import CFNetwork
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize device-risk collection as early as possible during launch.
    TrustDecisionRegistrar.shared.activate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

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
}
