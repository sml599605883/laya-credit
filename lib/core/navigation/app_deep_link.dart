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

/// 解析后的深链目标。
class AppDeepLink {
  const AppDeepLink({
    required this.route,
    this.orderStatus,
    this.productId = '',
    this.raw = '',
  });

  /// 目标路由名，见 [AppRoutes]。
  final String route;

  final OrderFilterStatus? orderStatus;
  final String productId;
  final String raw;
}

/// 深链解析器。
///
/// 目前只映射已经存在的页面；产品详情、重新授信、订单列表等页面补齐后，
/// 在这里把别名接到对应路由即可。
class AppDeepLinkParser {
  const AppDeepLinkParser();

  static const _scheme = 'ph';
  static const _host = 'laya-credit';

  AppDeepLink? parse(String rawTarget) {
    final uri = Uri.tryParse(rawTarget.trim());
    if (uri == null || uri.scheme != _scheme || uri.host != _host) return null;

    final segments = uri.pathSegments;
    // 文档路径为 /ios/<别名>。
    if (segments.length < 2 || segments.first != 'ios') return null;

    final alias = segments.last;
    return switch (alias) {
      AppDeepLinkAlias.home => AppDeepLink(
        route: AppRoutes.root,
        raw: rawTarget,
      ),
      AppDeepLinkAlias.login => AppDeepLink(
        route: AppRoutes.login,
        raw: rawTarget,
      ),
      AppDeepLinkAlias.order => AppDeepLink(
        route: AppRoutes.mine,
        orderStatus: OrderFilterStatus.fromValue(
          uri.queryParameters['status'] ?? '',
        ),
        raw: rawTarget,
      ),
      // TODO(页面): 产品详情 / 重新授信 / 准入页尚未搭建，先不解析。
      _ => null,
    };
  }
}
