import 'package:flutter/material.dart';

import '../../pages/home_page.dart';
import '../../pages/id_verification_page.dart';
import '../../pages/login_page.dart';
import '../../pages/mine_page.dart';
import '../../pages/stats_page.dart';
import '../../root_tab_page.dart';
import 'app_routes.dart';

/// 登录页入参。跳转方可以传入回调，在登录成功后继续未完成的动作。
class LoginPageArguments {
  const LoginPageArguments({this.onLoginSuccess});

  final Future<void> Function()? onLoginSuccess;
}

/// 路由生成器：`MaterialApp.onGenerateRoute` 的唯一入口。
///
/// 每个 case 负责把 `settings.arguments` 转成强类型的页面入参，
/// 这样页面构造函数保持 required 参数，缺参数时在跳转处就能发现。
class AppRouteGenerator {
  AppRouteGenerator._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return _route<void>(settings, (_) => const RootTabPage());

      case AppRoutes.home:
        return _route<void>(settings, (_) => const HomePage());

      case AppRoutes.stats:
        return _route<void>(settings, (_) => const StatsPage());

      case AppRoutes.mine:
        return _route<void>(settings, (_) => const MinePage());

      case AppRoutes.idVerification:
        return _route<void>(settings, (_) => const IdVerificationPage());

      case AppRoutes.login:
        final args = settings.arguments as LoginPageArguments?;
        return _route<bool>(
          settings,
          (_) => LoginPage(onLoginSuccess: args?.onLoginSuccess),
        );

      default:
        return _route<void>(settings, (_) => _UnknownRoutePage(settings.name));
    }
  }

  /// 统一使用 [MaterialPageRoute]：iOS 上会自动带侧滑返回手势。
  /// 若某个流程（如认证资料填写）需要禁止用户中途返回，
  /// 给该 case 换成禁止手势的 Route 实现即可，不要全局修改。
  static MaterialPageRoute<T> _route<T>(
    RouteSettings settings,
    WidgetBuilder builder,
  ) {
    return MaterialPageRoute<T>(builder: builder, settings: settings);
  }
}

/// 未注册路由的兜底页。出现在这里说明跳转用错了路由名。
class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage(this.routeName);

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                routeName ?? '(null)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
