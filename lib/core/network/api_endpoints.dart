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

  /// 注销账号。GET
  static const deleteAccount = '/outsulk/norseled';

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

  /// 重新授信（等待授信 loading 页轮询）。GET
  ///
  /// 准入接口返回「重新授信」时跳转到 `IntervesicularSauder` 原生页，
  /// 页面按固定间隔轮询本接口；`connectedly.countercharged` 为 `1` 表示授信完成，
  /// `2` 表示暂无结果（继续轮询）。文档语义路径 `/v3/product/re-credit`。
  static const recredit = '/outsulk/phantom';

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

  /// 获取联系人信息（认证第四项）。GET
  static const emergencyContacts = '/outsulk/liquidators';

  /// 保存联系人信息（认证第四项）。POST
  static const saveEmergencyContacts = '/outsulk/stabiliment';

  /// 获取绑卡信息（认证第五项）：打款渠道分组与字段描述。GET
  static const bindCardInfo = '/outsulk/cussedly';

  /// 提交绑卡（认证第五项）。POST
  static const submitBindCard = '/outsulk/superidealness';

  /// 用户账户列表（借款确认页的可选收款账户）。POST
  ///
  /// 返回按打款方式分组的账户（Bank / E-wallet / Cash Pickup）。
  static const userAccounts = '/outsulk/heartfelt';

  /// 更换银行卡（借款确认页提交选中的收款账户）。POST
  ///
  /// 返回订单详情页地址，由调用方决定用 WebView 还是原生页打开。
  static const changeBankCard = '/outsulk/bathtubs';

  /// 原卡重试确认订单（订单详情 H5 的「原卡重试」按钮）。POST
  ///
  /// 入参只有订单号，返回订单详情页地址，由调用方在当前 WebView 里打开。
  static const orderRetryConfirm = '/outsulk/resex';

  /// 订单列表。POST
  static const orderList = '/outsulk/gundy';

  // ---------- 数据上报（接口文档 `6.data-report.html` / `4.certify.html#同盾report`）----------
  //
  // 说明：文档里同一组「数据上报」还包含 `上报通讯录`（`/outsulk/kailua`），
  // 本项目不上报通讯录，因此**不接入**该接口，这里也不登记对应路径。

  /// 上报位置信息。POST
  ///
  /// 登录且拿到定位授权后上报；字段见 [ApiFields] 的「设备上报 - 位置」段。
  static const reportLocation = '/outsulk/solomon';

  /// google_market 上报（返回 adjust_token）。POST
  static const reportGoogleMarket = '/outsulk/antibilious';

  /// 上报风控埋点（新）。POST
  ///
  /// 场景类型见文档 `6.data-report.html`：1 注册 / 2 认证选择 / 3 证件信息 /
  /// 4 人脸照片 / 5 个人信息 / 6 工作信息 / 7 紧急联系人 / 8 银行卡信息 /
  /// 9 开始申贷 / 10 结束申贷。
  static const reportRisk = '/outsulk/mesometral';

  /// 设备信息上报（报文需 AES 加密后放在 `connectedly`）。POST
  static const reportDeviceInfo = '/outsulk/vesperal';

  /// 上报 Apple 推送 token。POST
  static const reportApplePushToken = '/outsulk/tightens';

  /// 同盾（TrustDecision）活体结果上报。POST
  static const reportTrustDecision = '/outsulk/wastefulnesses';

  /// 根据设备标识符查询 iOS 设备信息。POST
  ///
  /// 入参是设备型号标识（如 `iPhone11,8`），返回设备名称与物理尺寸，
  /// 供设备信息上报报文里的 `chlor` / `squattest` 使用。
  static const deviceInfoLookup = '/outsulk/omphacy';
}
