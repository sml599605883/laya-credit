import 'webview_contract.dart';

typedef WebViewRiskReporter = Future<void> Function({
  required String productId,
  required String orderNo,
  required int startedAtSeconds,
});
typedef WebViewUrlAction = Future<void> Function(String url);
typedef WebViewExternalAction = Future<bool> Function(Uri uri);
typedef WebViewParamsBuilder = Future<Map<String, dynamic>> Function(
  String path,
);
typedef WebViewRetryAction = Future<String> Function(String orderNo);
typedef WebViewAccountAction = Future<void> Function({
  required String productId,
  required String orderNo,
});
typedef WebViewAsyncAction = Future<void> Function();
typedef WebViewMessageAction = Future<void> Function(String message);
typedef WebViewLogger = void Function(String message);

/// action 执行失败时抛出。[message] 会原样展示给用户，
/// 避免把 `ApiException(...)` 这类内部前缀透出到 Toast。
class WebViewActionException implements Exception {
  const WebViewActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 桥接 action 的纯逻辑分发器。
///
/// 与 `InAppWebViewController`、页面生命周期完全解耦：所有副作用都通过构造
/// 注入的回调完成，因此可以脱离 Widget 单测。页面只负责注入真实实现。
class WebViewActionCoordinator {
  const WebViewActionCoordinator({
    this.reportRisk,
    this.openWebView,
    this.navigateInternal,
    this.openExternal,
    this.closePage,
    this.jumpHome,
    this.requestAppReview,
    this.buildPublicParams,
    this.retryOrder,
    this.reloadOrOpenWebView,
    this.changeAccount,
    this.showLoading,
    this.dismissLoading,
    this.showError,
    this.logger,
    this.nowSeconds,
  });

  final WebViewRiskReporter? reportRisk;
  final WebViewUrlAction? openWebView;
  final WebViewUrlAction? navigateInternal;
  final WebViewExternalAction? openExternal;
  final WebViewAsyncAction? closePage;
  final WebViewAsyncAction? jumpHome;
  final WebViewAsyncAction? requestAppReview;
  final WebViewParamsBuilder? buildPublicParams;
  final WebViewRetryAction? retryOrder;
  final WebViewUrlAction? reloadOrOpenWebView;
  final WebViewAccountAction? changeAccount;
  final WebViewAsyncAction? showLoading;
  final WebViewAsyncAction? dismissLoading;
  final WebViewMessageAction? showError;
  final WebViewLogger? logger;
  final int Function()? nowSeconds;

  Future<WebViewResult> dispatch(WebViewRequest request) async {
    try {
      return switch (request.action) {
        WebViewActions.uploadRisk => await _uploadRisk(request),
        WebViewActions.openGooglePlay => _ignoreGooglePlay(request),
        WebViewActions.openUrl => await _openUrl(request),
        WebViewActions.close => await _run(closePage),
        WebViewActions.home => await _run(jumpHome),
        WebViewActions.grade => await _run(requestAppReview),
        WebViewActions.retryOrder => await _retryOrder(request),
        WebViewActions.changeAccount => await _changeAccount(request),
        WebViewActions.publicParams => await _publicParams(request),
        _ => WebViewResult.failure(
          'Unsupported action: ${request.action}',
          code: -2,
        ),
      };
    } catch (error) {
      final resolved = _resolveErrorMessage(error);
      await showError?.call(resolved);
      return WebViewResult.failure(resolved);
    }
  }

  Future<WebViewResult> _uploadRisk(WebViewRequest request) async {
    final productId = _value(request, WebViewFields.productId);
    if (productId.isEmpty) {
      return const WebViewResult.failure('Missing productId');
    }
    await reportRisk?.call(
      productId: productId,
      orderNo: _value(request, WebViewFields.orderNo),
      startedAtSeconds:
          nowSeconds?.call() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return const WebViewResult.success();
  }

  WebViewResult _ignoreGooglePlay(WebViewRequest request) {
    // H5 直接把包名（裸串）作为 data 下发。
    final package = request.rawDataString;
    logger?.call('Google Play action ignored on iOS: package=$package');
    return const WebViewResult.success();
  }

  Future<WebViewResult> _openUrl(WebViewRequest request) async {
    // H5 直接把链接（裸串）作为 data 下发。
    final rawUrl = request.rawDataString;
    final uri = Uri.tryParse(rawUrl);
    if (rawUrl.isEmpty || uri == null || uri.scheme.isEmpty) {
      return const WebViewResult.failure('Invalid url');
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (uri.host.isEmpty) {
        return const WebViewResult.failure('Invalid url');
      }
      await openWebView?.call(rawUrl);
      return const WebViewResult.success();
    }
    if (uri.scheme == 'ph') {
      await navigateInternal?.call(rawUrl);
      return const WebViewResult.success();
    }
    final opened = await openExternal?.call(uri) ?? false;
    return opened
        ? const WebViewResult.success()
        : const WebViewResult.failure('Unable to open url');
  }

  Future<WebViewResult> _publicParams(WebViewRequest request) async {
    final path = request.rawDataString;
    if (path.isEmpty) {
      return const WebViewResult.failure('Missing path');
    }
    final params = await buildPublicParams?.call(path);
    if (params == null) {
      return const WebViewResult.failure('Public params are unavailable');
    }
    return WebViewResult.success(params);
  }

  Future<WebViewResult> _retryOrder(WebViewRequest request) async {
    final orderNo = _value(request, WebViewFields.orderNo);
    if (orderNo.isEmpty) {
      return const WebViewResult.failure('Missing orderNo');
    }
    await showLoading?.call();
    try {
      final url = (await retryOrder?.call(orderNo) ?? '').trim();
      if (url.isEmpty) {
        const message = 'Missing retry result url';
        await showError?.call(message);
        return const WebViewResult.failure(message);
      }
      await reloadOrOpenWebView?.call(url);
      return const WebViewResult.success();
    } finally {
      await dismissLoading?.call();
    }
  }

  Future<WebViewResult> _changeAccount(WebViewRequest request) async {
    final productId = _value(request, WebViewFields.productId);
    final orderNo = _value(request, WebViewFields.orderNo);
    if (productId.isEmpty || orderNo.isEmpty) {
      return const WebViewResult.failure('Missing account information');
    }
    await showLoading?.call();
    try {
      await changeAccount?.call(productId: productId, orderNo: orderNo);
      return const WebViewResult.success();
    } finally {
      await dismissLoading?.call();
    }
  }

  Future<WebViewResult> _run(WebViewAsyncAction? action) async {
    await action?.call();
    return const WebViewResult.success();
  }

  String _value(WebViewRequest request, String key) =>
      request.data[key]?.toString().trim() ?? '';

  static String _resolveErrorMessage(Object error) {
    if (error is WebViewActionException) {
      final text = error.message.trim();
      if (text.isNotEmpty) return text;
    }
    final text = error.toString().trim();
    return text.isEmpty ? 'Unable to complete action' : text;
  }
}
