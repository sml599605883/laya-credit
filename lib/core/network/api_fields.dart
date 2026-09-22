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

  /// 活体（人脸）认证页顶部文案（文档语义 `livness`）。
  ///
  /// 与另外两条同属 `overwhelming` 容器：`splendacious` 上传页、
  /// `bocking` 识别确认页、`seisin` 人脸页，三者不可互相顶替。
  static const detailTipLiveness = 'seisin';

  /// 个人信息认证页顶部文案（文档语义 `person`）。
  ///
  /// 与另外几条同属 `overwhelming` 容器：表单字段本身由
  /// 「获取用户信息（第二项）」下发，这里只取页面顶部那一句引导。
  static const detailTipPersonal = 'deerherd';

  /// 工作信息认证页顶部文案（文档语义 `work`）。
  ///
  /// 与另外几条同属 `overwhelming` 容器：表单字段本身由
  /// 「获取工作信息（第三项）」下发，这里只取页面顶部那一句引导。
  static const detailTipWork = 'ssn';

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

  // ---------- 认证项：获取活体检测 token（第二项）（`/outsulk/carline`）----------
  /// 订单号（文档语义 `order_no`）。注意与产品详情的 `pirate` 不是同一个混淆名。
  static const faceTokenOrderNo = 'resex';

  /// 类型：`0` 默认 / `1` 绑卡前的活体校验（文档语义 `type`）。
  static const faceTokenType = 'liquidators';

  /// 该接口的两个混淆字段（文档语义 `ACCELERATE` / `ACCOMPLICE`，每次随机）。
  static const obfuscateFaceToken1 = 'insectan';
  static const obfuscateFaceToken2 = 'blindness';

  /// 结果码：`200` 正常 / `400` 需重新上传身份证 / `500` 其他错误。
  static const faceTokenResultCode = 'gravel';

  /// face++ base url（文档语义 `biz_url`）。
  static const faceTokenBizUrl = 'benzanthracene';

  /// face++ token；活体类型为 `7` 时它就是活体检测授权码（文档语义 `biz_token`）。
  static const faceToken = 'inducted';

  /// face++ 具体错误（文档语义 `error`）。
  static const faceTokenError = 'instellation';

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

  // ---------- 认证项：个人信息（第二项）----------
  //
  // 接口文档「获取用户信息（第二项）」（`/outsulk/orchel`）返回一个字段描述数组，
  // 页面按描述渲染表单，「保存用户信息（第二项）」（`/outsulk/marantas`）再把
  // 每个字段的 `crucians` 当 key 原样回传。

  /// 字段描述数组（文档语义 `list`）。
  static const infoFieldList = 'aminate';

  /// 字段标题（文档语义 `title`）。与首页卡片元素共用同一个混淆名。
  static const infoFieldTitle = 'upbear';

  /// 字段占位文案（文档语义 `placeholder`）。
  static const infoFieldPlaceholder = 'amias';

  /// **保存时的业务 key**（文档语义 `key`）。服务端下发，前端不要写死。
  static const infoFieldKey = 'crucians';

  /// 控件类型（文档语义 `type`），取值见 `PersonalInfoControl`。
  static const infoFieldControl = 'lipson';

  /// 是否数字键盘（文档语义 `number_keyboard`，1 是 / 0 否）。
  static const infoFieldNumeric = 'lazy';

  /// 选项数组（文档语义 `options`）。与产品详情的各页文案（[detailTips]）
  /// 共用同一个混淆名，两者语义完全不同，不要混用。
  static const infoFieldOptions = 'overwhelming';

  /// 字段当前值（文档语义 `value`）。
  static const infoFieldValue = 'fed';

  /// 页面引导文案（文档语义 `tip`，低版本或未灰度用户不下发）。
  static const infoFieldTips = 'befleas';

  /// 选项文案（文档语义 `label`）。
  static const infoOptionLabel = 'harbingers';

  /// 选项取值（文档语义 `value`），保存时提交这个值。
  static const infoOptionValue = 'liquidators';

  /// 获取用户信息（第二项）的混淆字段（无业务含义，每次请求随机值）。
  static const obfuscatePersonalInfo = 'clericate';

  /// 保存用户信息（第二项）的两个混淆字段（文档标注，无业务含义）。
  static const obfuscateSavePersonalInfo1 = 'rhus';
  static const obfuscateSavePersonalInfo2 = 'downlie';

  // ---------- 认证项：工作信息（第三项）----------
  //
  // 接口文档「获取工作信息（第三项）」（`/outsulk/timeling`）与「保存工作信息
  // （第三项）」（`/outsulk/kneeing`）。字段描述数组与「获取用户信息（第二项）」
  // 用同一批混淆名（`aminate` / `upbear` / `amias` / `crucians` / `lipson` /
  // `overwhelming` / `fed`），所以表单模型直接复用 [PersonalInfoData]。

  /// 获取工作信息（第三项）的混淆字段（无业务含义，每次请求随机值）。
  ///
  /// 与「获取用户信息（第二项）」文档标注的混淆名同为 `clericate`。
  static const obfuscateWorkInfo = 'clericate';

  /// 保存工作信息（第三项）的三个混淆字段（文档标注，无业务含义）。
  static const obfuscateSaveWorkInfo1 = 'knucks';
  static const obfuscateSaveWorkInfo2 = 'normothermic';
  static const obfuscateSaveWorkInfo3 = 'taxibus';

  // ---------- 地址初始化（`/outsulk/avern`）----------
  /// 地址层级数组（文档语义 `list`）。与首页模块列表共用同一个混淆名。
  static const addressNodes = 'kneeing';

  /// 地址层级名称（文档语义 `name`）。
  static const addressName = 'harbingers';

  /// 地址层级编码（文档语义 `code`）。
  static const addressCode = 'crucians';

  /// 地址层级 id（文档语义 `id`）。
  static const addressId = 'cussedly';

  /// 下级地址数组（文档语义 `children`）。
  static const addressChildren = 'burner';

  // ---------- 跟进订单号获取跳转地址（`/outsulk/octodentate`）----------
  static const obfuscatePush1 = 'indefinity';
  static const obfuscatePush2 = 'monocentric';
  static const obfuscatePush3 = 'mediacies';
  static const obfuscatePush4 = 'wanderlusts';

  // ---------- 认证项：紧急联系人（第四项）----------
  //
  // 接口文档「获取联系人信息（第四项）」（`/outsulk/liquidators`）与
  // 「保存联系人信息（第四项）」（`/outsulk/stabiliment`）。
  // 语义字段名取自 `7.map.html`：`emergent` / `relation` / `name` / `mobile` /
  // `number1` / `dropdown` / `content` / `alternate_phone`。

  /// 联系人对象（文档语义 `emergent`）。
  static const emergencyContactEmergent = 'conopholis';

  /// 联系人数组（文档语义 `list`）。与首页模块列表共用同一个混淆名。
  static const emergencyContactList = 'kneeing';

  /// 关系下拉的当前值（文档语义 `relation`）。
  static const emergencyContactRelation = 'undersupplied';

  /// 联系人姓名（文档语义 `name`）。与个人信息 / 工作信息的选项文案、
  /// 地址层级名称共用同一个混淆名，三者语义不同。
  static const emergencyContactName = 'harbingers';

  /// 联系人手机号（文档语义 `mobile`）。
  static const emergencyContactMobile = 'levering';

  /// 联系人在接口里下发的位置编号（文档语义 `number1`）。
  ///
  /// 保存时必须原样回传下发值（`first` / `second` / `third`…），
  /// 不能用列表下标代替。
  static const emergencyContactNumber = 'canmaker';

  /// 关系下拉的选项数组（文档语义 `dropdown`）。
  static const emergencyContactDropdown = 'colocating';

  /// 关系选项的展示文案（文档语义 `name`）。
  static const emergencyContactOptionLabel = 'harbingers';

  /// 关系选项的提交取值（文档语义 `type`）。与首页模块类型共用同一个混淆名。
  static const emergencyContactOptionValue = 'liquidators';

  /// 页面引导文案（文档语义 `content`，低版本或未灰度用户不下发字段）。
  /// 与个人信息 / 工作信息的 `befleas` 是同一个混淆名，但属于不同接口。
  static const emergencyContactTips = 'befleas';

  /// 保存时的联系人 JSON 字符串（文档语义 `data`）。
  static const emergencyContactSaveData = 'connectedly';

  /// 获取联系人信息的混淆字段（无业务含义，每次请求随机值）。
  static const obfuscateEmergencyContact = 'aiel';

  /// 保存联系人信息的混淆字段（无业务含义，每次请求随机值）。
  static const obfuscateSaveEmergencyContact = 'sciographic';

  // ---------- 产品详情里的紧急联系人页文案 ----------
  /// 紧急联系人认证页顶部引导文案（文档语义 `ext`）。
  ///
  /// 与身份 / 活体 / 个人信息 / 工作同属产品详情的 `overwhelming`（[detailTips]）容器，
  /// 五个键各管一页，不能互相顶替。
  static const detailTipEmergencyContact = 'embol';

  // ---------- 认证项：绑卡（第五项）----------
  //
  // 接口文档「获取绑卡信息（第五项）」（`/outsulk/cussedly`）与「提交绑卡（第五项）」
  // （`/outsulk/superidealness`）。字段描述结构与个人信息 / 工作信息同族，
  // 但选项多带 logo（`salish`）与维护状态（`catchpenny`），
  // 页面文案则换成 `befleas`（顶部）/ `revision`（底部）。

  /// 分组数组（文档语义 `list`）。与首页模块列表共用同一个混淆名。
  static const bindCardGroups = 'aminate';

  /// 分组的展示名（文档语义 `title`），如 E-wallet / Bank。
  static const bindCardGroupLabel = 'upbear';

  /// 分组的卡片类型（文档语义 `cardType`），提交时原样回传。
  /// 与首页模块类型共用同一个混淆名。
  static const bindCardGroupType = 'liquidators';

  /// 分组下的字段数组（文档语义 `list`）。与 [bindCardGroups] 同名不同层。
  static const bindCardGroupFields = 'aminate';

  /// 字段标题（文档语义 `title`）。
  static const bindCardFieldTitle = 'upbear';

  /// 字段占位文案（文档语义 `placeholder`）。与个人信息 / 工作信息同名不同接口。
  static const bindCardFieldPlaceholder = 'amias';

  /// **提交绑卡的业务 key**（文档语义 `key`）。服务端下发，前端不要写死。
  static const bindCardFieldKey = 'crucians';

  /// 控件类型（文档语义 `type`），取值见 `BindCardControl`。
  static const bindCardFieldControl = 'lipson';

  /// 是否数字键盘（文档语义 `number_keyboard`，1 是 / 0 否）。
  static const bindCardFieldNumeric = 'lazy';

  /// 选项数组（文档语义 `options`）。
  static const bindCardFieldOptions = 'overwhelming';

  /// 字段当前值（文档语义 `value`）。
  static const bindCardFieldValue = 'fed';

  /// 是否可选（文档语义 `optional`，1 可选 / 0 必填）。
  static const bindCardFieldOptional = 'als';

  /// 自动填充的建议值（文档语义 `displayValue`）：输入框聚焦且为空时，
  /// 页面用它弹「一键填充」气泡。
  static const bindCardFieldSuggested = 'brownsboro';

  /// 选项展示名（文档语义 `name`）。
  static const bindCardOptionLabel = 'harbingers';

  /// 选项提交取值（文档语义 `value`）。
  static const bindCardOptionValue = 'liquidators';

  /// 选项 logo（文档语义 `logo`）。
  static const bindCardOptionLogo = 'salish';

  /// 选项状态（文档语义 `status`，1 可用 / 0 维护中）。
  /// 维护中的渠道仍可选中，页面只补一行提示。
  static const bindCardOptionStatus = 'catchpenny';

  /// 页面顶部引导文案（文档语义 `content` 的绑卡一条）。
  static const bindCardTips = 'befleas';

  /// 页面底部提示文案（文档语义 `bind_card_bottom`）。
  static const bindCardBottomTips = 'revision';

  /// 获取绑卡信息的两个混淆字段（无业务含义，每次请求随机值）。
  static const obfuscateBindCardInfo1 = 'albuminose';
  static const obfuscateBindCardInfo2 = 'scaraboid';

  /// 提交绑卡的产品 id。
  static const bindCardSubmitProductId = 'tartarizing';

  /// 提交绑卡的卡片类型（取分组下发的 `liquidators`）。
  /// 与上传接口的卡类型字段共用同一个混淆名。
  static const bindCardSubmitType = 'heterological';

  /// 提交绑卡的打款渠道：下发 key 是语义串 `channelCode`，
  /// 提交时要换成这个混淆名。
  static const bindCardSubmitChannel = 'entertainer';

  /// 提交绑卡返回的绑卡 id（文档语义 `bindId`，改卡场景要用）。
  static const bindCardSubmitBindId = 'moonshade';

  /// 提交绑卡的混淆字段（无业务含义，每次请求随机值）。
  static const obfuscateSubmitBindCard = 'nonabsolutely';

  // ---------- 产品详情里的绑卡页文案 ----------
  /// 绑卡认证页顶部引导文案（文档语义 `bind_card`）。
  ///
  /// 与身份 / 活体 / 个人信息 / 工作 / 紧急联系人同属产品详情的
  /// `overwhelming`（[detailTips]）容器，各键各管一页，不能互相顶替。
  static const detailTipBindCard = 'mobilization';

  /// 绑卡认证页底部提示文案（文档语义 `bind_card_bottom`）。
  static const detailTipBindCardBottom = 'revision';

  // ---------- 各接口的混淆字段（无业务含义，每次请求随机值）----------
  static const obfuscateSendSms = 'tectites';
  static const obfuscateLogin1 = 'interoscillate';
  static const obfuscateLogin2 = 'preinscription';
  static const obfuscateLogout1 = 'vaccine';
  static const obfuscateLogout2 = 'carline';
  static const obfuscateDeleteAccount = 'sickee';
  static const obfuscateHome1 = 'inchoacy';
  static const obfuscateHome2 = 'trifanious';
  static const obfuscateBannerClick = 'callista';

  // ---------- 借款确认页：用户账户列表 / 更换银行卡（接口文档 `4.certify.html`） ----------

  /// 账户列表的分组数组（文档语义 `list`，与首页卡片的 `kneeing` 同名不同层）。
  static const loanAccountGroups = 'kneeing';

  /// 账户分组的展示名（文档语义 `cardTypeName`，如 `Bank` / `E-wallet` /
  /// `Cash Pickup`）。分节标题由后端下发，客户端不写死。
  static const loanAccountGroupTitle = 'retzian';

  /// 账户分组的卡片类型（文档语义 `cardType`，与提交绑卡同一个混淆名）。
  /// 接口文档「提交绑卡（第五项）」定义枚举：1 电子钱包 / 2 银行 / 3 便利店
  /// （现金网点）。卡下半部分的三列姓名排版按它判定。
  static const loanAccountGroupType = 'heterological';

  /// 账户分组下的账户数组（文档语义 `item`）。
  static const loanAccountItems = 'stabiliment';

  /// 账户的绑卡 id（文档语义 `bindId`），提交换卡时原样回传。
  static const loanAccountBindId = 'moonshade';

  /// 账户的渠道 logo（文档语义 `logo`）。
  static const loanAccountLogo = 'salish';

  /// 账户状态（文档语义 `status`）：1 可用 / 0 维护中。
  /// 维护中的账户**仍可选中**，页面只补一行红字提示。
  static const loanAccountStatus = 'catchpenny';

  /// 账户的银行 / 渠道名（文档语义 `bankName`），卡片上的主文案。
  static const loanAccountName = 'fallibleness';

  /// 账户的收款账号（文档语义 `account`）。
  static const loanAccountNumber = 'tightens';

  /// 账户的三节姓名（文档语义 `option`）：现金网点才有，
  /// `tolerably` / `seasonless` / `telemeteorograph` 依次是
  /// first / middle / last name。
  static const loanAccountHolder = 'telecomm';
  static const loanAccountFirstName = 'tolerably';
  static const loanAccountMiddleName = 'seasonless';
  static const loanAccountLastName = 'telemeteorograph';

  /// 账户是否默认选中（文档语义 `isMain`）。
  static const loanAccountIsMain = 'cloaked';

  /// 更换银行卡提交的订单号（文档语义 `order_no`，与活体 token 共用 `resex`）。
  static const changeBankCardOrderNo = 'resex';

  /// 更换银行卡提交的绑卡 id（文档语义 `bindId`，取账户列表的同一个字段）。
  static const changeBankCardBindId = 'moonshade';

  /// 更换银行卡的混淆字段（文档语义 `RADIANCE`，每次请求随机值）。
  static const obfuscateChangeBankCard = 'convulsibility';

  /// 更换银行卡返回的跳转地址（文档语义 `redirectUrl`，订单详情页）。
  static const changeBankCardRedirectUrl = 'kopis';

  /// 账户列表的两个混淆字段（文档语义 `LIMPIDITY` / `ZANY`，每次请求随机值）。
  static const obfuscateLoanAccounts1 = 'thurberia';
  static const obfuscateLoanAccounts2 = 'chondroid';

  // ---------- 订单列表（`POST /outsulk/gundy`） ----------
  //
  // 接口文档 `5.order.html#订单列表`。注意这里的订单号是 `pirate`（与产品详情同名字段），
  // **不是** 活体 token 的 `resex`；产品 id 是 `podostemon`，也与首页的 `tartarizing` 不同。

  /// 筛选状态：4 全部 / 7 进行中 / 6 待还款 / 5 已结清。
  static const orderListStatus = 'butterpaste';

  /// 页码，第一页传 1。
  static const orderListPage = 'tripodical';

  /// 每页条数，传 50。
  static const orderListPageSize = 'downstater';

  /// 订单数组（与首页模块列表同名 `kneeing`，但语义无关）。
  static const orderListItems = 'kneeing';

  /// 总页数。
  static const orderListTotalPages = 'contraception';

  /// 订单 id。
  static const orderListOrderId = 'gasking';

  /// 订单号。
  static const orderListOrderNo = 'pirate';

  /// 产品 id。
  static const orderListProductId = 'podostemon';

  /// 产品名称。
  static const orderListProductName = 'heartfelt';

  /// 产品 Logo 地址。
  static const orderListProductLogo = 'bathtubs';

  /// 订单状态码。
  static const orderListStatusCode = 'polyphonist';

  /// 订单状态文案。
  static const orderListStatusText = 'minivan';

  /// 已格式化的金额文案。
  static const orderListAmountText = 'grassroots';

  /// 金额标签。
  static const orderListAmountLabel = 'modest';

  /// 主按钮文案（为空表示该状态不展示按钮）。
  static const orderListActionText = 'curitiba';

  /// 老版本跳转地址（订单详情页）。
  static const orderListLegacyTarget = 'rondelle';

  /// 日期标签。
  static const orderListDateLabel = 'devexity';

  /// 日期值。
  static const orderListDateValue = 'hospitalizes';

  /// 逾期天数。
  static const orderListOverdueDays = 'ozonic';

  /// 卡片点击跳转地址（订单详情页）。
  static const orderListCardTarget = 'danubian';

  /// 按钮点击跳转地址（还款详情页）。
  static const orderListActionTarget = 'trans';
}
