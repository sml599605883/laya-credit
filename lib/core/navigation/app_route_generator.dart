import 'package:flutter/material.dart';

import '../../data/models/identity_recognition.dart';
import '../../pages/bind_card_page.dart';
import '../../pages/emergency_contact_page.dart';
import '../../pages/face_verification_page.dart';
import '../../pages/home_page.dart';
import '../../pages/id_confirm_page.dart';
import '../../pages/id_upload_page.dart';
import '../../pages/id_verification_page.dart';
import '../../pages/login_page.dart';
import '../../pages/mine_page.dart';
import '../../pages/personal_info_page.dart';
import '../../pages/stats_page.dart';
import '../../pages/work_information_page.dart';
import '../../root_tab_page.dart';
import 'app_routes.dart';

/// 证件选择页入参。认证项按产品下发，必须带上产品 id。
class IdVerificationPageArguments {
  const IdVerificationPageArguments({required this.productId});

  final String productId;
}

/// 证件上传页入参。
///
/// [cardType] 是证件选择页的行文案，也是上传 / 保存接口的卡类型取值，
/// 必须原样带下去，不能在这里 trim 或改大小写。
class IdUploadPageArguments {
  const IdUploadPageArguments({
    required this.productId,
    required this.cardType,
  });

  final String productId;
  final String cardType;
}

/// 证件信息确认页入参（蓝湖稿 `03-01 - 身份认证-上传成功`）。
///
/// [recognition] 是上传接口识别出的身份信息：页面只读展示并原样回传给保存接口，
/// 所以这里不拆成三个字符串，避免中途被改写。
class IdConfirmPageArguments {
  const IdConfirmPageArguments({
    required this.productId,
    required this.cardType,
    required this.recognition,
  });

  final String productId;
  final String cardType;
  final IdentityRecognition recognition;
}

/// 人脸识别页入参。
///
/// [orderNo] 是活体 token 接口的 `resex`，由产品申请流程从产品详情
/// （`basicInfo.orderNo`）带下来，页面不再自己拉一次详情。
class FaceVerificationPageArguments {
  const FaceVerificationPageArguments({
    required this.productId,
    required this.orderNo,
  });

  final String productId;
  final String orderNo;
}

/// 登录页入参。跳转方可以传入回调，在登录成功后继续未完成的动作。
class LoginPageArguments {
  const LoginPageArguments({this.onLoginSuccess});

  final Future<void> Function()? onLoginSuccess;
}

/// 个人信息认证页入参（蓝湖稿 `03-02-认证-个人信息`）。
///
/// 字段、选项与当前值都由页面自己按 [productId] 拉取，这里只带产品 id。
class PersonalInfoPageArguments {
  const PersonalInfoPageArguments({required this.productId});

  final String productId;
}

/// 工作信息认证页入参（蓝湖稿 `03-03 - 工作信息`）。
///
/// 字段、选项与当前值都由页面自己按 [productId] 拉取，这里只带产品 id。
class WorkInfoPageArguments {
  const WorkInfoPageArguments({required this.productId});

  final String productId;
}

/// 紧急联系人认证页入参（蓝湖稿 `03-04 - 联系人信息`）。
///
/// 联系人条数与关系选项都由页面自己按 [productId] 拉取，这里只带产品 id。
class EmergencyContactPageArguments {
  const EmergencyContactPageArguments({required this.productId});

  final String productId;
}

/// 绑卡页入参（蓝湖稿 `03-05 - 绑定账户`，认证第五项）。
///
/// 打款方式分组与字段描述都由页面自己按 [productId] 拉取；
/// [orderNo] 是活体 token 接口的 `resex`，由产品申请流程从产品详情带下来。
class BindCardPageArguments {
  const BindCardPageArguments({required this.productId, this.orderNo = ''});

  final String productId;
  final String orderNo;
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
        final args = settings.arguments as IdVerificationPageArguments?;
        return _route<void>(
          settings,
          (_) => IdVerificationPage(productId: args?.productId ?? ''),
        );

      case AppRoutes.idUpload:
        final uploadArgs = settings.arguments as IdUploadPageArguments?;
        return _route<void>(
          settings,
          (_) => IdUploadPage(
            productId: uploadArgs?.productId ?? '',
            cardType: uploadArgs?.cardType ?? '',
          ),
        );

      case AppRoutes.idConfirm:
        final confirmArgs = settings.arguments as IdConfirmPageArguments?;
        return _route<void>(
          settings,
          (_) => IdConfirmPage(
            productId: confirmArgs?.productId ?? '',
            cardType: confirmArgs?.cardType ?? '',
            recognition:
                confirmArgs?.recognition ?? const IdentityRecognition(),
          ),
        );

      case AppRoutes.faceVerification:
        final faceArgs = settings.arguments as FaceVerificationPageArguments?;
        return _route<void>(
          settings,
          (_) => FaceVerificationPage(
            productId: faceArgs?.productId ?? '',
            orderNo: faceArgs?.orderNo ?? '',
          ),
        );

      case AppRoutes.personalInfo:
        final personalArgs = settings.arguments as PersonalInfoPageArguments?;
        return _route<void>(
          settings,
          (_) => PersonalInfoPage(productId: personalArgs?.productId ?? ''),
        );

      case AppRoutes.workInfo:
        final workArgs = settings.arguments as WorkInfoPageArguments?;
        return _route<void>(
          settings,
          (_) => WorkInformationPage(productId: workArgs?.productId ?? ''),
        );

      case AppRoutes.emergencyContact:
        final contactArgs =
            settings.arguments as EmergencyContactPageArguments?;
        return _route<void>(
          settings,
          (_) => EmergencyContactPage(productId: contactArgs?.productId ?? ''),
        );

      case AppRoutes.bindCard:
        final bindArgs = settings.arguments as BindCardPageArguments?;
        return _route<void>(
          settings,
          (_) => BindCardPage(
            productId: bindArgs?.productId ?? '',
            orderNo: bindArgs?.orderNo ?? '',
          ),
        );

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
