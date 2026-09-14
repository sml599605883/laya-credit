# CLAUDE.md

本文件为在本仓库工作的 AI 助手提供上下文。通用编码准则见根目录 `AGENTS.md`。

## 项目现状

菲律宾借贷**撮合/推荐**类 App（Flutter，仅 iOS，无 `android/` 目录）。
基础搭建已完成：路由（命名路由集中式）、状态管理（Riverpod）、主题与设计令牌、
网络层（含签名与公共参数）、登录态会话层、底部三 Tab 容器。
短信验证码 / 登录 / 退出登录 / 首页 / 个人中心 / banner 点击上报已按接口文档实现，
等后端提供域名（`apiBase`）后即可联调。

详见 `README.md` 的「基础搭建已完成的部分」与「待接入 / 待确认」两节。

## 关键约定（改代码前先看）

- 路由：只写 `AppNavigator.push(AppRoutes.xxx)`，路由名集中在 `lib/core/navigation/app_routes.dart`，
  新增页面必须在 `AppRouteGenerator` 注册。
- 状态：Riverpod。`ref.watch` 订阅、事件回调里用 `ref.read`；
  分层为 Page → Provider → Repository → HttpClient，页面不直接依赖 Dio。
- 设计令牌：颜色走 `AppColors`，间距走 `AppSpacing`（8pt 整数倍），
  尺寸用 `AppLayout.of(context).px(...)` 换算，切图走 `AppAssets`。禁止硬编码 Hex 与裸像素。
- 金额：禁止浮点运算，用 `Decimal` 或「分」为单位的整型；展示必须千分位格式化。
- 到期日：以 `origin_end_time` 为准。
- 每个 API 调用必须处理 Loading / Error / Empty，异常收敛为 `ApiException`，不允许闪退。
- 禁止引入 Beta 版依赖；禁止泄露 D-U-N-S 编号、公司注册号等敏感信息。

## 待确认项（改动前先与需求方对齐）

- `lib/core/config/api_environment.dart` 的 `apiBase` 仍是占位值（接口文档「测试环境地址」为空）；
  签名密钥与渠道标识已按文档填好。
- 接口文档项目 `ph_laya_credit_ios`（见 `.codex/project.toml` 的 `API_PREFIX`）：字段名是混淆串，
  写错只会静默读到 `null`，新增字段必须先查文档 `7.map.html` 并登记到 `ApiFields`。
- 首页 / 个人中心页面的视觉细节依赖完整设计稿，现为结构骨架。
- 底部导航标签文案、Stats 页定位待设计确认。

## 常用命令

- 安装/更新依赖：`flutter pub get`
- 静态分析：`flutter analyze`
- 格式化：`dart format .`
- 运行全部测试：`flutter test`
- 运行单个测试：`flutter test test/widget_test.dart`
- iOS 编译自检（不需要签名）：`flutter build ios --debug --no-codesign`

## Dart / 工具链注意事项

- `pubspec.yaml` SDK 约束为 `^3.13.3`；本地 Flutter 3.47.4 / Dart 3.13.3。
- `assets/` 下的 `*_slices` 目录是蓝湖原始导出，不要删除，也不要注册进 `pubspec.yaml`。



[mcp.api-doc.env]
API_PREFIX = "ph_laya_credit_ios"