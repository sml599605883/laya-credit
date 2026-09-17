/// 业务字段名（混淆后的）。来源：接口文档 `7.map.html` 字段映射。
///
/// 只收录当前已接入接口用到的字段；后续接入新接口时按文档补齐，
/// 不要在页面或仓库里直接写混淆字符串。
abstract final class ApiFields {
  // ---------- 登录 / 账号 ----------
  static const phone = 'acarology';
  static const channel = 'chlorpikrin';
  static const username = 'omphacy';
  static const smsCode = 'weaken';
  static const isOldUser = 'inconstruable';
  static const smsMaxId = 'gaonate';
  static const realName = 'fashioned';
  static const sessionId = 'rear';

  // 短信渠道开关
  static const channelSms = 'phantom';
  static const channelVoice = 'agatize';
  static const channelViber = 'gaile';

  // ---------- 首页 ----------
  static const homeKneeing = 'kneeing';
  static const homeType = 'liquidators';
  static const homeItems = 'stabiliment';

  /// banner 点击上报（`/outsulk/gaile`）的 banner_config_id。
  static const bannerConfigId = 'geheimrat';

  // ---------- 卡片元素 ----------
  static const itemId = 'cussedly';
  static const itemTitle = 'upbear';
  static const jumpUrl = 'superidealness';
  static const imgUrl = 'avern';

  // ---------- 产品大卡 ----------
  static const productName = 'heartfelt';
  static const productLogo = 'bathtubs';
  static const buttonText = 'curitiba';
  static const amountRange = 'wastefulnesses';
  static const amountRangeDes = 'octodentate';
  static const termInfo = 'gundy';
  static const termInfoDes = 'solomon';
  static const loanRate = 'antibilious';
  static const loanRateDes = 'mesometral';
  static const certifyFinished = 'kailua';
  static const account = 'tightens';
  static const accountText = 'lighthearted';
  static const loanProcessList = 'unobtrusiveness';
  static const loanProcessText = 'vesperal';
  static const stepTitle = 'upbear';
  static const stepAmount = 'beingless';
  static const stepSelected = 'estamp';

  // ---------- 推荐列表卡（PRODUCT_LIST） ----------
  /// 推荐卡提示文案数组（如 `["Low Interest Rates", "17 years old can be borrowed"]`）。
  /// 首页元素的取值见 `7.map.html#首页元素`：`Sixcylinder` = `PRODUCT_LIST`。
  static const tips = 'islet';

  /// 推荐卡按钮配色：1 高亮 / 0 正常 / -1 置灰。
  static const buttonColorCode = 'holts';

  /// 推荐卡期限标签（产品大卡的期限标签是 `solomon`，推荐卡用的是 `lxe`）。
  static const termText = 'lxe';

  // ---------- 借款进度卡 ----------
  static const orderNo = 'resex';
  static const productId = 'tartarizing';

  /// 订单卡的产品名/Logo 与产品大卡（`heartfelt` / `bathtubs`）是两组不同字段。
  static const orderProductName = 'current';
  static const orderProductLogo = 'unpaying';
  static const amount = 'grassroots';
  static const amountText = 'lepidophyllum';
  static const date = 'lauryn';
  static const dateText = 'obsequeence';
  static const orderStatus = 'firebreaks';
  static const cardStatus = 'satin';
  static const displayAmount = 'libertytown';
  static const orderStatusText = 'cuboid';

  // ---------- 产品申请 / 准入（`/outsulk/weaken`）----------
  /// 模块 id / 位置 / 子模块 id：文档标注已弃用，固定写死。
  static const applyModuleId = 'monotheist';
  static const applyPosition = 'besmeared';
  static const applySubModuleId = 'unidentifying';

  /// 来源标识（0 默认，1 首页 banner，2 首页弹窗 ...）。
  static const apiRemind = 'dirdum';
  static const obfuscateApply1 = 'baaing';
  static const obfuscateApply2 = 'deafened';

  /// 准入结果（data 内）。`200` 成功，其余为失败或需跳转。
  static const applyResultCode = 'countercharged';

  /// 跳转类型：0 原生 / 1 H5。
  static const applyJumpType = 'liquidators';

  /// 准入结果文案。
  static const applyMessage = 'ivah';
  static const applyAccessKey = 'closehearted';
  static const applySecretKey = 'scabrousness';

  // ---------- 产品详情（`/outsulk/inconstruable`）----------
  /// 产品信息对象。
  static const productDetail = 'priapi';
  static const obfuscateDetail1 = 'bonnerdale';
  static const obfuscateDetail2 = 'jawed';
  static const obfuscateDetail3 = 'rustiness';
  static const detailOrderNo = 'pirate';
  static const detailOrderId = 'gasking';

  /// 借款期限 / 期限类型（产品详情与订单跳转共用）。
  static const detailTerm = 'dandled';
  static const detailTermType = 'hellenizer';

  /// 下一步认证项 `{ taskType, title, url, type }`。
  static const detailNextStep = 'cretonne';
  static const detailTaskType = 'catholical';

  // ---------- 认证项：获取用户身份信息（第一项）（`/outsulk/gaonate`）----------
  /// 证件类型分组列表（数组，文档示例只有一组，客户端取第一组）。
  static const idCardGroups = 'wollongong';

  /// 分组里的推荐选项（设计稿 `Recommended ID Type`）。
  static const idCardRecommended = 'unconversational';

  /// 分组里的其他选项（设计稿 `Other Options`）。
  static const idCardOthers = 'drumfish';

  /// 证件名称。既是页面展示文案，也是上传 / 保存接口的卡类型取值。
  static const idCardName = 'partridge';

  /// 正确示范图 url 数组（证件上传页用）。
  static const idCardSampleUrls = 'woodshock';

  /// 错误示范图 url 数组（证件上传页用）。
  static const idCardWrongSampleUrls = 'indecisively';

  /// 该接口的业务混淆字段（「获取用户身份信息」请求参数里的混淆字段）。
  static const obfuscateIdentityInfo = 'disemboguement';

  // ---------- 跟进订单号获取跳转地址（`/outsulk/octodentate`）----------
  static const obfuscatePush1 = 'indefinity';
  static const obfuscatePush2 = 'monocentric';
  static const obfuscatePush3 = 'mediacies';
  static const obfuscatePush4 = 'wanderlusts';

  // ---------- 各接口的混淆字段（无业务含义，每次请求随机值）----------
  static const obfuscateSendSms = 'tectites';
  static const obfuscateLogin1 = 'interoscillate';
  static const obfuscateLogin2 = 'preinscription';
  static const obfuscateLogout1 = 'vaccine';
  static const obfuscateLogout2 = 'carline';
  static const obfuscateHome1 = 'inchoacy';
  static const obfuscateHome2 = 'trifanious';
  static const obfuscateBannerClick = 'callista';
}
