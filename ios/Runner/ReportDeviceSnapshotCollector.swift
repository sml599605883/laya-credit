import CoreTelephony
import Darwin
import Foundation
import NetworkExtension
import SystemConfiguration
import SystemConfiguration.CaptiveNetwork
import UIKit

private struct ReportWifiSnapshot {
  let name: String
  let bssid: String
  let count: Int

  static let empty = ReportWifiSnapshot(name: "", bssid: "", count: 0)
}

private struct ReportInterfaceRecord {
  let name: String
  let family: Int32
  let address: String
}

final class ReportDeviceSnapshotCollector {
  private let telephony = CTTelephonyNetworkInfo()

  func collect(
    idfv: String,
    idfa: String,
    isUsingProxy: Bool,
    modelIdentifier: String,
    completion: @escaping ([String: Any]) -> Void
  ) {
    collectWifi { [self] wifi in
      UIDevice.current.isBatteryMonitoringEnabled = true
      let batteryLevel =
        UIDevice.current.batteryLevel < 0
        ? 0
        : Int(UIDevice.current.batteryLevel * 100)
      let batteryState = UIDevice.current.batteryState
      UIDevice.current.isBatteryMonitoringEnabled = false

      let isCharging = batteryState == .charging || batteryState == .full
      let bounds = UIScreen.main.bounds
      let fileAttributes = try? FileManager.default.attributesOfFileSystem(
        forPath: NSHomeDirectory()
      )
      let totalStorage =
        (fileAttributes?[.systemSize] as? NSNumber)?.stringValue ?? "0"
      let availableStorage =
        (fileAttributes?[.systemFreeSize] as? NSNumber)?.stringValue ?? "0"
      let interfaces = activeInterfaces()
      let uptime = Int(ProcessInfo.processInfo.systemUptime * 1000)

      completion([
        "idfv": idfv,
        "idfa": idfa,
        "deviceId": idfv,
        "riskDeviceId": idfv,
        "batteryLevel": batteryLevel,
        "isCharging": isCharging ? 1 : 0,
        "elapsedMillis": uptime,
        "uptimeMillis": String(uptime),
        "isUsingProxy": isUsingProxy ? 1 : 0,
        "isUsingVpn": isUsingVpn() ? 1 : 0,
        "isJailbroken": isJailbroken() ? 1 : 0,
        "isEmulator": isSimulator() ? 1 : 0,
        "language": Locale.current.languageCode ?? "",
        "carrier": currentCarrierName(),
        "networkType": currentNetworkType(),
        "timeZoneName": gmtTimeZone(),
        "cpuCoreCount": ProcessInfo.processInfo.processorCount,
        "board": boardIdentifier(),
        "brand": "iPhone",
        "deviceName": UIDevice.current.name,
        "model": modelIdentifier,
        "modelName": UIDevice.current.model,
        "systemVersion": UIDevice.current.systemVersion,
        "packageName": Bundle.main.bundleIdentifier ?? "",
        "screenHeight": Int(bounds.height),
        "screenWidth": Int(bounds.width),
        "screenSize": "",
        "innerIp": preferredInnerIp(from: interfaces),
        "currentWifiName": wifi.name,
        "currentWifiBssid": wifi.bssid,
        "wifiCount": wifi.count,
        "availableStorage": availableStorage,
        "totalStorage": totalStorage,
        "totalMemory": String(ProcessInfo.processInfo.physicalMemory),
        "availableMemory": String(availableMemoryBytes()),
      ])
    }
  }

  private func collectWifi(completion: @escaping (ReportWifiSnapshot) -> Void) {
    if #available(iOS 26.0, *) {
      NEHotspotNetwork.fetchCurrent { network in
        let snapshot =
          network.map {
            ReportWifiSnapshot(name: $0.ssid, bssid: $0.bssid, count: 1)
          } ?? .empty
        DispatchQueue.main.async { completion(snapshot) }
      }
      return
    }

    DispatchQueue.global(qos: .utility).async {
      let networks = (CNCopySupportedInterfaces() as? [String] ?? []).compactMap {
        interface -> ReportWifiSnapshot? in
        guard
          let info = CNCopyCurrentNetworkInfo(interface as CFString)
            as? [String: Any]
        else {
          return nil
        }
        return ReportWifiSnapshot(
          name: info[kCNNetworkInfoKeySSID as String] as? String ?? "",
          bssid: info[kCNNetworkInfoKeyBSSID as String] as? String ?? "",
          count: 1
        )
      }
      let first = networks.first ?? .empty
      let snapshot = ReportWifiSnapshot(
        name: first.name,
        bssid: first.bssid,
        count: networks.count
      )
      DispatchQueue.main.async { completion(snapshot) }
    }
  }

  private func currentCarrierName() -> String {
    if let providers = telephony.serviceSubscriberCellularProviders {
      for key in providers.keys.sorted() {
        let name =
          providers[key]?.carrierName?.trimmingCharacters(
            in: .whitespacesAndNewlines
          ) ?? ""
        if !name.isEmpty { return name }
      }
    }
    return telephony.subscriberCellularProvider?.carrierName ?? ""
  }

  private func currentNetworkType() -> String {
    guard let flags = reachabilityFlags(), flags.contains(.reachable) else {
      return "OTHER"
    }
    guard flags.contains(.isWWAN) else { return "WIFI" }
    return cellularGeneration()
  }

  private func reachabilityFlags() -> SCNetworkReachabilityFlags? {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    let reachability = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        SCNetworkReachabilityCreateWithAddress(nil, $0)
      }
    }
    guard let reachability else { return nil }
    var flags = SCNetworkReachabilityFlags()
    return SCNetworkReachabilityGetFlags(reachability, &flags) ? flags : nil
  }

  private func cellularGeneration() -> String {
    let technologies = telephony.serviceCurrentRadioAccessTechnology ?? [:]
    let technology =
      technologies.keys.sorted().compactMap {
        technologies[$0]
      }.first ?? telephony.currentRadioAccessTechnology

    switch technology {
    case CTRadioAccessTechnologyGPRS,
      CTRadioAccessTechnologyEdge,
      CTRadioAccessTechnologyCDMA1x:
      return "2G"
    case CTRadioAccessTechnologyWCDMA,
      CTRadioAccessTechnologyHSDPA,
      CTRadioAccessTechnologyHSUPA,
      CTRadioAccessTechnologyCDMAEVDORev0,
      CTRadioAccessTechnologyCDMAEVDORevA,
      CTRadioAccessTechnologyCDMAEVDORevB,
      CTRadioAccessTechnologyeHRPD:
      return "3G"
    case CTRadioAccessTechnologyLTE:
      return "4G"
    case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
      return "5G"
    default:
      return "OTHER"
    }
  }

  private func activeInterfaces() -> [ReportInterfaceRecord] {
    var pointer: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
    defer { freeifaddrs(pointer) }

    var records: [ReportInterfaceRecord] = []
    for item in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let interface = item.pointee
      let flags = Int32(interface.ifa_flags)
      guard flags & IFF_UP != 0,
        flags & IFF_RUNNING != 0,
        flags & IFF_LOOPBACK == 0,
        let socketAddress = interface.ifa_addr
      else {
        continue
      }
      let family = Int32(socketAddress.pointee.sa_family)
      guard family == AF_INET || family == AF_INET6 else { continue }

      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let length =
        family == AF_INET
        ? socklen_t(MemoryLayout<sockaddr_in>.size)
        : socklen_t(MemoryLayout<sockaddr_in6>.size)
      guard
        getnameinfo(
          socketAddress,
          length,
          &host,
          socklen_t(host.count),
          nil,
          0,
          NI_NUMERICHOST
        ) == 0
      else {
        continue
      }
      let value = String(cString: host)
      if value.isEmpty || value == "127.0.0.1" || value == "::1" { continue }
      records.append(
        ReportInterfaceRecord(
          name: String(cString: interface.ifa_name),
          family: family,
          address: value
        )
      )
    }
    return records
  }

  private func isUsingVpn() -> Bool {
    guard
      let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
        as? [String: Any],
      let scoped = settings["__SCOPED__"] as? [String: Any]
    else {
      return false
    }
    let markers = ["tap", "tun", "ppp", "ipsec", "utun"]
    return scoped.keys.contains { key in
      let name = key.lowercased()
      return markers.contains { name.contains($0) }
    }
  }

  private func gmtTimeZone() -> String {
    let offset = TimeZone.current.secondsFromGMT()
    guard offset != 0 else { return "GMT" }

    let sign = offset >= 0 ? "+" : "-"
    let totalMinutes = abs(offset) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    guard minutes != 0 else { return "GMT\(sign)\(hours)" }
    return String(format: "GMT%@%d:%02d", sign, hours, minutes)
  }

  private func preferredInnerIp(from interfaces: [ReportInterfaceRecord]) -> String {
    let priorities: [(String, Int32)] = [
      ("en0", AF_INET),
      ("pdp_ip0", AF_INET),
      ("en0", AF_INET6),
      ("pdp_ip0", AF_INET6),
    ]
    for (name, family) in priorities {
      if let record = interfaces.first(where: {
        $0.name == name && $0.family == family
      }) {
        return record.address
      }
    }
    return ""
  }

  private func availableMemoryBytes() -> UInt64 {
    var pageSize: vm_size_t = 0
    guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
      return 0
    }
    var statistics = vm_statistics64()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.size
        / MemoryLayout<integer_t>.size
    )
    let status = withUnsafeMutablePointer(to: &statistics) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
      }
    }
    guard status == KERN_SUCCESS else { return 0 }
    return UInt64(statistics.free_count + statistics.inactive_count)
      * UInt64(pageSize)
  }

  /// 硬件 board（`hw.model`，如 `D79AP`）。设备报文里映射为 `amativeness`。
  private func boardIdentifier() -> String {
    var size = 0
    guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
      return ""
    }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else {
      return ""
    }
    return String(cString: buffer)
  }

  private func isSimulator() -> Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }

  private func isJailbroken() -> Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      let paths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt",
      ]
      if paths.contains(where: FileManager.default.fileExists(atPath:)) {
        return true
      }
      if getenv("DYLD_INSERT_LIBRARIES") != nil { return true }

      let probe = "/private/dali-device-\(UUID().uuidString)"
      do {
        try "probe".write(toFile: probe, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: probe)
        return true
      } catch {
        return false
      }
    #endif
  }
}
