# laya_credit

菲律宾市场的借贷撮合/推荐类 App（Flutter，仅 iOS）。本仓库定位为**撮合平台**：
App 内不直接放贷，只做产品展示与资料收集，最终由第三方资金方完成放款。

## 基础搭建已完成的部分

### 1. 页面跳转由什么控制

**命名路由 + `onGenerateRoute` 集中式路由表**，不使用 `Navigator.of(context).push(MaterialPageRoute(...))` 的散装写法。

| 关注点 | 位置 |
| --- | --- |
| 路由名常量（唯一来源） | `lib/core/navigation/app_routes.dart` |
| 路由名 → 页面 + 入参解析 | `lib/core/navigation/app_route_generator.dart` |
| 全局跳转入口（含无 context 场景） | `lib/core/navigation/app_navigator.dart` |
| 页面曝光埋点钩子 | `lib/core/navigation/app_route_observer.dart` |

约定：

- 业务代码只写 `AppNavigator.push(AppRoutes.xxx, arguments: ...)`，禁止出现裸字符串路由名。
- 页面入参用强类型类（如 `LoginPageArguments`）在生成器里解析，页面构造函数保持 `required` 参数，缺参数时在跳转处就报错。
- `MaterialApp.navigatorKey` 指向 `AppNavigator.navigatorKey`，支付回调、推送、会话过期等没有页面 `context` 的场景也能跳转。
- 页面栈操作只暴露 4 个语义化方法：`push` / `replace` / `resetTo`（清栈）/ `pop`。
- 侧滑返回保持 Flutter 默认（iOS 可返回）。若某个流程需要禁止中途返回，只改该路由对应的 Route 实现，不要全局关闭。

目前注册的路由：`/`（Tab 容器）、`/home`、`/stats`、`/mine`、`/login`，
以及认证流程的二级页 `/id-verification`（证件选择，见第 12 条）、
`/id-upload`（证件上传，见第 13 条）、`/id-confirm`（证件信息确认，见第 14 条）、
`/face-verification`（人脸识别，见第 15 条）。

### 2. 状态管理用什么

**Riverpod（`flutter_riverpod` 3.x）**，`ProviderScope` 挂在根节点，启动时用 `ProviderContainer` 预恢复登录态后再首帧。

| 场景 | 用法 |
| --- | --- |
| 同步只读依赖 | `Provider`（如 `networkConfigProvider`） |
| 异步初始化依赖 | `FutureProvider`（如 `httpClientProvider`、`deviceParamsProvider`） |
| 可变业务状态 | `NotifierProvider`（如 `userSessionProvider`） |
| 页面内一次性异步 | `AsyncNotifierProvider`（后续接入接口时使用） |

约定：

- 页面通过 `ref.watch(...)` 订阅；只在事件回调里用 `ref.read(...)`。
- 只关心单个字段时用 `ref.watch(p.select((s) => s.xxx))`，避免无关变更触发重建。
- 不要在 `build` 里做副作用；`ref.listen` 用于「状态变化 → 弹窗/跳转」这类响应。
- 分层：**Page → Provider → Repository → HttpClient**。页面不直接碰 Dio。

### 3. 目录结构

```
lib/
├── main.dart                     # 入口：ProviderScope + MaterialApp + 路由表
├── root_tab_page.dart            # 底部 Tab 容器（IndexedStack，保留各 Tab 状态）
├── core/
│   ├── config/                   # 后端接入参数（根地址 / 签名密钥 / 渠道标识）
│   ├── device/                   # 设备信息（deviceId / 版本号 / 机型）
│   ├── navigation/               # 路由表、生成器、全局导航、路由观察者
│   ├── network/                  # Dio 客户端、签名、公共参数、响应协议、异常
│   ├── session/                  # 登录态模型与本地持久化
│   └── ui/                       # Toast / Loading
├── pages/                        # 页面（一级目录平铺，页面内组件放同目录 widgets/）
├── providers/                    # Riverpod provider
├── theme/                        # 设计令牌：颜色 / 间距 / 切图 / 尺寸换算 / 主题
└── widgets/                      # 跨页面复用组件（底部导航等）
```

### 4. 设计令牌与蓝湖稿适配

- 设计稿基准宽度 **375pt**，用 `AppLayout.of(context).px(24)` 换算，禁止直接写死像素。
- 间距必须是 **8pt 的整数倍**，取值统一走 `AppSpacing`。
- **禁止硬编码 Hex 色值**，一律引用 `AppColors` 常量（命名按用途，不按色值）。
- 切图统一走 `AppAssets` 常量；路径对应 `pubspec.yaml` 中注册的 `assets/` 子目录。
- `assets/<页面>_slices/` 是蓝湖的**原始导出目录**，保留作为源文件、不参与打包；按用途重命名后的副本放在 `assets/{home,mine,navigation,common}/` 并注册进 `pubspec.yaml`。

### 5. 合规与健壮性约束

- 所有 API 调用必须完整处理 Loading / Error / Empty 三种状态，异常统一收敛为 `ApiException`，不允许因为接口异常闪退。
- 「立即申请」「支付回调」等关键路径需要接 Firebase Analytics 埋点，异常需能被 Crashlytics 捕获。
- 会话过期（后端返回 `-2`）与用户主动退出登录走**不同**路径：只有过期才自动弹登录页（`sessionExpirySignalProvider` → `RootTabPage`）。
- 金额展示必须千分位格式化、禁止浮点运算（`Decimal` 或「分」为单位的整型）。
- 借款到期日判断以 `origin_end_time` 为准。

### 6. 接口协议（已按接口文档核对）

接口文档项目为蓝湖 `ph_laya_credit_ios`，通过已配置的 `api-doc` MCP 工具读取。
本地需要在被忽略的 `.codex/project.toml` 里写上 `[mcp.api-doc.env] API_PREFIX = "ph_laya_credit_ios"`
（该文件含本地 MCP 配置，不入库）。

环境地址（在 `lib/core/config/api_environment.dart`）：

| 环境 | 地址 |
| --- | --- |
| 接口（测试） | `http://8.220.190.152/whole/`（必须以 `/` 结尾） |
| H5（测试） | `http://8.220.190.152` |

⚠️ 测试环境是「IP + 明文 HTTP」，该地址没有 HTTPS 监听。iOS 模拟器实测 ATS 放行了
明文 IP 请求，**但没有做任何 ATS 例外配置**；如果后续换到真机出现
`App Transport Security policy requires the use of a secure connection`，
说明该机器需要单独放行，届时优先找后端要 HTTPS 域名，而不是加 `NSAllowsArbitraryLoads`。

报文协议已逐项核对，映射集中在下面几个文件：

| 内容 | 位置 |
| --- | --- |
| 密钥与渠道（aesKey / iv / verifySecretKey / market） | `lib/core/config/api_environment.dart` |
| 公共参数名、响应字段名、错误码 | `lib/core/network/api_protocol.dart` |
| 接口路径（混淆后） | `lib/core/network/api_endpoints.dart` |
| 业务字段名（混淆后） | `lib/core/network/api_fields.dart` |

关键规则（改网络层之前先确认）：

- 公共参数以 **URL 参数**方式传递；POST 的业务参数走 form body，公共参数与签名仍在 query。
- 加签：公参 + 请求路径（`tarnhelm`），按参数名升序拼成 `key+value`，再用 `verifySecretKey` 做
  HMAC-SHA256（`RequestSigner`）。**公共混淆字段 `stith` 与签名本身不参与计算**；校验失败返回 `code 400`。
- **签名覆盖的参数必须与实际下发的参数完全一致**（测试环境实测结论）：后端是拿收到的参数重算签名的，
  多签一个没下发的字段会被判成 `code 400`。曾经 `gruelled` 只出现在签名里、不随请求下发，导致首页一直
  400；现在按文档的加签示例「照发照签」。新增公共参数时务必同步两处，测试里已有对应的守门用例。
- 响应固定三段：`crucians`(code) / `norseled`(message) / `connectedly`(data)；`0` 成功、`-2` 未登录。
- 混淆字段每次请求随机生成，不参与签名，见 `lib/core/network/obfuscation_helper.dart`。
- 后端字段名是混淆串，**写错不会报错、只会静默读到 `null`**：新增字段一律先查文档
  `7.map.html` 的字段映射，并登记到 `ApiFields`，禁止在页面里直接拼字符串。
  注意同名业务语义在不同接口可能用不同字段（如产品大卡的名称是 `heartfelt`，
  订单卡的产品名是 `current`）。
- 首页 `kneeing[].liquidators` 下发的是**模块名，而且是混淆串**，不是文档里的语义名。
  测试环境实测：`MalvernePlucked`=BANNER、`LupusesWheelrace`=LARGE_CARD、
  `BelliferousOverfertilizing`=AD_LIST、`Broadtoothed`=PROCESS_LIST。
  `HomeData` 先用 `_canonicalSectionType()` 归一化再匹配；漏掉这一步首页会静默变空
  （product / banner / orders 全是 `null`，不报错）。

## ⚠️ 待接入 / 待确认（下一步必做）

1. **测试环境已联调通过**：首页已在模拟器上拉到真实数据（banner + 空态），
   签名（GET / POST）、`-2` 未登录、`400` 签名失败三条链路都实测过。
   还缺**生产环境地址**，拿到后替换 `ApiEnvironment.apiBase` 即可。
   QA 可用 `runtimeApiBaseProvider` 在运行时切环境，不必重新打包。
2. **首页顶部 `orchel` 未接入**：文档首页响应根节点还有一组 `orchel`（`marantas` 图标 + `timeling` 跳转），
   与 `kneeing` 里的 `BANNER` 模块不是同一个东西，需要设计确认它在首页的位置。
3. **登录链路待真机验证**：短信验证码 / 登录接口已实现且签名被服务端接受，但发真实验证码需要测试手机号，
   尚未端到端跑过（登出 / 个人中心 / banner 上报已确认签名通过）。
4. **其余接口未接入**：订单、上报、H5 相关接口尚未落地。
   「点击申请」链路已接通到准入接口，但下游页面仍缺：准入 / 详情返回的
   H5 地址需要 WebView、认证项还缺紧急联系人 / 绑卡页、
   原生 `recredit` 需要重新授信 loading 页。相关分支见
   `lib/core/product/product_application_flow.dart` 的 TODO(页面)。
   认证项第一项（身份信息 `GET /outsulk/gaonate`）已接入证件选择页（见第 12 条），
   第二项（证件上传页）已按设计稿落地并接上上传接口（见第 13 条），
   第三项（证件信息确认页）也已落地并接上保存接口（见第 14 条），
   第四项（活体 / 人脸识别）也已落地并接上 token / 上传接口（见第 15 条），
   个人信息认证项也已落地并接上表单 / 保存接口（见第 16 条），
   工作信息认证项也已落地（见第 17 条）。
5. **首页已按蓝湖稿 02-01 / 02-02 还原**（额度头图 + 白色额度卡 + 授信进度卡 + 运营位 +
   推荐列表 + 悬浮底栏）。
   授信进度卡用设计导出的整卡底图 `assets/home/home_progress_card.png`（343x119pt：
   白描边 / 深色标题条 / 左侧金币 / 金色光晕 / 标题文字 / 柠檬绿卡身），
   页面只在卡身上叠金额行 / 进度槽 / 阶段文案行；进度槽上的阶段金币用
   `assets/home/home_progress_coin.png`，未到达阶段对同一张切图按亮度去色，与设计稿的银币一致。
   改动前**不要**再从设计稿 PNG 里裁切或从蓝湖下载素材：`assets/` 里没有的素材直接忽略。
   其余页面（个人中心以外的二级页）仍待补齐。
6. **底部导航** 已按蓝湖稿还原为悬浮胶囊（200x48）+ 三个 40pt 圆形按钮，选中态是柠檬绿实心圆；
   设计稿没有文字标签，代码里只保留 `Semantics` 文案。**Stats 页的定位**仍需与设计确认。
   根 Scaffold 开了 `extendBody`：页面内容一直铺到屏幕底部、从胶囊下方穿过，不再被截在胶囊顶边；
   新增 Tab 页时，滚动容器必须把 `AppTabBar.overlapHeight(context)` 加到底部内边距上，
   否则最后一条内容会滚不出胶囊的遮挡区（`test/widget_test.dart` 有对应回归测试）。
7. **消息 / 客服 / 隐私政策等二级页面** 尚未搭建，当前点击只弹占位提示。
8. **首页头图的问候语**：蓝湖稿 02-01 顶部是用户名（`Maya Agad`），接口当前没有下发昵称，
   先用品牌名 `Laya Credit` 顶位，等账号接口给出昵称字段再替换。
   进度卡标题现在直接来自整卡底图（设计稿的 `Credit activation progress`），
   后端 `vesperal`（如「Complete the authentication in just 3 minutes…」）**暂时不渲染**：
   底图是整卡合并位图，标题文字已经烘焙进图片里。若标题要跟随后端动态显示，
   需要设计另导一份不带标题文字的卡片底图，再叠到标题位置。
9. **首页公告 `AD_LIST` 暂无展示位置**：设计稿 02-01 / 02-02 都没有公告条，
   头图里原来固定占位 16pt 的公告已按设计稿删掉（`HomeData.notices` 仍在解析、测试保留）。
   等设计给出公告的展示位置（或确认不做）后再接。

10. **个人中心已按蓝湖稿 07-01 还原**（深色头图 + 订单入口渐变卡 + Customer Service / About Us 两组入口）。
    卡片外的页面底色、卡片圆角 / 内边距 / 行高都取自设计稿 CSS 与 Design Tokens；
    订单卡的圆角与渐变直接用整卡底图 `assets/mine/mine_order_card.png`（319x95）。
    卡片底部的薄荷色「肩线」同样走切图 `assets/mine/order_card_shoulder.png`（设计稿 `image_2`，
    375x28 通栏）：它顶边压在卡片底部 16pt，只露出 12pt；卡片左右各露出的那一角
    `rgba(51,65,65)` 深色衬底也在切图里。原先用 `CustomPainter` 手画的薄荷色梯形已删除
    （它漏掉了那圈深色衬底，且斜边不如切图准）。
    差异与待确认项：
    - **头图头像**：设计稿放的是 App 品牌图标，`assets/` 里没有这张切图，暂用
      `assets/mine/mine_avatar.png`（黑色剪影）并反白渲染——不反白在深色头图上完全看不见。
      拿到品牌图标后替换这一处即可。
    - 设计稿 `Website` 行右侧的「复制」小图标同样不在 `assets/` 里，按仓库约定直接不渲染；
      行本身仍响应点击（把域名写进剪贴板）。
    - `Website` 的域名与 `APP Version` 的版本号在设计稿里是 `xxxxx.com` / `v1.00` 占位，
      代码里分别取 `ApiEnvironment.h5Base` 的域名和安装包真实版本（`deviceParamsProvider`）。
      官网正式域名待产品确认后换成独立配置项。
    - 设计稿的订单入口是 All / Outstanding / Overdue / Settled，而订单筛选状态文档只有
      4 全部 / 7 进行中 / 6 待还款 / 5 已结清：`Overdue` 没有对应取值，暂时不传状态值（只展示、不跳转）。
    - 设计稿没有独立的「退出登录」按钮，退出入口挪到 About Us 的 `Account` 行，
      弹出设计稿 `07-01 - 个人中心-退出` 的底部面板（Log out / Delete Account / Quit）。
      `Delete Account` 尚未接入；`Quit` 按「关掉面板」处理。
    - **个人中心不请求接口**：产品确认 `GET /outsulk/interoscillate` 用不到，Customer Service
      那一行（`Smart customer service`）和 About Us 四项一样是客户端常量，文案与顺序取自设计稿。
      随之删掉了 `PersonalCenterProvider` / `PersonalCenterData` / 仓库方法 / 接口路径与字段常量；
      原本靠它下发的未读消息红点（`hasRedPoint` / `redPointId`）也一并下线，消息中心补齐时再加回。
      页面因此没有 Loading / Error 态，下拉刷新（没有可刷新的数据）也去掉了。
    - 蓝湖导出的切图文件名原本与设计稿元素错位了一格（`mine_message.png` 实际是订单「All」图标），
      已按设计稿语义重命名（`order_all/outstanding/overdue/settled`、
      `service_website/app_version/privacy/account`）；`pubspec.yaml` 按目录注册，无需同步改动。
      另外 `assets/navigation/tab_bar_background.png` 其实是订单卡的肩线切图，已移到
      `assets/mine/order_card_shoulder.png`（`AppAssets.mineOrderCardShoulder`）；
      底部导航目前是代码画的悬浮胶囊，不需要背景切图。
    - 设计稿的间距不全是 8pt 倍数（`block_2` 的 12/10、About Us 卡上方的 17、图标与文案之间的 6），
      这里以设计稿数值为准，新增元素时请沿用同一套值而不是就近取整。

11. **首页推荐列表已按蓝湖稿 02-01 的 `group_3` 还原**（后端模块 `PRODUCT_LIST`，
    测试环境下发混淆值 `Sixcylinder`）。`kneeing[].liquidators` 的混淆表在
    `7.map.html#首页元素`，**逐行对应**：MalvernePlucked=BANNER、LupusesWheelrace=LARGE_CARD、
    Abaca=SMALL_CARD、Fugue=REPAY、Sixcylinder=PRODUCT_LIST、Broadtoothed=PROCESS_LIST、
    BelliferousOverfertilizing=AD_LIST。补新类型时先核对行序，不要再按名字猜。
    模块要点与已知差异：
    - 区块标题右侧的「More + 箭头」产品确认不做，`_Recommendation` 只渲染标题；
      后端没下发推荐卡时整块不渲染（设计稿没有这一块的空态）。
    - 卡片 96x130 的弧形「Apply Now」按钮是**整块切图**（弧形卡身 + 文案烘焙在图里），
      按后端 `holts`（1 高亮 / 0 正常 / -1 置灰）选
      `apply_now_highlight` / `apply_now_normal` / `apply_now_disabled`；
      `holts` 缺失或取值不认识时回落「正常」。切图位置走 `top/right/bottom: 0` 贴住深色外框，
      所以外框高度变化时按钮会一起伸缩，不要再按固定 top 摆。
    - 「利率 / 期限」小表的期限标签用的是 `lxe`，与产品大卡的 `solomon` 不是同一个字段；
      金额说明仍复用大卡的 `octodentate`。文档示例里它的值是 `Maximum Loan Amount Upto`，
      而设计稿写的是 `Available up to` —— 以接口实测为准，不要照设计稿写死。
    - 底部粉色提示行由 `islet`（数组）用「 / 」拼接；它是长度不可控的整行文案，
      放不下时等比缩小而不是截断。金额同理走 `FittedBox(scaleDown)`，金额永远不许省略号。
    - 整张卡与按钮共用 `_openApply()`（与额度大卡一致）。`superidealness` 跳转地址暂未接入，
      与 banner 一样等 WebView / 产品详情页补齐后再接。

12. **证件选择页已按蓝湖稿 03 还原**（认证流程第一步，`/id-verification`）。
    头图（绿色渐变 + 「ID Verification」大标题 + 吉祥物，375x213）是整块切图
    `assets/id_verify/id_verify_header.png`（用户提供的 `位图@3x.png`），
    返回按钮走 `assets/common/back.png`（用户提供的 `返回@3x.png`，24x24，两个素材都已按用途改名）。
    两张卡（`Recommended ID Type` / `Other Options`）的白底、圆角 12、标题 16pt/700、
    行高 46、行间虚线（实 4 空 4、`rgba(189,189,162)`）都取自设计稿 CSS 与 Design Tokens。
    数据来自接口，不是客户端写死的清单：
    - 进页面用路由入参 `IdVerificationPageArguments.productId` 调
      `GET /outsulk/gaonate`（认证第一项），走 `CertificationRepository.getIdentityInfo`
      → `idVerificationProvider(productId)`。
    - 列表取响应里的 **`magisterial`**：两段字符串数组 `[[推荐...], [其他...]]`
      （文档示例 6 + 5 项），第一段对应设计稿 `Recommended ID Type`、第二段对应
      `Other Options`。划分依据是同一响应里 `wollongong` 的
      `unconversational` / `drumfish`（推荐 / 其他）示例用的就是同一批短码
      （`DRIVINGLICENSE` 在推荐、`TIN` 在其他）。**不要**改成从 `wollongong` 取列表。
    - 卡片文案**原样展示，客户端不做「短码 → 文案」映射**。
      ⚠️ 待联调确认：文档示例里 `magisterial` 是 `DRIVINGLICENSE` / `POSTALID` /
      `VOTERID` 这种短码，设计稿画的是 `DRIVER'S LICENSE` / `POSTAL  ID` / `Voter's ID`，
      而 `PHILIPPINE PASSPORT`、`UMID(Unified Multi-Purpose ID)` 这种文案前端推不出来。
      真机联调时先确认后端下发的是哪一种：如果下发短码，由后端补展示文案。
    - 三种状态齐全：请求中给 `LoadingView`；失败给 `ErrorView` + `Retry`
      （`ref.invalidate(idVerificationProvider(productId))`）；后端不下发证件
      （低版本 / 未灰度用户）时给空态文案，而不是画两张空卡片。
      Provider 按产品 id 缓存，同一产品反复进出页面不会重复请求。
    - 响应里这些字段暂未解析，等对应页面落地再接：`ceratin` / `acquirements`
      （已上传的身份证正面 / 活体）、`nonbuoyantly`、`wollongong`（每个卡类型的
      正确 / 错误示范图 `woodshock` / `indecisively`，上传页展示，按卡类型名与
      `magisterial` 的文案对应）、`befleas`（引导文案，低版本或未灰度用户不下发）。
    - ⚠️ Riverpod 3 默认对失败的 Provider 做指数退避重试（最多 10 次、单次最长 6.4s，
      见 `ProviderContainer.defaultRetry`）。这是**全 App 的容器级默认行为**（首页也一样），
      不是本页特有。要不要对业务失败关掉（`retry: (count, error) => null`）需要整体定，
      要改就统一改，别只改这一个 Provider。
    要点与已知差异：
    - 设计稿把卡片标题块和卡身拆成两个绝对定位元素，标题块底边压在卡身上 19pt
      （`text-wrapper_4` 的 `top: -19`）。代码按「标题块 + 卡身」竖排叠出同样效果，
      白卡顶边因此压住头图下沿 19pt；卡身在 CSS 里是 `border-radius: 0 0 12 12`，
      上圆角由标题块提供。
    - 行尾箭头（设计稿 5x9）在 `assets/` 里没有对应切图：`assets/common/chevron_right.png`
      是个人中心那套灰色箭头（7x11、`rgba(153,153,153)`），和设计稿的 `rgba(38,65,7)` 对不上，
      按仓库约定「没有的素材直接忽略也不硬凑」，改用 `CustomPainter` 按设计稿尺寸画，
      颜色走 `AppColors.idVerifyRowText`。行间虚线同理（Flutter 没有虚线边框）。
    - 选中证件后进上传页（`/id-upload`，见第 13 条）：压栈时带上 `productId` 与
      行文案（卡类型，也是保存接口 `heterological` 的取值）。
      这一页自己的正确 / 错误示范图暂时用的是设计稿切图；响应里 `wollongong` 的
      `woodshock` / `indecisively` 还没解析，等接口联调确认口径后再决定要不要改成下发。
    - 导航浮层固定在头图上、不随内容滚动：设计稿内容正好 812pt 一屏放得下，
      但小屏（< 812pt）滚动时返回按钮不能滚出屏幕。真机安全区比设计稿的
      状态栏（17pt + 21pt 间距）高，返回按钮落在「安全区 + 10pt」处，
      点击热区补到 40x40（设计稿只标了 24pt 图标）。
    - 设计稿里 `POSTAL  ID` / `TIN  ID` 是两个空格（`&nbsp;&nbsp;`）。文案现在由后端下发，
      前端不要做 `trim` / 空格替换，否则和设计稿对不上。

13. **证件上传页已按蓝湖稿 `03-01 - 身份认证-上传身份证` 还原**
    （认证流程第二步，`/id-upload`，`IdUploadPage`）。
    - 页面三段与设计稿一一对应：通栏头图（`section_1`，375x213）、上传引导整块
      （`section_3` + `group_1` 合起来 343x420）、底部 `Upload` 主按钮
      （`text-wrapper_4`，343x48 柠檬绿胶囊）。
    - 三个新素材都已按用途改名并登记到 `AppAssets`（`assets/id_verify/`）：
      `id_verify_header_blank.png`（用户提供的 `位图@3x.png`，和证件选择页的
      `id_verify_header.png` 是同一张渐变 + 吉祥物，**但没烘焙标题文字**，
      所以能复用给别的二级页；导航标题与引导段落由页面叠上去）、
      `id_verify_upload_demo.png`（`编组 14@3x.png`，`Demonstration` /
      `Wrong Demonstration` 两张白卡与三张错误示例全在这一张里）、
      `id_verify_upload_button.png`（`矩形@3x.png`，按钮底图）。
      返回按钮复用证件选择页的 `assets/common/back.png`。
    - `Upload` 按钮点击后从底部弹出上传方式面板（同一张蓝湖稿的
      `03-01 - 身份认证-选择上传方式`），`UploadMethodSheet`：`Camera` / `Album`
      两行各 57pt、中间 1pt 分隔线（`AppColors.actionSheetDivider`），`Quit` 前面垫
      8pt 灰色分组间隔带（`AppColors.actionSheetGap`）、行高 59pt
      （上下各 20pt 内边距 + 19pt 行高），面板通栏直角白底、遮罩
      `AppColors.dialogBarrier`。底部那 20pt 是真机上最容易漏掉的留白，
      所以面板包了 `SafeArea(top: false)` 补手势条、行高按 59 而不是 57 摆。
    - `Camera` / `Album` 已接「权限 -> 取图 -> 压缩 -> 上传」：
      相册走 PHPicker 不额外申请权限，相机先经 `IdentityPhotoPermission`；
      取图 / 压缩在 `lib/core/media/identity_photo.dart`（压缩按 1600/1200/900
      三档长边 + 质量依次尝试，命中 500KB 提前返回），页面不直接碰插件。
      上传走 `POST /outsulk/fashioned`（`CertificationRepository.uploadIdentityImage`，
      multipart 的字段名见 `ApiFields.upload*`）：固定 `liquidators=11`（身份证正面）、
      `chromogenous` 取相册 1 / 相机 2、`heterological` 取 `cardType`、文件字段 `attach`；
      `gargantua` / `musculopallial` / `bassein` / `sadomasochism` 这四个活体参数
      身份证正面用不到，但后端要求字段存在，固定带空串（对齐 peso_shield 的 uploadImage），
      **不要省略**。
      上传成功后进 `03-01 - 身份认证-上传成功` 页（见第 14 条）核对 OCR 结果，
      由那一页调用 `POST /outsulk/wardmote` 保存。
      新增依赖 `image_picker` / `permission_handler` / `flutter_image_compress` /
      `path_provider`，iOS 补了 `NSPhotoLibraryUsageDescription`，
      Podfile 里给 permission_handler 开了 `PERMISSION_CAMERA=1`。
    - 引导段落（`text_4`）优先用产品详情下发的 `overwhelming.splendacious`，
      由 `ProductApplicationFlow` 在拉详情时写入 `SessionStore` 的内存缓存，
      上传页读缓存、为空时回落到设计稿的四行兜底文案（204pt 宽下写死断行）。
      `overwhelming` 是「各认证页文案」容器，不能整段当字符串。
      **不要用身份信息响应里的 `befleas`**：接口文档确认引导文案属于产品详情。
    - 二级页的返回按钮 + 居中标题抽成了 `BackNavBar`（`lib/widgets/back_nav_bar.dart`），
      证件选择页与上传页共用，避免两份实现各自漂移。

14. **证件信息确认页已按蓝湖稿 `03-01 - 身份认证-上传成功` 还原**
    （认证流程第三步，`/id-confirm`，`IdConfirmPage`）。
    - 页面三段与设计稿一一对应：通栏头图（`section_1`，375x213，复用上传页那份
      没烘焙标题的 `id_verify_header_blank.png`）、白卡（`box_3`，343x396）、
      底部 `Upload` 主按钮（`text-wrapper_3`，343x48）。
    - 白卡里是证件照（`box_5`，319x200 + 12 圆角 + 2pt 白描边）与三行识别结果
      （`text-wrapper_4`，每行 48pt、`#F8F8F8` 底、4 圆角）：
      `Full Name` / `ID No.` / `Date of Birth`。**字段可编辑**（对齐 peso_shield
      的同名页）：OCR 会认错，姓名 / 证件号就地改，出生日期点开选择面板改。
      设计稿画的是只读态，这里保留灰底行样式、**不加输入框边框**。
    - 新素材 `assets/id_verify/id_verify_id_card.png`（用户提供的
      `p/sfz/right@3x.png`）已改名并登记为 `AppAssets.idVerifyIdCard`：
      后端回传证件照地址（`connectedly.superidealness`）时优先展示远端图，
      地址为空或加载失败才回落到这张设计稿切图。
    - 识别结果来自上传接口 `POST /outsulk/fashioned`（`type=11`）响应的
      `connectedly`，由 `IdentityRecognition.fromUploadResponse` 解析：
      `harbingers` 姓名 / `approach` 证件号 / `counter` 出生日期 /
      `superidealness` 证件照。`counter` 后端两种顺序都出现过：上传响应是
      `23/11/1993`（日在先），身份信息 `gaonate` 响应是 `1969/11/03`（年在先），
      页面统一归一成保存接口要的 `dd-MM-yyyy`（`IdentityRecognition.normalizeBirthDate`
      先按「第一段 4 位就是年」解析、再用 `DateTime` 回读校验，2 月 30 日这类
      不存在的日期原样透传交给用户改）。
    - 点 `Upload` 走 `POST /outsulk/wardmote`
      （`CertificationRepository.saveIdentityInfo`）：`liquidators=11`、
      `heterological` 取证件选择页的行文案、三个识别字段原样回传，
      另带随机混淆字段 `stith`。三个字段任一为空时页面直接提示
      `Please complete all fields`，不发坏请求。
      保存成功后交给 `ProductApplicationFlow.continueProductDetailFlow` 继续下一步。
    - 出生日期选择面板按蓝湖稿 `03-02 - 个人信息-日期选择` 还原：
      375x307 白面板 + 16pt 顶部圆角，右上角只有灰色 `Done`（没有 `Cancel`，
      点遮罩关闭），下面是日 / 月 / 年三列滚轮。滚轮行高 52.5、可视高 234、
      选中行加粗加深（`#0D1B17`），相邻行 `#666666`、再往外 `#999999`，
      选中行上下各一条 1pt `#EEEEEE` 分隔线，两侧留 68 / 59。
      换月 / 换年后会把日收进当月范围（2 月没有 30 号），拨动前先夹住下标，
      避免 `ListWheelScrollView` 在新 childCount 下断言失败。
    - 引导段落（`text_4`）优先用产品详情下发的 `overwhelming.bocking`
      （与上传页的 `splendacious` 同容器但不同字段，别混用），
      由 `ProductApplicationFlow` 写入 `SessionStore`，为空时回落到设计稿的
      三行兜底文案（190pt 宽下写死断行）。
    - `Upload` 按钮抽成了共用组件 `lib/widgets/upload_button.dart`
      （底图 + 文案 + 水波纹），上传页与确认页共用，避免两份实现各自漂移。

15. **人脸识别页已按蓝湖稿 `03-01 - 身份认证-人脸识别` 还原**
    （认证流程第四步，`/face-verification`，`FaceVerificationPage`）。
    - 页面结构与证件上传页一致：通栏头图（复用 `id_verify_header_blank.png`）、
      引导段落、示范整块切图（343x420）、底部 `Upload` 主按钮（343x48 柠檬绿胶囊）。
      设计稿实测：示范图顶边 194（压在头图下 19pt）、示范图到按钮 100pt、
      按钮下沿到页底 50pt，与上传页同口径。
    - 新素材已按用途改名并登记到 `AppAssets`（`assets/id_verify/`）：
      `face_verify_demo.png`（用户提供的 `编组 12@3x.png`，343x420）——
      `Demonstration` 正确示范（绿色取景框 + 面部轮廓）与 `Wrong Demonstration`
      三张错误示例（`Unclear` / `With reflection` / `Incomplete`）整块烘焙在一张里。
      返回按钮复用 `assets/common/back.png`，主按钮复用共用组件
      `lib/widgets/upload_button.dart`（文案沿用设计稿的 `Upload`）。
    - 引导段落（`text_4`，193pt 宽 / 16pt Helvetica-Bold）优先用产品详情下发的
      `overwhelming.seisin`（文档语义 `livness`，是「活体认证页面顶部文案」）。
      **别和上传页的 `splendacious`、确认页的 `bocking` 混用**：三条同属
      `overwhelming` 容器但各认证页一条，`ProductApplicationFlow` 在拉详情时
      写进 `SessionStore`，为空时回落到设计稿的三行兜底文案。
    - 点 `Upload` 的完整链路：
      1. `POST /outsulk/carline`（`CertificationRepository.getFaceToken`）取活体
         授权码，参数 `resex` 订单号 / `liquidators` 类型 + 两个随机混淆字段；
         响应 `gravel` 是结果码：`200` 继续、`400` 弹「重新上传身份证」确认框
         （确认后回 `/id-verification`）、其余按 `instellation` / `norseled` 提示。
      2. 授权码交给 `LivenessGateway`（`lib/core/face/liveness_gateway.dart`）
         经 method channel `laya_credit/client_bridge` 的
         `showTrustDecisionLiveness` 拉起 TrustDecision SDK；原生实现在
         仓库里早已就位（`ios/Runner/TrustDecisionRegistrar.swift`）。
      3. SDK 返回的抓拍图（base64）落到临时文件（同步写：人脸图不大，
         同步写能让这段流程不依赖事件循环），再走
         `POST /outsulk/fashioned`（`uploadFaceImage`，`liquidators=10`、
         `chromogenous=1`、`heterological` 空串、`gargantua` 带 livenessId、
         `musculopallial` 带授权码、`bassein` 带活体类型），上传完删临时文件。
      4. 成功后交给 `ProductApplicationFlow.continueProductDetailFlow`
         继续下一步认证（`Reargued` 之外的认证项）。
    - 相机权限在取 token 前预检（口径对齐 peso_shield）：复用
      `IdentityPhotoPermission.ensureCameraForLiveness`，先查当前状态，未授权再
      `request`，被拒时弹「Enable Camera to Continue」引导去系统设置，
      不浪费一次 token 请求；`Info.plist` 里的相机说明保持不变。
    - 订单号由 `ProductApplicationFlow` 从产品详情 `basicInfo.orderNo` 带进页面
      （token 接口的 `resex`），页面不再自己拉一次产品详情。
    - 测试通过 `livenessGatewayProvider` 注入假网关，覆盖「通过 / 未通过 /
      token 400」三条分支，并 mock `permission_handler` channel 覆盖
      「权限被拒弹引导」；`FaceVerificationPage` 不直接依赖 `MethodChannel`。

16. **个人信息认证页已按蓝湖稿 `03-02-认证-个人信息` 还原**
    （`/personal-info`，`PersonalInfoPage`，认证项 `taskType`
    `FlintiestDevwsor`）。
    - 页面分三段：通栏头图（**复用证件上传页的 `id_verify_header_blank.png`**：
      经与设计稿逐像素比对，渐变与吉祥物位置完全一致，不需要再切一张）、
      白卡（343 宽，卡顶是带 `25%` 的粉红进度缎带）、底部**固定**操作条
      （白底 + 上方 `0 -5px 6px rgba(233,233,233,0.5)` 投影 +
      343x48 柠檬绿 `Upload`，按钮下方留安全区）。
      新增素材只有两张（`assets/personal_info/`）：`personal_info_progress_ribbon.png`
      （用户提供的 `编组@3x.png`，343x33：粉红缎带 + 白卡顶部两角，
      `25%` 文案由页面叠在中央）与地址面板的 `personal_info_sheet_close.png`（24x24）。
    - 设计稿实测：缎带顶边 185（压在白卡顶边 192 上方 7pt）、白卡内容顶边 218、
      第一个字段标题顶边 228；字段=标题 22pt + 8pt + 取值行 48pt，字段间距 16pt
      （即 94pt 一节）；取值行 319 宽、`padding: 14 0`、行底 1pt `#EEEEEE` 分隔线
      （最后一行不画）；行尾 6x10 箭头用 `CustomPainter` 还原（`#181C17`）。
    - **表单字段不写死**：`POST /outsulk/orchel`（`CertificationRepository.getPersonalInfo`）
      下发 `aminate[]`，每个字段带 `upbear` 标题 / `amias` 占位 / `crucians` 业务 key /
      `lipson` 控件类型 / `lazy` 数字键盘 / `overwhelming` 选项 / `fed` 当前值。
      控件类型两套命名都认（`Obesity|enum|stepped`=枚举、`Ori|txt|onto`=输入框、
      `CumingsAgami|citySelect|stage`=地址选择，见 `PersonalInfoControl`）；
      未知类型退化成只读行，不渲染成不可用的输入框。
    - 交互（口径对齐 peso_shield）：枚举字段弹 `showPersonalInfoOptionSheet`
      （`Done` 回填展示文案，提交 `liquidators`；**面板每次打开都从第一项开始，
      不回填当前值**）；地址字段先拉
      `GET /outsulk/avern`（同页缓存一次）再弹 `showPersonalInfoAddressSheet`，
      逐层点选，返回 `省-市-区` 拼好的完整地址；`Upload` 把每个字段的 `crucians`
      当 key 回传 `POST /outsulk/marantas`（带 `rhus` / `downlie` 两个混淆字段），
      成功后交给 `ProductApplicationFlow.continueProductDetailFlow` 走下一步。
    - 引导文案优先级：产品详情 `overwhelming.deerherd`（文档语义 `person`）
      → 表单接口 `befleas` → 设计稿四行兜底。`deerherd` 与上传页 `splendacious`、
      确认页 `bocking`、人脸页 `seisin` 同属 `overwhelming` 容器，不能互相顶替。
    - **已知偏差**：进度文案 `25%` 目前写死——接口文档没有下发进度的字段，
      设计稿就是这个值，接入进度接口后再换成下发值；`Upload` 按钮文案沿用共用组件
      `lib/widgets/upload_button.dart`（16pt/500），设计稿该页标注是 14pt/700。

17. **工作信息认证页已按蓝湖稿 `03-03 - 工作信息` 还原**
    （`/work-info`，`WorkInformationPage`，认证项 `taskType`
    `TrussvilleUninstructively`）。
    - **与个人信息页共用同一套 UI**：`WorkInformationPage` 继承
      `PersonalInfoPage`（`PersonalInfoPage.work` 构造），头图 / 进度缎带 / 动态
      字段表单 / 底部 `Upload` 条全部复用，不复制第二份布局；
      只有导航标题（`Job information`）、进度文案（`50%`）、引导段排版
      （宽 164 / 字号 14 / 行高 17 / 距导航行 8）与数据源按形态切换。
    - **素材直接复用个人信息页那两张**：头图 `id_verify_header_blank.png`、
      进度缎带 `personal_info_progress_ribbon.png`——两张设计稿 PNG 的缎带
      粉红区域逐像素比对完全一致（185~218，375 空间 x 103.5~271.5），
      工作信息稿只是把文案换成 `50%`，不需要新切图。
    - **字段同样不写死**：`GET /outsulk/timeling`
      （`CertificationRepository.getWorkInfo`）返回与个人信息同一份 `aminate[]`
      字段结构，所以直接复用 `PersonalInfoData` 与
      `personal_info_option_sheet` / `personal_info_address_sheet`；
      `Upload` 把每个字段的 `crucians` 当 key 回传 `POST /outsulk/kneeing`
      （带 `knucks` / `normothermic` / `taxibus` 三个混淆字段），
      成功后同样交给 `ProductApplicationFlow.continueProductDetailFlow`。
    - **发薪日（`Payday`，`crucians=opportunities`）是二级选项字段**，单独处理：
      一级是发薪周期（`Daily` / `Weekly` / `Twice per Month` / `Once a Month`），
      每个周期自己再带一组下级选项（周几 / 每月几号），下级数组与一级同用
      `overwhelming`。`PersonalInfoOption.children` 解析这层嵌套，
      `PersonalInfoField.hasNestedOptions` 标记这类字段；页面上先弹一次面板选周期，
      有下级再弹一次选具体日期（复用同一张 `personal_info_option_sheet`，
      本项目蓝湖没有单独出这张面板，沿用 `03-02 - 个人信息-日期选择` 的面板家族）。
      行上展示 `周期|发薪日`，提交接口的是**二级**的 `liquidators`
      （接口文档 `fed: "Once a Month|1"` 的口径，对齐 peso_shield 的
      `PersonalInformationPaydaySheet` 行为，但用本项目已有的滚轮面板实现）。
      两个面板同样不预选（见第 16 条，行上仍按接口 `fed` 展示已保存的值），
      对齐 peso_shield 重开时停在顶部的行为。
    - 引导文案优先级：产品详情 `overwhelming.ssn`（文档语义 `work`）
      → 表单接口 `befleas` → 设计稿五行兜底；`ssn` 与其他认证页文案同属
      `overwhelming` 容器，不能互相顶替。
    - **已知偏差**：与个人信息页一样，进度文案 `50%` 先按设计稿写死；
      白卡内容顶边沿用个人信息页的 228，工作信息稿设计标注是 230（差 2pt，肉眼不可辨）。

## 常用命令

```bash
flutter pub get                      # 安装依赖
flutter analyze                      # 静态分析
dart format .                        # 格式化
flutter test                         # 全部测试
flutter test test/widget_test.dart   # 单个测试文件
flutter build ios --debug --no-codesign   # iOS 编译自检
```

## 提交约定

- 一个 Task 只解决一个 Feature 或 Bug，完成重大修改后提交一次。
- 禁止在未沟通的情况下删除 Proguard 混淆规则或安全配置。
- 禁止引入 Beta 版第三方库；新增依赖前先做依赖审计。
- 禁止在注释或代码中泄露 D-U-N-S 编号、公司注册号等敏感信息。
