import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/navigation/app_navigator.dart';
import 'package:laya_credit/core/webview/webview.dart';
import 'package:laya_credit/pages/webview_page.dart';

void main() {
  group('WebViewContract', () {
    test('handler 与 action 串与 Web 端契约一致', () {
      expect(WebViewContract.handler, 'ph_laya_credit_ios');
      expect(WebViewActions.uploadRisk, 'laya_credit_rqHm8jp3XV4JDoI');
      expect(WebViewActions.openGooglePlay, 'laya_credit_lgr5GnQLGtwyPTU');
      expect(WebViewActions.openUrl, 'laya_credit_LSfHZrCEnU8pobX');
      expect(WebViewActions.close, 'laya_credit_DPs6pJccZSPgIRr');
      expect(WebViewActions.home, 'laya_credit_3hmzdF0IOBcBQCB');
      expect(WebViewActions.grade, 'laya_credit_YTIqoTjNxGdF8Fz');
      expect(WebViewActions.retryOrder, 'laya_credit_3ooUbdYzl5XA9WD');
      expect(WebViewActions.changeAccount, 'laya_credit_5vBBE3uRdizNLo7');
      expect(WebViewActions.publicParams, 'laya_credit_IoIRBP06E3v1dGA');
      expect(WebViewFields.productId, 'podostemon');
      expect(WebViewFields.orderNo, 'pirate');
    });

    test('解析 JSON 字符串信封', () {
      final request = WebViewRequest.decode(
        '{"action":"${WebViewActions.uploadRisk}","callbackId":"cb-1",'
        '"data":{"${WebViewFields.productId}":"p-1","${WebViewFields.orderNo}":42}}',
      );
      expect(request.action, WebViewActions.uploadRisk);
      expect(request.callbackId, 'cb-1');
      expect(request.expectsCallback, isTrue);
      expect(request.data[WebViewFields.productId], 'p-1');
      expect(request.data[WebViewFields.orderNo], 42);
    });

    test('兼容 name / payload / callback 别名', () {
      final request = WebViewRequest.decode({
        'name': WebViewActions.uploadRisk,
        'callback': 'cb-2',
        'payload': '{"${WebViewFields.productId}":"p-2"}',
      });
      expect(request.action, WebViewActions.uploadRisk);
      expect(request.callbackId, 'cb-2');
      expect(request.data[WebViewFields.productId], 'p-2');
    });

    test('裸串 data（openUrl / publicParams）原样保留', () {
      final request = WebViewRequest.decode({
        'action': WebViewActions.openUrl,
        'data': 'https://h5.example/a',
      });
      expect(request.data, isEmpty);
      expect(request.rawDataString, 'https://h5.example/a');
    });

    test('畸形 JSON 退化成空 action 且不抛异常', () {
      final request = WebViewRequest.decode('{not-json');
      expect(request.action, isEmpty);
      expect(request.data, isEmpty);
      expect(request.expectsCallback, isFalse);
    });

    test('result 固定输出 code / message / data', () {
      expect(const WebViewResult.success().toJson(), {
        'code': 0,
        'message': 'success',
        'data': <String, dynamic>{},
      });
      expect(const WebViewResult.failure('boom').toJson()['code'], -1);
    });
  });

  group('WebViewActionCoordinator', () {
    test('openUrl 的 http(s) 交给新 WebView', () async {
      final opened = <String>[];
      final coordinator = WebViewActionCoordinator(
        openWebView: (url) async => opened.add(url),
      );
      final result = await coordinator.dispatch(
        WebViewRequest.decode({
          'action': WebViewActions.openUrl,
          'data': 'https://h5.example/a',
        }),
      );
      expect(result.code, 0);
      expect(opened, ['https://h5.example/a']);
    });

    test('openUrl 的 ph 协议走内部路由', () async {
      final navigated = <String>[];
      final coordinator = WebViewActionCoordinator(
        navigateInternal: (url) async => navigated.add(url),
      );
      await coordinator.dispatch(
        WebViewRequest.decode({
          'action': WebViewActions.openUrl,
          'data': 'ph://laya-credit/ios/DrivepipeAlphyl',
        }),
      );
      expect(navigated, ['ph://laya-credit/ios/DrivepipeAlphyl']);
    });

    test('未知 action 返回 -2', () async {
      final result = await WebViewActionCoordinator().dispatch(
        WebViewRequest.decode({'action': 'not_an_action'}),
      );
      expect(result.code, -2);
    });

    test('uploadRisk 缺 productId 直接失败', () async {
      final result = await WebViewActionCoordinator().dispatch(
        WebViewRequest.decode({'action': WebViewActions.uploadRisk}),
      );
      expect(result.code, -1);
      expect(result.message, contains('productId'));
    });

    test('uploadRisk 命中时带上 productId / orderNo 与时间', () async {
      String? capturedProductId;
      String? capturedOrderNo;
      int? capturedStartedAt;
      final coordinator = WebViewActionCoordinator(
        reportRisk:
            ({
              required productId,
              required orderNo,
              required startedAtSeconds,
            }) async {
              capturedProductId = productId;
              capturedOrderNo = orderNo;
              capturedStartedAt = startedAtSeconds;
            },
        nowSeconds: () => 1234,
      );
      final result = await coordinator.dispatch(
        WebViewRequest.decode({
          'action': WebViewActions.uploadRisk,
          'data': {
            WebViewFields.productId: 'p-1',
            WebViewFields.orderNo: 'o-1',
          },
        }),
      );
      expect(result.code, 0);
      expect(capturedProductId, 'p-1');
      expect(capturedOrderNo, 'o-1');
      expect(capturedStartedAt, 1234);
    });

    test('publicParams 用裸串作为 path', () async {
      String? capturedPath;
      final coordinator = WebViewActionCoordinator(
        buildPublicParams: (path) async {
          capturedPath = path;
          return {'sign': 'x'};
        },
      );
      final result = await coordinator.dispatch(
        WebViewRequest.decode({
          'action': WebViewActions.publicParams,
          'data': '/outsulk/connectedly',
        }),
      );
      expect(result.code, 0);
      expect(capturedPath, '/outsulk/connectedly');
      expect(result.data, {'sign': 'x'});
    });

    test('retryOrder 拿到空地址时失败并提示', () async {
      final errors = <String>[];
      var loading = 0;
      final coordinator = WebViewActionCoordinator(
        retryOrder: (orderNo) async => '',
        showLoading: () async => loading++,
        dismissLoading: () async => loading--,
        showError: (message) async => errors.add(message),
      );
      final result = await coordinator.dispatch(
        WebViewRequest.decode({
          'action': WebViewActions.retryOrder,
          'data': {WebViewFields.orderNo: 'o-1'},
        }),
      );
      expect(result.code, -1);
      expect(errors, isNotEmpty);
      expect(loading, 0);
    });

    test('action 抛 WebViewActionException 时原样透出文案', () async {
      final errors = <String>[];
      final coordinator = WebViewActionCoordinator(
        retryOrder: (orderNo) async =>
            throw const WebViewActionException('No original card'),
        showError: (message) async => errors.add(message),
      );
      final result = await coordinator.dispatch(
        WebViewRequest.decode({
          'action': WebViewActions.retryOrder,
          'data': {WebViewFields.orderNo: 'o-1'},
        }),
      );
      expect(result.code, -1);
      expect(result.message, 'No original card');
      expect(errors, ['No original card']);
    });
  });

  group('WebView 辅助函数', () {
    test('内联 scheme 白名单', () {
      expect(isInlineWebViewScheme('https'), isTrue);
      expect(isInlineWebViewScheme('about'), isTrue);
      expect(isInlineWebViewScheme('tel'), isFalse);
      expect(isInlineWebViewScheme('mailto'), isFalse);
    });

    test('无历史可回退时关闭页面', () {
      expect(shouldCloseWebView(canGoBack: false), isTrue);
      expect(shouldCloseWebView(canGoBack: true), isFalse);
    });

    test('标题回退', () {
      expect(
        resolveWebViewTitle(pageTitle: '  ', fallback: 'Details'),
        'Details',
      );
      expect(
        resolveWebViewTitle(pageTitle: 'Order', fallback: 'Details'),
        'Order',
      );
    });

    test('回调脚本仅在带 callbackId 时生成', () {
      final request = WebViewRequest.decode({
        'action': WebViewActions.close,
        'callbackId': 'cb-9',
      });
      final script = webViewCallbackScript(
        request,
        const WebViewResult.success({'ok': true}),
      );
      expect(script, contains('window.${WebViewContract.handler}'));
      expect(script, contains('cb-9'));

      final noCallback = WebViewRequest.decode({
        'action': WebViewActions.close,
      });
      expect(
        webViewCallbackScript(noCallback, const WebViewResult.success()),
        isNull,
      );
    });

    test('保留确认路径未命中时不拦截', () {
      expect(webViewConfirmProductId('https://h5.example/#/Order'), isEmpty);
    });
  });

  group('AppNavigator.webViewUri', () {
    test('只放行带 host 的 http/https', () {
      expect(
        AppNavigator.webViewUri('https://h5.example/a')?.host,
        'h5.example',
      );
      expect(
        AppNavigator.webViewUri('http://8.220.190.152/#/x')?.host,
        '8.220.190.152',
      );
      expect(AppNavigator.webViewUri('ph://laya-credit/ios/x'), isNull);
      expect(AppNavigator.webViewUri('https://'), isNull);
      expect(AppNavigator.webViewUri(''), isNull);
    });
  });
}
