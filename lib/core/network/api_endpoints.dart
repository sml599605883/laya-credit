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

  /// banner 点击记录上报。POST
  static const bannerClick = '/outsulk/gaile';

  /// 点击申请（产品准入）。POST
  static const productApply = '/outsulk/weaken';

  /// 产品详情（准入成功后拉取认证项 / 下一步）。POST
  static const productDetail = '/outsulk/inconstruable';

  /// 跟进订单号获取跳转地址（认证完成后进借款确认页）。POST
  static const productPush = '/outsulk/octodentate';

  /// 获取用户身份信息（认证第一项）：证件类型列表。GET
  static const identityInfo = '/outsulk/gaonate';

  /// 上传证件图片 / 活体照片（multipart。第一项）。POST
  static const uploadIdentityImage = '/outsulk/fashioned';

  /// 获取 face++ token / 活体检测授权码（认证第二项）。POST
  static const faceToken = '/outsulk/carline';

  /// 保存识别出的身份证信息（认证第一项）。POST
  static const saveIdentityInfo = '/outsulk/wardmote';

  /// 获取用户信息（认证第二项）：个人信息表单字段描述。POST
  static const personalInfo = '/outsulk/orchel';

  /// 保存用户信息（认证第二项）。POST
  static const savePersonalInfo = '/outsulk/marantas';

  /// 获取工作信息（认证第三项）：工作信息表单字段描述。GET
  static const workInfo = '/outsulk/timeling';

  /// 保存工作信息（认证第三项）。POST
  static const saveWorkInfo = '/outsulk/kneeing';

  /// 地址初始化：地址层级（省 / 市 / 区）。GET
  static const addressInit = '/outsulk/avern';
}
