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

  // ---------- 个人中心 ----------
  static const serviceList = 'metamitosis';
  static const ifRedPoint = 'imtiaz';
  static const redPointId = 'gaze';

  // ---------- 首页 ----------
  static const homeKneeing = 'kneeing';
  static const homeType = 'liquidators';
  static const homeItems = 'stabiliment';

  /// banner 点击上报（`/outsulk/gaile`）的 banner_config_id。
  static const bannerConfigId = 'geheimrat';

  // ---------- 卡片元素 ----------
  static const itemId = 'cussedly';
  static const itemTitle = 'upbear';
  static const itemKey = 'lozenged';
  static const iconUrl = 'marantas';
  static const linkUrl = 'timeling';
  static const jumpUrl = 'superidealness';
  static const isH5 = 'laparohysterectomy';
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

  // ---------- 各接口的混淆字段（无业务含义，每次请求随机值）----------
  static const obfuscateSendSms = 'tectites';
  static const obfuscateLogin1 = 'interoscillate';
  static const obfuscateLogin2 = 'preinscription';
  static const obfuscateLogout1 = 'vaccine';
  static const obfuscateLogout2 = 'carline';
  static const obfuscateHome1 = 'inchoacy';
  static const obfuscateHome2 = 'trifanious';
  static const obfuscatePersonalCenter = 'doulocracy';
  static const obfuscateBannerClick = 'callista';
}
