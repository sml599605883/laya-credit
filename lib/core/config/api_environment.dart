/// 后端接入参数。
///
/// 来源：蓝湖接口文档 `ph_laya_credit_ios`（aesKey / iv / verifySecretKey 由
/// `api_doc_get_decode_config` 下发），测试环境地址由后端口头提供。
///
/// ⚠️ 注意：测试环境是 **IP + 明文 HTTP**（该地址没有 HTTPS 监听），
/// iOS 的 ATS 会拦截明文请求，`ios/Runner/Info.plist` 里为此开了放行开关，
/// 发布前必须换成 HTTPS 生产域名并删掉那个开关。
/// QA 也可以用 `runtimeApiBaseProvider` 在运行时临时覆盖，不必改这里重新打包。
abstract final class ApiEnvironment {
  /// 接口根地址（必须以 / 结尾）。
  ///
  /// 测试环境：`http://8.220.190.152/whole/`。
  static const apiBase = 'http://8.220.190.152/whole/';

  /// H5 站点根地址（协议页、客服、订单详情等 WebView 页面使用）。
  static const h5Base = 'http://8.220.190.152';

  /// 请求签名密钥（verifySecretKey）。
  static const signSecret = 'b5e0041bb7ff77e115fb995f756e6c2b';

  /// 渠道标识，用于后端区分 App。文档要求传 `appstore-ph-laya-credit-ios`。
  static const marketIdentifier = 'appstore-ph-laya-credit-ios';

  /// 报文字段加密用的 AES 密钥与 IV（数据上报等少数接口会用到）。
  static const aesKey = '27f7dd9897297dbd';
  static const aesIv = '9feade03e8f337e2';
}
