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
  /// 只有这些结果码才算活体通过；其余（含 successBlock 携带的错误码）一律按失败处理。
  private static let acceptedLivenessCodes: Set<Int> = [0]
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
      result(makeLivenessReply(payload: nil))
      return
    }

    // successBlock / failBlock 仅表示「回调到达」，是否通过一律由 payload 的 code 决定：
    // successBlock 里同样会带非 0 的错误码，不能按其回调类型下结论。
    let reply: ([AnyHashable: Any]?) -> Void = { [self] payload in
      result(makeLivenessReply(payload: payload))
    }
    manager?.pointee.showLivenessWithShowStyle(
      viewController,
      license,
      TDLivenessShowStylePresent,
      reply,
      reply
    )
  }

  private func makeLivenessReply(payload: [AnyHashable: Any]?) -> [String: Any] {
    let raw = (payload as? [String: Any]) ?? [:]
    let code = Self.livenessCode(in: raw)
    return [
      "success": Self.acceptedLivenessCodes.contains(code),
      "code": code,
      "message": raw["message"] as? String ?? "",
      "image": raw["image"] as? String ?? "",
      "sequence_id": raw["sequence_id"] as? String ?? "",
      "liveness_id": raw["liveness_id"] as? String ?? "",
      "raw": raw,
    ]
  }

  /// 读取 SDK 回传的结果码，兼容数值与字符串两种形态；缺失或无法解析时按失败（-1）处理。
  private static func livenessCode(in payload: [String: Any]) -> Int {
    switch payload["code"] {
    case let number as NSNumber:
      return number.intValue
    case let text as String:
      return Int(text) ?? -1
    default:
      return -1
    }
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
