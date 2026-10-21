import AdSupport
import AppTrackingTransparency
import CFNetwork
import Contacts
import CoreLocation
import Flutter
import Security
import UIKit

/// 数据上报采集项的原生桥。
///
/// - method channel `laya_credit/report`：`getReportLocation` /
///   `requestLocationPermission` / `getReportDeviceSnapshot` /
///   `getTrackingStatus` / `requestTrackingAuthorization`。
///
/// 与推送（`laya_credit/push`）、评分（`laya_credit/app_review`）、风控活体
/// （`laya_credit/client_bridge`）分开，避免把定位 / 设备采集混进其它通道。
/// 推送 token 由 `PushNotificationRegistrar` 负责，不在这里重复。
final class ReportRegistrar:
  NSObject,
  CLLocationManagerDelegate,
  FlutterStreamHandler
{
  static let shared = ReportRegistrar()

  private static let channelName = "laya_credit/report"
  private static let eventChannelName = "laya_credit/report_events"

  private let deviceSnapshotCollector = ReportDeviceSnapshotCollector()
  private var locationManager: CLLocationManager?
  private var locationResult: FlutterResult?
  private var locationPermissionManager: CLLocationManager?
  private var locationPermissionResult: FlutterResult?
  private var eventSink: FlutterEventSink?

  private override init() {
    super.init()
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
      case "getReportLocation":
        self.getReportLocation(result)
      case "requestLocationPermission":
        self.requestLocationPermission(result)
      case "getReportDeviceSnapshot":
        self.deviceSnapshotCollector.collect(
          idfv: self.stableVendorIdentifier(),
          idfa: self.currentAdvertisingIdentifier(),
          isUsingProxy: (self.currentProxySettings()["enabled"] as? Bool) == true,
          modelIdentifier: self.deviceModelName(),
          completion: { snapshot in result(snapshot) }
        )
      case "getStableDeviceId":
        result(self.stableVendorIdentifier())
      case "getTrackingStatus":
        result(self.trackingStatus())
      case "requestTrackingAuthorization":
        self.requestTrackingAuthorization(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let eventChannel = FlutterEventChannel(
      name: Self.eventChannelName,
      binaryMessenger: binaryMessenger
    )
    eventChannel.setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    publishTrackingStatus()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  /// ATT 决策完成或 App 重新激活时主动推送当前状态，避免 Flutter 侧在
  /// `requestTrackingAuthorization` 返回后的瞬间读到尚未稳定的值。
  func publishTrackingStatus() {
    eventSink?([
      "type": "tracking_status_changed",
      "status": trackingStatus(),
    ])
  }

  // MARK: - 定位

  private func getReportLocation(_ result: @escaping FlutterResult) {
    guard locationResult == nil else {
      result(FlutterError(
        code: "location_in_progress",
        message: "A location request is already in progress",
        details: nil
      ))
      return
    }
    guard CLLocationManager.locationServicesEnabled() else {
      result(locationPayload(location: nil, placemark: nil, status: "service_disabled"))
      return
    }

    let manager = CLLocationManager()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager = manager
    locationResult = result
    // 只读当前定位，不在上报路径里弹权限：授权时机对齐 dali——由「点击申请」
    // 时显式调用 `requestLocationPermission`，未授权 / 未决定都直接回状态。
    let status = manager.authorizationStatus
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      manager.requestLocation()
    } else {
      finishLocation(locationPayload(location: nil, placemark: nil, status: locationStatus(status)))
    }
  }

  private func requestLocationPermission(_ result: @escaping FlutterResult) {
    guard CLLocationManager.locationServicesEnabled() else {
      result("service_disabled")
      return
    }
    let manager = CLLocationManager()
    manager.delegate = self
    if let previousResult = locationPermissionResult {
      locationPermissionResult = nil
      locationPermissionManager = nil
      previousResult("interrupted")
    }
    locationPermissionManager = manager
    locationPermissionResult = result
    let status = manager.authorizationStatus
    guard status == .notDetermined else {
      locationPermissionManager = nil
      locationPermissionResult = nil
      result(locationStatus(status))
      return
    }
    manager.requestWhenInUseAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager === locationPermissionManager {
      let status = manager.authorizationStatus
      guard status != .notDetermined else { return }
      let result = locationPermissionResult
      locationPermissionResult = nil
      locationPermissionManager = nil
      result?(locationStatus(status))
      return
    }
    guard locationResult != nil else { return }
    let status = manager.authorizationStatus
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      manager.requestLocation()
    } else if status == .denied || status == .restricted {
      finishLocation(locationPayload(location: nil, placemark: nil, status: locationStatus(status)))
    }
  }

  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.last else {
      finishLocation(locationPayload(location: nil, placemark: nil, status: locationStatus(manager.authorizationStatus)))
      return
    }
    CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
      guard let self else { return }
      self.finishLocation(self.locationPayload(
        location: location,
        placemark: placemarks?.first,
        status: self.locationStatus(manager.authorizationStatus)
      ))
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finishLocation(locationPayload(location: nil, placemark: nil, status: locationStatus(manager.authorizationStatus)))
  }

  private func finishLocation(_ payload: [String: Any]) {
    let result = locationResult
    locationResult = nil
    locationManager?.stopUpdatingLocation()
    locationManager = nil
    result?(payload)
  }

  private func locationPayload(
    location: CLLocation?,
    placemark: CLPlacemark?,
    status: String
  ) -> [String: Any] {
    return [
      "province": placemark?.administrativeArea ?? "",
      "locality": placemark?.subAdministrativeArea ?? "",
      "fullAddress": fullAddress(from: placemark),
      "countryCode": placemark?.isoCountryCode ?? "",
      "country": placemark?.country ?? "",
      "street": street(from: placemark),
      "latitude": location.map { String($0.coordinate.latitude) } ?? "",
      "longitude": location.map { String($0.coordinate.longitude) } ?? "",
      "city": placemark?.locality ?? placemark?.subAdministrativeArea ?? "",
      "permissionStatus": status
    ]
  }

  private func street(from placemark: CLPlacemark?) -> String {
    guard let placemark else { return "" }
    return placemark.postalAddress?.street
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private func fullAddress(from placemark: CLPlacemark?) -> String {
    guard let placemark else { return "" }
    let streetNumber = [placemark.thoroughfare, placemark.subThoroughfare]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    let parts = [
      placemark.country,
      placemark.administrativeArea,
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.subLocality,
      streetNumber
    ]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    return uniqueAddressParts(parts).joined(separator: " ")
  }

  private func uniqueAddressParts(_ parts: [String]) -> [String] {
    var seen = Set<String>()
    return parts.filter { seen.insert($0).inserted }
  }

  private func locationStatus(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways: return "authorized_always"
    case .authorizedWhenInUse: return "authorized_when_in_use"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "not_determined"
    @unknown default: return "unknown"
    }
  }

  // MARK: - 跟踪授权（ATT）

  private func trackingStatus() -> String {
    guard #available(iOS 14, *) else { return "not_supported" }
    switch ATTrackingManager.trackingAuthorizationStatus {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "not_determined"
    @unknown default: return "unknown"
    }
  }

  private func requestTrackingAuthorization(_ result: @escaping FlutterResult) {
    guard #available(iOS 14, *) else {
      result("not_supported")
      return
    }
    if ATTrackingManager.trackingAuthorizationStatus != .notDetermined {
      let status = trackingStatus()
      result(status)
      publishTrackingStatus()
      return
    }
    ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
      DispatchQueue.main.async {
        guard let self else {
          result("unknown")
          return
        }
        let status = self.trackingStatus()
        result(status)
        self.publishTrackingStatus()
      }
    }
  }

  private func currentAdvertisingIdentifier() -> String {
    if #available(iOS 14, *), ATTrackingManager.trackingAuthorizationStatus == .authorized {
      let identifier = ASIdentifierManager.shared().advertisingIdentifier.uuidString
      return identifier == "00000000-0000-0000-0000-000000000000" ? "" : identifier
    }
    return ""
  }

  // MARK: - 设备标识 / 代理

  private func currentProxySettings() -> [String: Any] {
    guard
      let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
        as? [String: Any]
    else {
      return ["enabled": false, "host": "", "port": 0]
    }

    let enabled =
      (settings[kCFNetworkProxiesHTTPEnable as String] as? NSNumber)?.boolValue
      ?? false
    let host = settings[kCFNetworkProxiesHTTPProxy as String] as? String ?? ""
    let port =
      (settings[kCFNetworkProxiesHTTPPort as String] as? NSNumber)?.intValue
      ?? 0
    guard enabled, !host.isEmpty, port > 0 else {
      return ["enabled": false, "host": "", "port": 0]
    }
    return ["enabled": true, "host": host, "port": port]
  }

  /// 设备 ID 优先读取 Keychain，首次安装时才用当前 IDFV 初始化。
  ///
  /// Flutter 公共参数 `genuflection` / `shapely` 也通过 `getStableDeviceId`
  /// 读取同一个值，保证卸载重装后设备报文与公参保持一致。
  private func stableVendorIdentifier() -> String {
    let service = "laya_credit.report"
    let account = "stable_idfv"
    if let stored = keychainValue(service: service, account: account),
       !stored.isEmpty {
      return stored
    }

    let identifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
    if !identifier.isEmpty {
      saveKeychainValue(identifier, service: service, account: account)
    }
    return identifier
  }

  private func deviceModelName() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let identifier = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0) ?? ""
      }
    }
    return identifier.isEmpty ? UIDevice.current.model : identifier
  }

  private func keychainValue(service: String, account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private func saveKeychainValue(_ value: String, service: String, account: String) {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      SecItemAdd(item as CFDictionary, nil)
    }
  }
}
