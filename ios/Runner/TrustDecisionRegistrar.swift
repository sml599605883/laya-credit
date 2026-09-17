import Flutter
import TDMobRisk
import UIKit

/// Wires the TrustDecision device-risk and liveness SDKs into the Flutter app.
///
/// `activate()` collects device risk data and is invoked once from
/// `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, while the method
/// channel lets Dart request a liveness check on demand.
final class TrustDecisionRegistrar: NSObject {
  static let shared = TrustDecisionRegistrar()

  private static let channelName = "laya_credit/client_bridge"
  private let trustDecisionPartnerCode = "boqin_ph"
  private let trustDecisionAppKey = "1dc25522f2adc77f5347816c0f7fa31b"
  private var hasActivated = false
  private lazy var manager = TDMobRiskManager.sharedManager()

  private override init() {
    super.init()
  }

  /// Activates device-risk collection. Safe to call more than once.
  func activate() {
    guard !hasActivated else { return }
    hasActivated = true
    manager?.pointee.initWithOptions([
      "partner": trustDecisionPartnerCode,
      "appKey": trustDecisionAppKey,
      "country": "sg",
      "language": "en",
      "showReadyPage": false,
      "runningTasks": false,
      "readPhonoe": false,
      "installPackageList": false,
      "playAudio": true,
    ])
  }

  func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "showTrustDecisionLiveness":
        self.showLiveness(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func showLiveness(_ arguments: Any?, result: @escaping FlutterResult) {
    activate()
    guard
      let license = arguments as? String, !license.isEmpty,
      let viewController = topViewController()
    else {
      result(livenessResult(success: false, payload: nil))
      return
    }

    manager?.pointee.showLivenessWithShowStyle(
      viewController,
      license,
      TDLivenessShowStylePresent,
      { payload in result(self.livenessResult(success: true, payload: payload)) },
      { payload in result(self.livenessResult(success: false, payload: payload)) }
    )
  }

  private func livenessResult(success: Bool, payload: [AnyHashable: Any]?) -> [String: Any] {
    let raw = (payload as? [String: Any]) ?? [:]
    return [
      "success": success,
      "code": (raw["code"] as? NSNumber)?.intValue ?? (success ? 0 : -1),
      "message": raw["message"] as? String ?? "",
      "image": raw["image"] as? String ?? "",
      "sequence_id": raw["sequence_id"] as? String ?? "",
      "liveness_id": raw["liveness_id"] as? String ?? "",
      "raw": raw,
    ]
  }

  private func topViewController(
    from viewController: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
  ) -> UIViewController? {
    if let navigationController = viewController as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }
    if let tabBarController = viewController as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }
    if let presentedViewController = viewController?.presentedViewController {
      return topViewController(from: presentedViewController)
    }
    return viewController
  }
}
