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

  /// 各认证页顶部文案对象（文档语义 `note`）。
  ///
  /// 结构：`{ 身份认证、身份认证成功、活体、个人信息、工作、紧急联系人、绑卡... }`，
  /// 每个子字段是一条页面引导文案。`overwhelming` 本身不是文案，别整段当字符串用。
  static const detailTips = 'overwhelming';

  /// 身份认证页顶部文案（文档语义 `base`）。
  static const detailTipIdentity = 'splendacious';

  /// 身份认证**成功**页顶部文案（文档语义 `identitySuccess`）。
  ///
  /// 与 [detailTipIdentity] 同属 `overwhelming` 容器，别混用：
  /// `splendacious` 是上传页的，`bocking` 是识别结果确认页的。
  static const detailTipIdentitySuccess = 'bocking';

  /// 下一步认证项 `{ taskType, title, url, type }`。
  static const detailNextStep = 'cretonne';
  static const detailTaskType = 'catholical';

  // ---------- 认证项：获取用户身份信息（第一项）（`/outsulk/gaonate`）----------
  /// 证件类型分组：两段字符串数组，`[[推荐...], [其他...]]`。
  static const idCardGroups = 'magisterial';

  /// 该接口的业务混淆字段（「获取用户身份信息」请求参数里的混淆字段）。
  static const obfuscateIdentityInfo = 'disemboguement';

  // ---------- 认证项：上传证件图片（`/outsulk/fashioned`）----------
  /// 上传类型：`10` 人像 / `11` 身份证正面。
  static const uploadType = 'liquidators';

  /// 图片来源：`1` 相册 / `2` 拍照（`uploadType=10` 时固定 `1`）。
  static const uploadImageSource = 'chromogenous';

  /// 证件类型（证件选择页的行文案）。
  static const uploadCardType = 'heterological';

  /// 图片文件的表单字段名（文档里就是字面量 `attach`，没有混淆）。
  static const uploadFileField = 'attach';

  // 下面四个是活体（`uploadType=10`）才用得上的参数。身份证正面用不到，
  // 但后端要求这些字段必须存在，所以上传时固定带空串（对齐 peso_shield 的 uploadImage）。
  /// 活体类型 5/6 传 biz_token，7 传 livenessId。
  static const uploadLivenessId = 'gargantua';

  /// 活体检测授权码（活体类型 7 必传）。
  static const uploadLivenessLicense = 'musculopallial';

  /// 活体类型：5 face++ / 6 lite face++ / 7 trustdecision。
  static const uploadFaceType = 'bassein';

  /// 活体业务编号（type=10 且 faceType=6 时必传）。
  static const uploadBizId = 'sadomasochism';

  // ---------- 认证项：上传证件图片（`/outsulk/fashioned`）的 OCR 结果 ----------
  //
  // 接口文档「接口上传(face,身份证正面)（第一项）」：`type=11` 时响应 `connectedly`
  // 带回识别结果，保存接口（`/outsulk/wardmote`）把这几个值原样回传。
  /// 识别出的姓名。
  static const identityName = 'harbingers';

  /// 识别出的证件号。
  static const identityIdNumber = 'approach';

  /// 识别出的出生日期。上传响应是 `23/11/1993`，保存接口要求 `d-m-Y`，
  /// 页面在跳转前统一成 `23-11-1993`（与设计稿 `23-02-1996` 一致）。
  static const identityBirthDate = 'counter';

  /// 证件照地址。与产品详情/准入的跳转地址（[jumpUrl]）共用同一个混淆字段名，
  /// 但在上传响应里语义是「证件照 url」，所以单独给一个按用途命名的常量。
  static const identityImageUrl = 'superidealness';

  /// 保存身份证信息的混淆字段（无业务含义，每次请求随机值）。
  static const obfuscateSaveIdentity = 'stith';

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
