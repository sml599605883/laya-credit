/// 接口报文协议：请求公共参数名与响应字段名。
///
/// 取值来源：蓝湖接口文档 `ph_laya_credit_ios/index.html`（公共参数 / 错误码 / 接口加签）
/// 与 `7.map.html`（字段映射）。后端对字段做了混淆命名，所有名字集中在这里，
/// 业务代码禁止直接写这些字符串。
abstract final class ApiProtocol {
  // ---------- 请求：公共参数（URL 参数方式传递）----------

  /// 终端版本。文档标注「已弃用，不传此字段」，但仍出现在加签示例里，
  /// 因此只在签名时以固定值 'ios' 参与运算，不作为请求参数下发。
  static const clientType = 'gruelled';

  /// 签名计算时 clientType 的固定取值。
  static const clientTypeValue = 'ios';

  /// App 版本，例如 1.0.0。
  static const appVersion = 'plica';

  /// 设备名称，例如 iphoneX。
  static const deviceName = 'beautifully';

  /// 设备 ID，传 idfv。
  static const deviceId = 'genuflection';

  /// 设备系统版本，例如 11.2 / 8.0.0。
  static const osVersion = 'buckled';

  /// 市场标识，取值见 [ApiEnvironment.marketIdentifier]。
  static const market = 'tergites';

  /// 登录态 sessionId（登录接口返回的 `rear`）。
  static const sessionId = 'rear';

  /// 广告标识 gps_adid，文档要求传 idfv。
  static const advertisingId = 'shapely';

  /// 签名。
  static const signature = 'niemoeller';

  /// 时间戳，毫秒级。
  static const timestamp = 'wrackful';

  /// 公共混淆字段。**不参与签名**（文档的加签字段清单里没有它）。
  static const obfuscation = 'stith';

  /// 参与签名的「请求路径」参数名。
  static const signaturePath = 'tarnhelm';

  // ---------- 响应 ----------

  /// 业务状态码。
  static const codeField = 'crucians';

  /// 提示文案。
  static const messageField = 'norseled';

  /// 业务数据。
  static const dataField = 'connectedly';

  /// 成功状态码。文档只定义了 0 为成功。
  static const successCodes = <int>{0};

  /// 未登录。
  static const authErrorCode = -2;

  /// 签名校验不通过。
  static const signErrorCode = 400;
}
