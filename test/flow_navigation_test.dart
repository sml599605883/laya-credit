import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/navigation/app_deep_link.dart';
import 'package:laya_credit/core/navigation/app_navigator.dart';
import 'package:laya_credit/core/navigation/app_routes.dart';

/// 用一个占位路由表承载真实导航栈，验证栈清理行为而无需渲染真实页面。
Widget _harness() {
  return MaterialApp(
    navigatorKey: AppNavigator.navigatorKey,
    onGenerateRoute: (settings) {
      final name = settings.name ?? 'home';
      Widget buildPage(BuildContext _) => Scaffold(body: Text(name));
      // 登录页按真实路由生成器返回 `MaterialPageRoute<bool>`，其余页面返回
      // `MaterialPageRoute<void>`，避免 `pushNamed<bool>` 的泛型强转失败。
      if (name == AppRoutes.login) {
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: buildPage,
        );
      }
      return MaterialPageRoute<void>(settings: settings, builder: buildPage);
    },
    home: const Scaffold(body: Text('home')),
  );
}

void main() {
  testWidgets('removeWebViewPages 关闭来源 H5', (tester) async {
    await tester.pumpWidget(_harness());

    unawaited(
      AppNavigator.toWebView<void>(url: 'https://h5.example.com/order/1'),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.webView), findsOneWidget);

    unawaited(
      AppNavigator.toWebView<void>(
        url: 'https://h5.example.com/confirm/2',
        removeWebViewPages: true,
      ),
    );
    await tester.pumpAndSettle();

    // 新 H5 在栈顶，旧的来源 H5 已被移除；返回后直接回到入口页。
    expect(find.text(AppRoutes.webView), findsOneWidget);
    AppNavigator.pop<void>();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text(AppRoutes.webView), findsNothing);
  });

  testWidgets('H5 login 深链清掉会话栈再登录', (tester) async {
    await tester.pumpWidget(_harness());

    unawaited(
      AppNavigator.toWebView<void>(url: 'https://h5.example.com/expired'),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.webView), findsOneWidget);

    unawaited(
      AppNavigator.openDeepLink(
        const AppDeepLinkParser().parse(
          'ph://laya-credit/ios/IdeogrammicCothurni',
        ),
        onUnhandled: (link) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.login), findsOneWidget);
    expect(find.text(AppRoutes.webView), findsNothing);
    // 登录页退出后回到入口页，不会落回失效 H5。
    AppNavigator.pop<void>();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
