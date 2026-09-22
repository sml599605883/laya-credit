/// 全局路由表。
///
/// 所有页面跳转都通过这里的常量进行，禁止在业务代码里写裸字符串路由名，
/// 否则拼写错误只会在运行时才暴露。
abstract final class AppRoutes {
  /// 根页面（底部 Tab 容器）。
  static const root = '/';

  /// 首页 Tab。
  static const home = '/home';

  /// 进度 Tab（底部导航中间，蓝湖稿 `02-03 - 首页-进度`）。
  static const progress = '/progress';

  /// 个人中心 Tab。
  static const mine = '/mine';

  /// 登录页。
  static const login = '/login';

  /// 证件选择页（认证流程第一步）。
  static const idVerification = '/id-verification';

  /// 证件上传页（认证流程第二步）。
  static const idUpload = '/id-upload';

  /// 证件信息确认页（认证流程第三步，识别结果核对）。
  static const idConfirm = '/id-confirm';

  /// 人脸识别页（认证流程第四步，活体检测）。
  static const faceVerification = '/face-verification';

  /// 个人信息认证页（个人信息认证项）。
  static const personalInfo = '/personal-info';

  /// 工作信息认证页（工作信息认证项）。
  static const workInfo = '/work-info';

  /// 紧急联系人认证页（紧急联系人认证项）。
  static const emergencyContact = '/emergency-contact';

  /// 绑卡页（认证第五项，打款账户）。
  static const bindCard = '/bind-card';

  /// 借款确认页（认证全部完成后选收款账户）。
  static const loanConfirm = '/loan-confirm';

  /// 订单列表页（个人中心订单入口）。
  static const orderList = '/order-list';

  /// 通用 H5 页（协议、客服、订单详情、准入返回的 web 链接等）。
  static const webView = '/webview';

  /// 全部路由（用于启动自检与埋点白名单）。
  static const List<String> all = [
    root,
    home,
    progress,
    mine,
    login,
    idVerification,
    idUpload,
    idConfirm,
    faceVerification,
    personalInfo,
    workInfo,
    emergencyContact,
    bindCard,
    loanConfirm,
    orderList,
    webView,
  ];

  /// 路由名是否已注册。
  static bool isValid(String? route) => route != null && all.contains(route);
}
