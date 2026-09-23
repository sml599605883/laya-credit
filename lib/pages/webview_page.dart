import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/client/client_bridge.dart';
import '../core/navigation/app_deep_link.dart';
import '../core/navigation/navigation.dart';
import '../core/report/report.dart';
import '../core/ui/toast_helper.dart';
import '../core/webview/webview_action_coordinator.dart';
import '../core/webview/webview_contract.dart';
import '../providers/network_provider.dart';
import '../providers/repository_provider.dart';
import '../theme/theme.dart';
import '../widgets/back_nav_bar.dart';
import '../widgets/state_views.dart';
import 'loan_confirm_page.dart';

/// WebView 内联放行的 scheme：这些交给 WebView 自己处理，
/// 其余（tel / mailto / 第三方 App 等）交给系统或内部路由。
bool isInlineWebViewScheme(String scheme) => switch (scheme.toLowerCase()) {
  'http' || 'https' || 'about' || 'data' || 'javascript' || 'file' => true,
  _ => false,
};

/// 无可回退历史时，返回键应该关闭页面而不是继续回退。
bool shouldCloseWebView({required bool canGoBack}) => !canGoBack;

/// iOS 下禁用长按菜单 / 链接预览，避免用户长按图片弹出系统菜单。
bool shouldDisableWebViewContextMenu(TargetPlatform platform) =>
    platform == TargetPlatform.iOS;

/// iOS 上兜底禁用图片长按选择（部分 H5 会覆盖 CSS）。
const String iosImageLongPressPreventionScript = r'''
(() => {
  const style = document.createElement('style');
  style.textContent = `
    img {
      -webkit-touch-callout: none !important;
      -webkit-user-select: none !important;
      user-select: none !important;
    }
  `;
  (document.head || document.documentElement).appendChild(style);

  document.addEventListener('contextmenu', (event) => {
    const target = event.target;
    if (target instanceof Element && target.closest('img')) {
      event.preventDefault();
    }
  }, true);
})();
''';

UnmodifiableListView<UserScript>? webViewInitialUserScripts(
  TargetPlatform platform,
) {
  if (platform != TargetPlatform.iOS) return null;
  return UnmodifiableListView<UserScript>([
    UserScript(
      source: iosImageLongPressPreventionScript,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: false,
    ),
  ]);
}

/// 判断能否用 `history.go(-1)` 回退单页应用的历史。
///
/// H5 的 hash 路由（`#/a` -> `#/b`）在 WebView 里是同一条历史记录，
/// `goBack()` 会直接退出整个页面；同文档的 fragment 变化才用 JS 回退。
class WebViewBackHistory {
  WebViewBackHistory._();

  static bool shouldUsePageHistoryGo(WebHistory? history) {
    final currentItem = _currentItem(history);
    final previousItem = _previousItem(history);
    if (currentItem == null || previousItem == null) {
      return false;
    }
    final currentUri = Uri.tryParse(currentItem.url?.toString() ?? '');
    final previousUri = Uri.tryParse(previousItem.url?.toString() ?? '');
    if (currentUri == null || previousUri == null) {
      return false;
    }
    return currentUri.fragment.isNotEmpty &&
        previousUri.fragment.isNotEmpty &&
        currentUri.removeFragment() == previousUri.removeFragment();
  }

  static WebHistoryItem? _currentItem(WebHistory? history) {
    final currentIndex = history?.currentIndex;
    final items = history?.list;
    if (currentIndex == null ||
        items == null ||
        currentIndex < 0 ||
        currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex];
  }

  static WebHistoryItem? _previousItem(WebHistory? history) {
    final currentIndex = history?.currentIndex;
    final items = history?.list;
    if (currentIndex == null ||
        items == null ||
        currentIndex <= 0 ||
        currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex - 1];
  }
}

/// 只有主框架加载失败才算页面失败，子资源失败不弹整页错误。
bool shouldShowWebViewLoadError({required bool? isForMainFrame}) =>
    isForMainFrame == true;

/// H5 加载出标题前用 [fallback] 兜底。
String resolveWebViewTitle({
  required String? pageTitle,
  required String fallback,
}) {
  final value = pageTitle?.trim() ?? '';
  return value.isNotEmpty ? value : fallback.trim();
}

/// await 之后校验控制器是否仍是当前页面的控制器，避免跨页串写。
bool canUseWebViewController({
  required bool mounted,
  required Object? activeController,
  required Object? controller,
}) =>
    mounted &&
    activeController != null &&
    identical(activeController, controller);

/// H5 的「返回保留确认」路径。
///
/// TODO(混淆串): 路径段与参数名待接口文档确认后替换
/// （dali 用 `Florescences` + `thunderstruck`）。当前占位值下不会命中，
/// 命中时也只打日志、继续正常返回（本项目暂不做保留弹窗）。
const String webViewConfirmPathSegment = 'RetentionConfirm';
const String webViewConfirmProductKey = 'productId';

String webViewConfirmProductId(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return '';
  final fragmentUri = Uri.tryParse(uri.fragment);
  final directConfirm = uri.pathSegments.contains(webViewConfirmPathSegment);
  final fragmentConfirm =
      fragmentUri?.pathSegments.contains(webViewConfirmPathSegment) == true;
  if (!directConfirm && !fragmentConfirm) return '';
  final direct = uri.queryParameters[webViewConfirmProductKey]?.trim() ?? '';
  if (direct.isNotEmpty) return direct;
  return fragmentUri?.queryParameters[webViewConfirmProductKey]?.trim() ?? '';
}

/// 需要回调时拼出 `window.<handler>.handleMessage(...)` 脚本。
String? webViewCallbackScript(WebViewRequest request, WebViewResult result) {
  if (!request.expectsCallback) return null;
  final payload = jsonEncode(<String, Object?>{
    'callbackId': request.callbackId,
    'data': result.data,
  });
  return 'window.${WebViewContract.handler}.handleMessage($payload);';
}

/// 前后台切换时注册 / 注销 JS handler。
///
/// WebView 进后台仍持有 handler 会让 H5 在暂停期间继续发消息，
/// 这里跟随 App 生命周期开关。
class WebViewBridgeGate {
  WebViewBridgeGate({required this.addHandler, required this.removeHandler});

  final void Function(Object controller) addHandler;
  final void Function(Object controller) removeHandler;
  Object? _controller;
  bool _foreground = true;
  bool _registered = false;

  void attach(Object controller) {
    detach();
    _controller = controller;
    _sync();
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _sync();
  }

  void detach() {
    final controller = _controller;
    if (controller != null && _registered) {
      removeHandler(controller);
    }
    _registered = false;
    _controller = null;
  }

  void _sync() {
    final controller = _controller;
    if (controller == null || _foreground == _registered) return;
    if (_foreground) {
      addHandler(controller);
      _registered = true;
    } else {
      removeHandler(controller);
      _registered = false;
    }
  }
}

/// 通用 H5 页面：协议、客服、订单详情、准入返回的 web 链接都走这里。
///
/// 承载 `flutter_inappwebview` 与 JS 桥（见 [WebViewContract]），
/// action 的业务分发在 [WebViewActionCoordinator]，页面只做状态与生命周期。
class WebViewPage extends ConsumerStatefulWidget {
  const WebViewPage({super.key, required this.initialUrl, this.initialTitle});

  final String initialUrl;
  final String? initialTitle;

  @override
  ConsumerState<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends ConsumerState<WebViewPage>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  late final WebViewActionCoordinator _coordinator;
  late final WebViewBridgeGate _bridgeGate;
  late String _title;
  bool _loading = true;
  bool _loadFailed = false;

  Uri? get _initialUri => AppNavigator.webViewUri(widget.initialUrl);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title = resolveWebViewTitle(
      pageTitle: widget.initialTitle,
      fallback: 'Details',
    );
    _bridgeGate = WebViewBridgeGate(
      addHandler: (value) {
        (value as InAppWebViewController).addJavaScriptHandler(
          handlerName: WebViewContract.handler,
          callback: _handleBridgeCall,
        );
      },
      removeHandler: (value) {
        (value as InAppWebViewController).removeJavaScriptHandler(
          handlerName: WebViewContract.handler,
        );
      },
    );
    _coordinator = _buildCoordinator();
  }

  WebViewActionCoordinator _buildCoordinator() {
    return WebViewActionCoordinator(
      // H5 的 `uploadRisk`（确认用款 / 结束申贷）动作：场景 10，开始时间由 H5 下发。
      reportRisk:
          ({
            required productId,
            required orderNo,
            required startedAtSeconds,
          }) async {
            await ReportService.current?.reportRisk(
              productId: productId,
              scene: '10',
              orderNo: orderNo,
              startedAtSeconds: startedAtSeconds,
            );
          },
      openWebView: (url) async {
        await AppNavigator.toWebView<void>(url: url);
      },
      navigateInternal: _navigateInternal,
      openExternal: _openExternal,
      closePage: () async => AppNavigator.pop<void>(),
      jumpHome: () async => AppNavigator.popToRoot(),
      requestAppReview: ClientBridge().requestAppReview,
      buildPublicParams: (path) async {
        final client = await ref.read(httpClientProvider.future);
        return client.buildSignedQuery(path);
      },
      retryOrder: _retryOrderConfirm,
      changeAccount: _changeOrderAccount,
      reloadOrOpenWebView: _reloadOrOpenWebView,
      showLoading: () async {
        ToastHelper.showLoading();
      },
      dismissLoading: () async {
        ToastHelper.hideLoading();
      },
      showError: (message) async => ToastHelper.showError(message),
      logger: debugPrint,
    );
  }

  /// H5（订单详情页）请求「更换打款账户」。
  ///
  /// 进原生账号列表选一笔（页面自己拉账户、自己换绑，再把订单详情页地址回过来）；
  /// 用户点「新增账户」则进绑卡页的改卡模式，拿它 pop 回来的地址。
  /// 两条分支都用一个**全新的 WebView 路由**接上结果地址，而不是在当前
  /// controller 上 `loadUrl`——否则 H5 历史里还留着换绑前的订单详情，返回会回到
  /// 过期页。口径对齐 fund_nexus 的 `_replaceAccountChangeFlow`
  /// 与 peso_shield 的 `_replaceCurrentWebView`。
  ///
  /// 注意：协调器在 action 执行期间会挂跨页 Loading（`ToastHelper.showLoading`
  /// 是 `allowClick: false`），而账号列表要等用户选完、绑卡页要等用户填完才会
  /// pop；所以这里**不能**等交互结果，push 完立刻把 Future 交回协调器，
  /// 否则 Loading 遮罩会把账号列表页整个挡住。口径对齐 fund_nexus 的
  /// `unawaited(push(...))`。
  Future<void> _changeOrderAccount({
    required String productId,
    required String orderNo,
  }) {
    unawaited(_changeOrderAccountFlow(productId: productId, orderNo: orderNo));
    return Future<void>.value();
  }

  Future<void> _changeOrderAccountFlow({
    required String productId,
    required String orderNo,
  }) async {
    final result = await AppNavigator.push<LoanConfirmResult>(
      AppRoutes.loanConfirm,
      arguments: LoanConfirmPageArguments(
        productId: productId,
        orderNo: orderNo,
      ),
    );
    if (!mounted || result == null) return;

    final String url;
    if (result is LoanConfirmAddPaymentMethod) {
      final changed = await AppNavigator.push<String>(
        AppRoutes.bindCard,
        arguments: BindCardPageArguments(
          productId: productId,
          orderNo: orderNo,
          isAccountChange: true,
        ),
      );
      if (!mounted || changed == null || changed.trim().isEmpty) return;
      url = changed;
    } else {
      url = (result as LoanConfirmAccountChanged).url;
    }

    await _replaceWithWebView(url);
  }

  /// 换绑成功后，用一个全新的 WebView 路由接上订单详情地址。
  ///
  /// 账号列表页与绑卡页在完成时都已自行 pop，这里只要把栈顶的旧 WebView
  /// 替换成新页即可（历史重置，返回不会落回过期的换绑流程）。
  Future<void> _replaceWithWebView(String rawUrl) async {
    final uri = AppNavigator.webViewUri(rawUrl);
    if (uri == null) {
      debugPrint('[WebView] 换绑结果地址非法: $rawUrl');
      return;
    }
    await AppNavigator.replace<void>(
      AppRoutes.webView,
      arguments: WebViewPageArguments(url: uri.toString()),
    );
  }

  /// 原卡重试确认订单（H5 桥 `retryOrderDialog`）。
  ///
  /// 调 `POST /outsulk/resex` 拿订单详情页地址，交给 `reloadOrOpenWebView`
  /// 在当前 WebView 里打开（口径对齐 dali 的 retryOrder）。
  Future<String> _retryOrderConfirm(String orderNo) async {
    final repository = await ref.read(certificationRepositoryProvider.future);
    final response = await repository.retryOrderConfirm(orderNo: orderNo);
    if (!response.isSuccess) {
      throw WebViewActionException(response.message);
    }
    return response.data.trim();
  }

  Future<void> _navigateInternal(String raw) async {
    final link = const AppDeepLinkParser().parse(raw);
    await AppNavigator.openDeepLink(
      link,
      onUnhandled: (target) {
        debugPrint('[WebView] 暂不支持的内部跳转: ${target.raw}');
      },
    );
  }

  Future<bool> _openExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('[WebView] 打开外部链接失败: $error');
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _bridgeGate.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _bridgeGate.detach();
    _controller = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<dynamic> _handleBridgeCall(List<dynamic> arguments) async {
    final controller = _controller;
    if (!canUseWebViewController(
      mounted: mounted,
      activeController: _controller,
      controller: controller,
    )) {
      return const WebViewResult.failure('WebView is inactive').toJson();
    }
    final request = WebViewRequest.decode(
      arguments.isEmpty ? null : arguments.first,
    );
    final result = await _coordinator.dispatch(request);
    final script = webViewCallbackScript(request, result);
    if (script != null &&
        canUseWebViewController(
          mounted: mounted,
          activeController: _controller,
          controller: controller,
        )) {
      await _safeControllerCall(
        'handleMessage',
        () => controller!.evaluateJavascript(source: script),
      );
    }
    return result.toJson();
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    var canGoBack = false;
    var currentUrl = widget.initialUrl;
    if (controller != null &&
        canUseWebViewController(
          mounted: mounted,
          activeController: _controller,
          controller: controller,
        )) {
      canGoBack =
          await _safeControllerCall('canGoBack', controller.canGoBack) ?? false;
      if (!canUseWebViewController(
        mounted: mounted,
        activeController: _controller,
        controller: controller,
      )) {
        return;
      }
      currentUrl =
          (await _safeControllerCall(
            'getUrl',
            controller.getUrl,
          ))?.toString() ??
          currentUrl;
    }

    // TODO(页面): 保留确认弹窗尚未搭建，命中时先打日志、继续正常返回。
    final confirmProductId = webViewConfirmProductId(currentUrl);
    if (confirmProductId.isNotEmpty) {
      debugPrint('[WebView] 命中返回保留确认(productId=$confirmProductId)，暂不拦截');
    }
    await _completeBack(controller: controller, canGoBack: canGoBack);
  }

  Future<void> _completeBack({
    required InAppWebViewController? controller,
    required bool canGoBack,
  }) async {
    if (!shouldCloseWebView(canGoBack: canGoBack) && controller != null) {
      await _goBackOneHistoryEntry(controller);
      return;
    }
    if (mounted) AppNavigator.pop<void>();
  }

  Future<void> _goBackOneHistoryEntry(InAppWebViewController controller) async {
    if (!canUseWebViewController(
      mounted: mounted,
      activeController: _controller,
      controller: controller,
    )) {
      return;
    }
    final history = await _safeControllerCall(
      'getCopyBackForwardList',
      controller.getCopyBackForwardList,
    );
    if (!canUseWebViewController(
      mounted: mounted,
      activeController: _controller,
      controller: controller,
    )) {
      return;
    }
    if (WebViewBackHistory.shouldUsePageHistoryGo(history)) {
      await _safeControllerCall(
        'history.go',
        () => controller.evaluateJavascript(source: 'window.history.go(-1);'),
      );
      return;
    }
    await _safeControllerCall('goBack', controller.goBack);
  }

  /// 控制器可能已被释放（平台视图销毁 / 原生插件不可用），
  /// 或者原生方法缺失。这里把调用失败收敛为 `null`，由调用方取安全默认值，
  /// 保证返回键等交互不会因为一个平台异常把金融页打崩。
  Future<T?> _safeControllerCall<T>(
    String method,
    Future<T> Function() call,
  ) async {
    try {
      return await call();
    } catch (error) {
      debugPrint('[WebView] 控制器方法 $method 调用失败: $error');
      return null;
    }
  }

  Future<NavigationActionPolicy> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.CANCEL;
    if (isInlineWebViewScheme(uri.scheme)) {
      return NavigationActionPolicy.ALLOW;
    }
    if (uri.scheme == 'ph') {
      await _navigateInternal(uri.toString());
    } else {
      await _openExternal(uri);
    }
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _retry() async {
    final uri = _initialUri;
    final controller = _controller;
    if (uri == null || controller == null) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    await _safeControllerCall(
      'loadUrl',
      () => controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri))),
    );
  }

  Future<void> _reloadOrOpenWebView(String rawUrl) async {
    final uri = AppNavigator.webViewUri(rawUrl);
    final controller = _controller;
    if (uri == null ||
        !canUseWebViewController(
          mounted: mounted,
          activeController: _controller,
          controller: controller,
        )) {
      return;
    }
    final currentUri = await _safeControllerCall('getUrl', controller!.getUrl);
    if (!canUseWebViewController(
      mounted: mounted,
      activeController: _controller,
      controller: controller,
    )) {
      return;
    }
    if (currentUri?.toString().trim() == uri.toString()) {
      await _safeControllerCall('reload', controller.reload);
      return;
    }
    await _safeControllerCall(
      'loadUrl',
      () => controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final uri = _initialUri;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceMint,
        body: Column(
          children: [
            BackNavBar(layout: layout, title: _title, onBack: _handleBack),
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
              ),
            Expanded(
              child: uri == null
                  ? const _WebViewPlaceholder('Invalid page address')
                  : _loadFailed
                  ? ErrorView(
                      message: 'Page failed to load',
                      onRetry: () => unawaited(_retry()),
                    )
                  : _buildWebView(uri),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView(Uri uri) {
    // 原生平台实现未注册（单元测试环境）时不能直接构造 InAppWebView，
    // 否则会断言失败；生产环境始终已注册。
    if (InAppWebViewPlatform.instance == null) {
      return const _WebViewPlaceholder('Web page preview is unavailable');
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
      initialUserScripts: webViewInitialUserScripts(defaultTargetPlatform),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        useHybridComposition: true,
        isInspectable: kDebugMode,
        disableContextMenu: shouldDisableWebViewContextMenu(
          defaultTargetPlatform,
        ),
        allowsLinkPreview: !shouldDisableWebViewContextMenu(
          defaultTargetPlatform,
        ),
        mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        _bridgeGate.attach(controller);
      },
      shouldOverrideUrlLoading: _handleNavigation,
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.DENY,
        );
      },
      onLoadStart: (controller, url) {
        if (mounted) {
          setState(() {
            _loading = true;
            _loadFailed = false;
          });
        }
      },
      onLoadStop: (controller, url) async {
        if (!mounted) return;
        final title = await controller.getTitle();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _title = resolveWebViewTitle(pageTitle: title, fallback: _title);
        });
      },
      onProgressChanged: (controller, progress) {
        if (mounted) {
          setState(() {
            _loading = progress < 100;
          });
        }
      },
      onReceivedError: (controller, request, error) {
        if (mounted &&
            shouldShowWebViewLoadError(
              isForMainFrame: request.isForMainFrame,
            )) {
          setState(() {
            _loading = false;
            _loadFailed = true;
          });
        }
      },
      onTitleChanged: (controller, title) {
        final value = title?.trim() ?? '';
        if (mounted && value.isNotEmpty) {
          setState(() => _title = value);
        }
      },
    );
  }
}

/// 无 WebView 可渲染时的兜底文案（地址非法 / 平台实现缺失），没有重试入口。
class _WebViewPlaceholder extends StatelessWidget {
  const _WebViewPlaceholder(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Center(
      child: Padding(
        padding: layout.edgeInsets(left: AppSpacing.md, right: AppSpacing.md),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: layout.px(14),
          ),
        ),
      ),
    );
  }
}
