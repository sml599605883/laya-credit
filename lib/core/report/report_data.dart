import 'dart:convert';

import '../network/api_crypto.dart';

/// 一次定位快照。原生 `ReportRegistrar` 回传的字典与这里的 key 一一对应。
class ReportLocationSnapshot {
  const ReportLocationSnapshot({
    this.province = '',
    this.locality = '',
    this.fullAddress = '',
    this.countryCode = '',
    this.country = '',
    this.street = '',
    this.latitude = '',
    this.longitude = '',
    this.city = '',
    this.permissionStatus = '',
  });

  static const empty = ReportLocationSnapshot();

  final String province;
  final String locality;
  final String fullAddress;
  final String countryCode;
  final String country;
  final String street;
  final String latitude;
  final String longitude;
  final String city;
  final String permissionStatus;

  /// 只要经纬度 / 地址 / 城市 / 国家任意一项有值，就认为这次定位可用。
  bool get isValid =>
      latitude.isNotEmpty ||
      longitude.isNotEmpty ||
      fullAddress.isNotEmpty ||
      street.isNotEmpty ||
      city.isNotEmpty ||
      country.isNotEmpty;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'province': province,
    'locality': locality,
    'fullAddress': fullAddress,
    'countryCode': countryCode,
    'country': country,
    'street': street,
    'latitude': latitude,
    'longitude': longitude,
    'city': city,
    'permissionStatus': permissionStatus,
  };

  factory ReportLocationSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return ReportLocationSnapshot(
      province: reportText(map['province']),
      locality: reportText(map['locality'] ?? map['subAdminArea']),
      fullAddress: reportText(map['fullAddress']),
      countryCode: reportText(map['countryCode']),
      country: reportText(map['country']),
      street: reportText(map['street']),
      latitude: reportText(map['latitude']),
      longitude: reportText(map['longitude']),
      city: reportText(map['city']),
      permissionStatus: reportText(map['permissionStatus']),
    );
  }
}

/// 一次设备快照。key 与 iOS 侧 `ReportDeviceSnapshotCollector` 的输出对齐。
class ReportDeviceSnapshot {
  const ReportDeviceSnapshot({
    this.idfv = '',
    this.idfa = '',
    this.deviceId = '',
    this.riskDeviceId = '',
    this.batteryLevel = 0,
    this.isCharging = 0,
    this.elapsedMillis = 0,
    this.uptimeMillis = '0',
    this.isUsingProxy = 0,
    this.isUsingVpn = 0,
    this.isJailbroken = 0,
    this.isEmulator = 0,
    this.language = '',
    this.carrier = '',
    this.networkType = '',
    this.timeZoneName = '',
    this.cpuCoreCount = 0,
    this.board = '',
    this.brand = '',
    this.deviceName = '',
    this.model = '',
    this.modelName = '',
    this.systemVersion = '',
    this.packageName = '',
    this.screenHeight = 0,
    this.screenWidth = 0,
    this.screenSize = '',
    this.innerIp = '',
    this.currentWifiName = '',
    this.currentWifiBssid = '',
    this.wifiCount = 0,
    this.availableStorage = '0',
    this.totalStorage = '0',
    this.totalMemory = '0',
    this.availableMemory = '0',
  });

  factory ReportDeviceSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return ReportDeviceSnapshot(
      idfv: reportText(map['idfv']),
      idfa: reportText(map['idfa']),
      deviceId: reportText(map['deviceId']),
      riskDeviceId: reportText(map['riskDeviceId']),
      batteryLevel: _integer(map['batteryLevel']),
      isCharging: _integer(map['isCharging']),
      elapsedMillis: _integer(map['elapsedMillis']),
      uptimeMillis: reportText(map['uptimeMillis'], fallback: '0'),
      isUsingProxy: _integer(map['isUsingProxy']),
      isUsingVpn: _integer(map['isUsingVpn']),
      isJailbroken: _integer(map['isJailbroken']),
      isEmulator: _integer(map['isEmulator']),
      language: reportText(map['language']),
      carrier: reportText(map['carrier']),
      networkType: reportText(map['networkType']),
      timeZoneName: reportText(map['timeZoneName']),
      cpuCoreCount: _integer(map['cpuCoreCount']),
      board: reportText(map['board']),
      brand: reportText(map['brand']),
      deviceName: reportText(map['deviceName']),
      model: reportText(map['model']),
      modelName: reportText(map['modelName']),
      systemVersion: reportText(map['systemVersion']),
      packageName: reportText(map['packageName']),
      screenHeight: _integer(map['screenHeight']),
      screenWidth: _integer(map['screenWidth']),
      screenSize: reportText(map['screenSize']),
      innerIp: reportText(map['innerIp']),
      currentWifiName: reportText(map['currentWifiName']),
      currentWifiBssid: reportText(map['currentWifiBssid']),
      wifiCount: _integer(map['wifiCount']),
      availableStorage: reportText(map['availableStorage'], fallback: '0'),
      totalStorage: reportText(map['totalStorage'], fallback: '0'),
      totalMemory: reportText(map['totalMemory'], fallback: '0'),
      availableMemory: reportText(map['availableMemory'], fallback: '0'),
    );
  }

  final String idfv;
  final String idfa;
  final String deviceId;
  final String riskDeviceId;
  final int batteryLevel;
  final int isCharging;
  final int elapsedMillis;
  final String uptimeMillis;
  final int isUsingProxy;
  final int isUsingVpn;
  final int isJailbroken;
  final int isEmulator;
  final String language;
  final String carrier;
  final String networkType;
  final String timeZoneName;
  final int cpuCoreCount;
  final String board;
  final String brand;
  final String deviceName;
  final String model;
  final String modelName;
  final String systemVersion;
  final String packageName;
  final int screenHeight;
  final int screenWidth;
  final String screenSize;
  final String innerIp;
  final String currentWifiName;
  final String currentWifiBssid;
  final int wifiCount;
  final String availableStorage;
  final String totalStorage;
  final String totalMemory;
  final String availableMemory;
}

/// 拼装并加密「设备信息上报」报文（`POST /outsulk/vesperal`）。
///
/// 报文结构按接口文档 `6.data-report.html#设备信息上报详细信息` 逐字段对齐：
/// 顶层是 `deporting/hyalite/alarmable/parson/scalloper/preelectronic/
/// herculanensian/demits/heretical` 九个分组（`deceleron` 文档标注已弃用，不传）。
///
/// 字段名按接口文档的「混淆前 → 混淆后」映射（`doc-obf-data`）逐项对齐：
/// 每个分组的注释里都标了混淆前的语义名，新增 / 修改字段时以映射表为准，
/// 不要靠文档示例里的取值反推。
String encryptReportDevicePayload({
  required ReportDeviceSnapshot snapshot,
  required String deviceModel,
  required String physicalSize,
  required ReportLocationSnapshot? location,
  required int lastLoginAtMillis,
  required int nowMillis,
  required String key,
  required String iv,
}) {
  String text(Object? value, {String fallback = ''}) =>
      reportText(value, fallback: fallback);

  final payload = <String, dynamic>{
    // 顶层语义（混淆前）：os_type(deceleron，已弃用不传) / os_version(deporting) /
    // last_login_time(hyalite) / package_name(alarmable) / battery_status(parson) /
    // gps_info(scalloper) / general_data(preelectronic) / hardware(herculanensian) /
    // network(demits) / storage(heretical)。
    'deporting': text(snapshot.systemVersion),
    'hyalite': lastLoginAtMillis,
    'alarmable': text(snapshot.packageName),
    // battery_status：battery_pct(untighten) / is_charging(nonmeasurability)。
    'parson': <String, dynamic>{
      'untighten': snapshot.batteryLevel,
      'nonmeasurability': snapshot.isCharging,
    },
    // gps_info：gps_longitude(print) / gps_latitude(martite) / gps_address(stonefort) /
    // address_info(conceive) → country_name(halona)、country_code(introduction)、
    // admin_area(dsri)、locality(loud)、sub_admin_area(intertrinitarian)、
    // feature_name(warfaring)。
    'scalloper': <String, dynamic>{
      'print': text(location?.longitude),
      'martite': text(location?.latitude),
      'stonefort': text(location?.fullAddress),
      'conceive': <String, dynamic>{
        'halona': text(location?.country),
        'introduction': text(location?.countryCode),
        'dsri': text(location?.province),
        'loud': text(location?.city),
        'intertrinitarian': text(location?.locality),
        'warfaring': text(location?.street),
      },
    },
    // general_data：idfv(midshipmanship) / idfa(diamagnetism) / mac(spd) /
    // currentSystemTime(hieromachy) / elapsedRealtime(picturegoer) /
    // is_using_proxy_port(joiners) / is_using_vpn(misrepresentee) / is_root(dishmonger) /
    // is_simulator(hopeton) / language(whiteacre) / network_operator_name(insubjection) /
    // network_type(departed) / sensor_list(capanne) / time_zone_id(twineless) /
    // uptimeMillis(trebucket)。
    'preelectronic': <String, dynamic>{
      'midshipmanship': text(snapshot.idfv),
      'diamagnetism': text(snapshot.idfa),
      'spd': text(snapshot.currentWifiBssid),
      'hieromachy': nowMillis,
      'picturegoer': text(snapshot.uptimeMillis, fallback: '0'),
      'joiners': snapshot.isUsingProxy,
      'misrepresentee': snapshot.isUsingVpn,
      'dishmonger': snapshot.isJailbroken,
      'hopeton': snapshot.isEmulator,
      'whiteacre': text(snapshot.language),
      'insubjection': text(snapshot.carrier),
      'departed': text(snapshot.networkType),
      'capanne': const <dynamic>[],
      'twineless': text(snapshot.timeZoneName),
      'trebucket': snapshot.elapsedMillis,
    },
    // hardware：混淆前 → 混淆后
    // board → amativeness、brand → hammer、cores → sluttish、
    // device_height → paedatrophy、device_name → compensatingly、
    // device_width → polyhistor、model → chlor、physical_size → squattest、
    // release → unforbidden。
    'herculanensian': <String, dynamic>{
      'amativeness': text(snapshot.board),
      'hammer': text(snapshot.brand),
      'sluttish': snapshot.cpuCoreCount,
      'paedatrophy': snapshot.screenHeight,
      'compensatingly': text(snapshot.deviceName),
      'polyhistor': snapshot.screenWidth,
      'chlor': text(deviceModel),
      'squattest': text(physicalSize),
      'unforbidden': text(snapshot.systemVersion),
    },
    // network：ip(maid) / configured_wifi(between) / current_wifi(trowable) /
    // wifi_count(allmouths)；wifi 项 bssid(pseudoaesthetically) / ssid(microzyme)。
    'demits': <String, dynamic>{
      'maid': text(snapshot.innerIp),
      'between': <dynamic>[
        <String, dynamic>{
          'harbingers': text(snapshot.currentWifiName),
          'pseudoaesthetically': text(snapshot.currentWifiBssid),
          'spd': text(snapshot.currentWifiBssid),
          'microzyme': text(snapshot.currentWifiName),
        },
      ],
      'trowable': <String, dynamic>{
        'harbingers': text(snapshot.currentWifiName),
        'pseudoaesthetically': text(snapshot.currentWifiBssid),
        'spd': text(snapshot.currentWifiBssid),
        'microzyme': text(snapshot.currentWifiName),
      },
      'allmouths': snapshot.wifiCount,
    },
    // storage：internal_storage_usable(unsnobbish) / internal_storage_total(ez) /
    // ram_total_size(ge) / ram_usable_size(semmes)。
    'heretical': <String, dynamic>{
      'unsnobbish': text(snapshot.availableStorage, fallback: '0'),
      'ez': text(snapshot.totalStorage, fallback: '0'),
      'ge': text(snapshot.totalMemory, fallback: '0'),
      'semmes': text(snapshot.availableMemory, fallback: '0'),
    },
  };
  return ApiCrypto(key: key, iv: iv).encryptText(jsonEncode(payload));
}

/// 归一化上报文本：`null` / 空串 / 字面量 `"null"` 都回落到 [fallback]。
String reportText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
