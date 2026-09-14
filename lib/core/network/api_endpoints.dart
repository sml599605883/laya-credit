/// 接口路径。来源：接口文档的路径映射表（`api_doc_get_map` / type=url）。
///
/// 左边是后端原始语义路径，右边是线上实际下发的混淆路径。
abstract final class ApiEndpoints {
  /// 获取登录/注册短信验证码。POST
  static const sendSmsCode = '/outsulk/acarology';

  /// 获取支持的验证码发送渠道（首次发送失败后换渠道）。POST
  static const smsChannels = '/outsulk/tectites';

  /// 验证码登录/注册。POST
  static const smsLogin = '/outsulk/chlorpikrin';

  /// 退出登录。GET
  static const logout = '/outsulk/crucians';

  /// APP 首页。GET
  static const homePage = '/outsulk/connectedly';

  /// 个人中心。GET
  static const personalCenter = '/outsulk/interoscillate';

  /// banner 点击记录上报。POST
  static const bannerClick = '/outsulk/gaile';
}
