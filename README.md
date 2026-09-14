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

目前注册的路由：`/`（Tab 容器）、`/home`、`/stats`、`/mine`、`/login`。

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
5. **页面视觉待补齐**：现有设计切图不完整（只有首页、首页空态、个人中心的部分元素），页面目前是结构骨架 + 真实切图，未做像素级还原。
6. **底部导航** 已按蓝湖稿还原为悬浮胶囊（200x48）+ 三个 40pt 圆形按钮，选中态为柠檬绿实心圆；
   设计稿没有文字标签，代码里只保留 `Semantics` 文案。**Stats 页的定位**仍需与设计确认。
7. **消息 / 客服 / 隐私政策等二级页面** 尚未搭建，当前点击只弹占位提示。
8. **首页头图的问候语**：蓝湖稿 02-01 顶部是用户名（`Maya Agad`），接口当前没有下发昵称，
   先用品牌名 `Laya Credit` 顶位，等账号接口给出昵称字段再替换。
   另外设计稿 `section_2` 底部的 `image_4`（借款流程插画 200x48）与 `image_5`（产品资质 134x5）
   在设计图里被底部 Tab 栏遮住、不可见，暂未渲染，需与设计确认这两块是否要露出。

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
