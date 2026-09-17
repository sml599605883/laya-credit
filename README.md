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
以及认证流程的二级页 `/id-verification`（证件选择，见第 12 条）。

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
4. **其余接口未接入**：认证项、订单、上报、H5 相关接口尚未落地。
   「点击申请」链路已接通到准入接口，但下游页面仍缺：准入 / 详情返回的
   H5 地址需要 WebView、认证项需要活体 / 个人信息 / 工作 / 紧急联系人 / 绑卡页、
   原生 `recredit` 需要重新授信 loading 页。相关分支见
   `lib/core/product/product_application_flow.dart` 的 TODO(页面)。
   认证项里的身份认证（`Kegful`）已接上证件选择页（见第 12 条），
   证件上传页仍然缺。
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
    要点与已知差异：
    - 设计稿把卡片标题块和卡身拆成两个绝对定位元素，标题块底边压在卡身上 19pt
      （`text-wrapper_4` 的 `top: -19`）。代码按「标题块 + 卡身」竖排叠出同样效果，
      白卡顶边因此压住头图下沿 19pt；卡身在 CSS 里是 `border-radius: 0 0 12 12`，
      上圆角由标题块提供。
    - 行尾箭头（设计稿 5x9）在 `assets/` 里没有对应切图：`assets/common/chevron_right.png`
      是个人中心那套灰色箭头（7x11、`rgba(153,153,153)`），和设计稿的 `rgba(38,65,7)` 对不上，
      按仓库约定「没有的素材直接忽略也不硬凑」，改用 `CustomPainter` 按设计稿尺寸画，
      颜色走 `AppColors.idVerifyRowText`。行间虚线同理（Flutter 没有虚线边框）。
    - 证件清单是客户端固定文案（设计稿写死的），不请求接口，所以页面没有
      Loading / Error / Empty 态，与个人中心同一套判断。
    - 选中证件后的上传页（正面 / 反面 + 拍摄引导）尚未搭建，点击先给占位提示；
      `product_application_flow.dart` 里 `taskType == 'Kegful'` 会直接压栈这一页。
      上传接口按产品维度取资料，补齐时再把 `productId` 透传过来，现在页面不吃参数。
    - 导航浮层固定在头图上、不随内容滚动：设计稿内容正好 812pt 一屏放得下，
      但小屏（< 812pt）滚动时返回按钮不能滚出屏幕。真机安全区比设计稿的
      状态栏（17pt + 21pt 间距）高，返回按钮落在「安全区 + 10pt」处，
      点击热区补到 40x40（设计稿只标了 24pt 图标）。
    - 证件文案里的 `POSTAL  ID` / `TIN  ID` 是两个空格，来自设计稿的 `&nbsp;&nbsp;`，
      不要顺手改成一个空格。

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
