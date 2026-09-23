import 'app_routes.dart';

/// 深链 Scheme：`ph://laya-credit/ios/<混淆别名>`（文档 `7.map.html#Scheme`）。
///
/// 别名是后端下发的混淆名，客户端只做映射，不要反推语义。
abstract final class AppDeepLinkAlias {
  static const home = 'DrivepipeAlphyl';
  static const settings = 'MilkwoodSporogenous';
  static const login = 'IdeogrammicCothurni';
  static const order = 'AsepticizingCriminalist';
  static const productDetail = 'UnworshippingPigeonberries';
  static const recredit = 'IntervesicularSauder';
  static const admission = 'Isaria';
}

/// 订单列表筛选状态（文档：4 全部 / 7 进行中 / 6 待还款 / 5 已结清）。
enum OrderFilterStatus {
  all('4'),
  inProgress('7'),
  toRepay('6'),
  settled('5');

  const OrderFilterStatus(this.value);

  final String value;

  static OrderFilterStatus? fromValue(String value) {
    for (final status in OrderFilterStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

/// 解析后的深链目标类型。
///
/// 准入接口下发 `superidealness` 时，用 `liquidators` 区分原生（0）与 H5（1）；
/// 原生的再按这里的别名分到具体页面。
enum AppDeepLinkKind {
  /// H5 链接，需要 WebView 打开。
  webView,

  /// 首页。
  home,

  /// 设置页。
  settings,

  /// 登录页。
  login,

  /// 订单列表页。
  order,

  /// 产品详情 / 继续认证流程。
  productDetail,

  /// 重新授信 loading 页。
  recredit,

  /// 准入流程。
  admission,

  /// 无法识别的地址。
  unsupported,
}

/// 解析后的深链目标。
class AppDeepLink {
  const AppDeepLink({
    required this.kind,
    this.route,
    this.orderStatus,
    this.productId = '',
    this.url = '',
    this.raw = '',
  });

  /// 目标类型。
  final AppDeepLinkKind kind;

  /// 可直接跳转的路由名，见 [AppRoutes]；不需要路由时为 null。
  final String? route;

  final OrderFilterStatus? orderStatus;

  /// 地址里携带的产品 id（可能为空）。
  final String productId;

  /// H5 链接（仅 [AppDeepLinkKind.webView] 有值）。
  final String url;

  final String raw;
}

/// 深链解析器。
///
/// 目前只映射已经存在的页面；产品详情、重新授信、订单列表等页面补齐后，
/// 在这里把别名接到对应路由即可。
class AppDeepLinkParser {
  const AppDeepLinkParser();

  /// App 专属协议（文档 `7.map.html#Scheme`）：`ph://laya-credit/ios/<别名>`。
  static const _scheme = 'ph';
  static const _host = 'laya-credit';

  /// 订单列表深链携带筛选状态的参数名（`butterpaste`，取值 4/7/6/5，
  /// 与订单列表接口的业务字段同名）。
  static const _orderStatusParam = 'butterpaste';

  /// 深链里携带产品 id 的参数名（文档值映射 `product_id` → `tartarizing`）。
  static const _productIdParam = 'tartarizing';

  AppDeepLink parse(String rawTarget) {
    final trimmed = rawTarget.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return AppDeepLink(kind: AppDeepLinkKind.unsupported, raw: rawTarget);
    }

    // H5 链接直接交给 WebView（页面补齐前由调用方兜底提示）。
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return AppDeepLink(
        kind: AppDeepLinkKind.webView,
        url: trimmed,
        productId: uri.queryParameters['productId'] ?? '',
        raw: rawTarget,
      );
    }

    if (uri.scheme != _scheme || uri.host != _host) {
      return AppDeepLink(kind: AppDeepLinkKind.unsupported, raw: rawTarget);
    }

    final segments = uri.pathSegments;
    // 文档路径为 /ios/<别名>。
    if (segments.length < 2 || segments.first != 'ios') {
      return AppDeepLink(kind: AppDeepLinkKind.unsupported, raw: rawTarget);
    }

    final alias = segments.last;
    // 产品 id 的参数名：文档值映射把 `product_id` 混淆成 `tartarizing`，
    // 历史链接也有直接叫 `productId` 的，两个都认，取到即用。
    final productId =
        uri.queryParameters['productId'] ??
        uri.queryParameters[_productIdParam] ??
        uri.queryParameters[AppDeepLinkAlias.admission] ??
        '';

    return switch (alias) {
      AppDeepLinkAlias.home => AppDeepLink(
        kind: AppDeepLinkKind.home,
        route: AppRoutes.root,
        raw: rawTarget,
      ),
      AppDeepLinkAlias.settings => AppDeepLink(
        kind: AppDeepLinkKind.settings,
        raw: rawTarget,
      ),
      AppDeepLinkAlias.login => AppDeepLink(
        kind: AppDeepLinkKind.login,
        route: AppRoutes.login,
        raw: rawTarget,
      ),
      AppDeepLinkAlias.order => AppDeepLink(
        kind: AppDeepLinkKind.order,
        route: AppRoutes.orderList,
        orderStatus: OrderFilterStatus.fromValue(
          uri.queryParameters[_orderStatusParam] ?? '',
        ),
        raw: rawTarget,
      ),
      AppDeepLinkAlias.productDetail => AppDeepLink(
        kind: AppDeepLinkKind.productDetail,
        productId: productId,
        raw: rawTarget,
      ),
      AppDeepLinkAlias.recredit => AppDeepLink(
        kind: AppDeepLinkKind.recredit,
        productId: productId,
        raw: rawTarget,
      ),
      AppDeepLinkAlias.admission => AppDeepLink(
        kind: AppDeepLinkKind.admission,
        productId: productId,
        raw: rawTarget,
      ),
      _ => AppDeepLink(kind: AppDeepLinkKind.unsupported, raw: rawTarget),
    };
  }
}
