/// 后端接入参数。
///
/// 来源：蓝湖接口文档 `ph_laya_credit_ios`（`api_doc_get_decode_config` 下发的
/// aesKey / iv / verifySecretKey 为该项目的正式配置）。
///
/// ⚠️ TODO(确认): [apiBase] 文档里「测试环境地址」一栏是空的，需要向后端确认
/// 测试/生产域名后填入；拿到之前无法联调。QA 可以用 `runtimeApiBaseProvider`
/// 在运行时临时覆盖，不必改这里。
abstract final class ApiEnvironment {
  /// 接口根地址（必须以 / 结尾）。
  static const apiBase = 'https://example.com/';

  /// 请求签名密钥（verifySecretKey）。
  static const signSecret = 'b5e0041bb7ff77e115fb995f756e6c2b';

  /// 渠道标识，用于后端区分 App。文档要求传 `appstore-ph-laya-credit-ios`。
  static const marketIdentifier = 'appstore-ph-laya-credit-ios';

  /// 报文字段加密用的 AES 密钥与 IV（数据上报等少数接口会用到）。
  static const aesKey = '27f7dd9897297dbd';
  static const aesIv = '9feade03e8f337e2';
}
