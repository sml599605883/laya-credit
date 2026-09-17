import '../../core/network/api_fields.dart';

/// 首页数据。
///
/// 后端按「模块列表」下发：每个模块带一个类型（BANNER / LARGE_CARD / PROCESS_LIST /
/// AD_LIST ...），客户端按类型渲染，不要写死顺序。
class HomeData {
  const HomeData({
    required this.banners,
    required this.product,
    required this.orders,
    required this.notices,
    this.productList = const [],
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    final sections = json[ApiFields.homeKneeing];
    final banners = <HomeBanner>[];
    final products = <HomeProductCard>[];
    final productList = <HomeProductListCard>[];
    final orders = <HomeOrderCard>[];
    final notices = <String>[];

    if (sections is List) {
      for (final section in sections.whereType<Map>()) {
        final type = _canonicalSectionType(
          section[ApiFields.homeType]?.toString() ?? '',
        );
        final items = section[ApiFields.homeItems];
        if (items is! List) continue;
        final maps = items.whereType<Map>().map(
          (item) => item.cast<String, dynamic>(),
        );

        switch (type) {
          case HomeSectionType.banner:
            banners.addAll(maps.map(HomeBanner.fromJson));
          case HomeSectionType.largeCard:
          case HomeSectionType.smallCard:
            products.addAll(maps.map(HomeProductCard.fromJson));
          case HomeSectionType.productList:
            productList.addAll(maps.map(HomeProductListCard.fromJson));
          case HomeSectionType.process:
            orders.addAll(maps.map(HomeOrderCard.fromJson));
          case HomeSectionType.adList:
            notices.addAll(
              maps
                  .map((item) => item[ApiFields.itemTitle]?.toString() ?? '')
                  .where((title) => title.isNotEmpty),
            );
          default:
            break;
        }
      }
    }

    return HomeData(
      banners: banners,
      product: products.isEmpty ? null : products.first,
      productList: productList,
      orders: orders,
      notices: notices,
    );
  }

  /// 运营位（BANNER 模块）下发的横幅，按后端顺序排列，可多条轮播。
  final List<HomeBanner> banners;
  final HomeProductCard? product;

  /// 推荐列表（PRODUCT_LIST 模块），按后端顺序排列。
  final List<HomeProductListCard> productList;

  /// 进行中的借款订单（借款进度卡）。
  final List<HomeOrderCard> orders;

  /// 首页滚动公告。
  final List<String> notices;

  bool get hasOrders => orders.isNotEmpty;
}

/// 首页模块类型（文档 `7.map.html#首页元素`）。
///
/// ⚠️ 文档里写的是下面这些可读名，但测试环境实际下发的是混淆串
/// （实测 2026-09-14 的 `kneeing[].liquidators`），映射见 [_canonicalSectionType]。
abstract final class HomeSectionType {
  static const banner = 'BANNER';
  static const largeCard = 'LARGE_CARD';
  static const smallCard = 'SMALL_CARD';
  static const repay = 'REPAY';

  /// 推荐列表（首页「Recommendation」区块）。
  static const productList = 'PRODUCT_LIST';

  /// 借款进度卡片。
  static const process = 'PROCESS_LIST';

  /// 首页滚动条。
  static const adList = 'AD_LIST';
}

/// 把 `kneeing[].liquidators` 的实际取值归一成 [HomeSectionType] 常量。
///
/// 与 `7.map.html#首页元素` 的混淆表逐行对应：MalvernePlucked=BANNER、
/// LupusesWheelrace=LARGE_CARD、Abaca=SMALL_CARD、Fugue=REPAY、
/// Sixcylinder=PRODUCT_LIST、Broadtoothed=PROCESS_LIST、
/// BelliferousOverfertilizing=AD_LIST。
///
/// 目前只有实际用到的类型在渲染，其余取值原样返回、由调用方忽略
/// （映射表是逐行对应的，补类型时务必核对行序，不要再按名字猜）。
String _canonicalSectionType(String type) => switch (type) {
  'MalvernePlucked' => HomeSectionType.banner,
  'LupusesWheelrace' => HomeSectionType.largeCard,
  'BelliferousOverfertilizing' => HomeSectionType.adList,
  'Broadtoothed' => HomeSectionType.process,
  'Sixcylinder' => HomeSectionType.productList,
  _ => type,
};

/// 借款进度卡状态（文档 satin 字段）。
enum HomeOrderCardStatus {
  reviewed(1),
  toRepay(2),
  overdue(3),
  disbursing(4),
  failed2(5),
  failed1(6),
  normal(0);

  const HomeOrderCardStatus(this.code);

  final int code;

  static HomeOrderCardStatus fromCode(int code) {
    return HomeOrderCardStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => HomeOrderCardStatus.normal,
    );
  }
}

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.imageUrl,
    required this.jumpUrl,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json[ApiFields.itemId]?.toString() ?? '',
      imageUrl: json[ApiFields.imgUrl]?.toString() ?? '',
      jumpUrl: json[ApiFields.jumpUrl]?.toString() ?? '',
    );
  }

  final String id;
  final String imageUrl;
  final String jumpUrl;
}

/// 授信/借款进度条的一步。
class HomeProgressStep {
  const HomeProgressStep({
    required this.title,
    required this.amount,
    required this.selected,
  });

  factory HomeProgressStep.fromJson(Map<String, dynamic> json) {
    return HomeProgressStep(
      title: json[ApiFields.stepTitle]?.toString() ?? '',
      amount: json[ApiFields.stepAmount]?.toString() ?? '',
      selected: json[ApiFields.stepSelected]?.toString() == '1',
    );
  }

  final String title;
  final String amount;
  final bool selected;
}

/// 首页产品大卡（LARGE_CARD）。
class HomeProductCard {
  const HomeProductCard({
    required this.id,
    required this.productName,
    required this.productLogo,
    required this.buttonText,
    required this.amountRange,
    required this.amountRangeDes,
    required this.termInfo,
    required this.termInfoDes,
    required this.loanRate,
    required this.loanRateDes,
    required this.certifyFinished,
    required this.account,
    required this.accountText,
    required this.progressText,
    required this.steps,
  });

  factory HomeProductCard.fromJson(Map<String, dynamic> json) {
    return HomeProductCard(
      id: json[ApiFields.itemId]?.toString() ?? '',
      productName: json[ApiFields.productName]?.toString() ?? '',
      productLogo: json[ApiFields.productLogo]?.toString() ?? '',
      buttonText: json[ApiFields.buttonText]?.toString() ?? '',
      amountRange: json[ApiFields.amountRange]?.toString() ?? '',
      amountRangeDes: json[ApiFields.amountRangeDes]?.toString() ?? '',
      termInfo: json[ApiFields.termInfo]?.toString() ?? '',
      termInfoDes: json[ApiFields.termInfoDes]?.toString() ?? '',
      loanRate: json[ApiFields.loanRate]?.toString() ?? '',
      loanRateDes: json[ApiFields.loanRateDes]?.toString() ?? '',
      certifyFinished: json[ApiFields.certifyFinished]?.toString() == '1',
      account: json[ApiFields.account]?.toString() ?? '',
      accountText: json[ApiFields.accountText]?.toString() ?? '',
      progressText: json[ApiFields.loanProcessText]?.toString() ?? '',
      steps: _steps(json[ApiFields.loanProcessList]),
    );
  }

  /// 产品 id（点击申请 `tartarizing` 传的就是它）。
  final String id;
  final String productName;
  final String productLogo;
  final String buttonText;
  final String amountRange;
  final String amountRangeDes;
  final String termInfo;
  final String termInfoDes;
  final String loanRate;
  final String loanRateDes;

  /// 是否已完成认证（1 完成 / 0 未完成）。
  final bool certifyFinished;

  /// 收款账号及文案，部分包认证完成后展示。
  final String account;
  final String accountText;
  final String progressText;
  final List<HomeProgressStep> steps;
}

/// 首页借款进度卡（PROCESS_LIST）。
class HomeOrderCard {
  const HomeOrderCard({
    required this.orderNo,
    required this.productId,
    required this.productName,
    required this.productLogo,
    required this.title,
    required this.displayAmount,
    required this.amountText,
    required this.date,
    required this.dateText,
    required this.orderStatusText,
    required this.status,
    required this.progressText,
    required this.steps,
    required this.jumpUrl,
  });

  factory HomeOrderCard.fromJson(Map<String, dynamic> json) {
    final rawStatus = json[ApiFields.cardStatus];
    final statusCode = rawStatus is num
        ? rawStatus.toInt()
        : int.tryParse(rawStatus?.toString() ?? '') ?? 0;

    return HomeOrderCard(
      orderNo: json[ApiFields.orderNo]?.toString() ?? '',
      productId: int.tryParse(json[ApiFields.productId]?.toString() ?? '') ?? 0,
      productName: json[ApiFields.orderProductName]?.toString() ?? '',
      productLogo: json[ApiFields.orderProductLogo]?.toString() ?? '',
      title: json[ApiFields.itemTitle]?.toString() ?? '',
      displayAmount: json[ApiFields.displayAmount]?.toString() ?? '',
      amountText: json[ApiFields.amountText]?.toString() ?? '',
      date: json[ApiFields.date]?.toString() ?? '',
      dateText: json[ApiFields.dateText]?.toString() ?? '',
      orderStatusText: json[ApiFields.orderStatusText]?.toString() ?? '',
      status: HomeOrderCardStatus.fromCode(statusCode),
      progressText: json[ApiFields.loanProcessText]?.toString() ?? '',
      steps: _steps(json[ApiFields.loanProcessList]),
      jumpUrl: json[ApiFields.jumpUrl]?.toString() ?? '',
    );
  }

  final String orderNo;
  final int productId;
  final String productName;
  final String productLogo;
  final String title;

  /// 已格式化的显示金额（例如 ₱50,000）。
  final String displayAmount;
  final String amountText;

  /// 还款日期（客户端展示时以 origin_end_time 口径为准，见 README）。
  final String date;
  final String dateText;
  final String orderStatusText;
  final HomeOrderCardStatus status;
  final String progressText;
  final List<HomeProgressStep> steps;
  final String jumpUrl;
}

List<HomeProgressStep> _steps(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => HomeProgressStep.fromJson(item.cast<String, dynamic>()))
      .toList();
}

/// 推荐卡的按钮配色（文档 `holts`）。
///
/// 取值与设计稿 `02-01` 从上到下的三张卡一一对应：柠檬绿 / 品牌红 / 灰。
/// 后端也会混用早期的 `buttoncolor` 字段，这里只认 `holts`，缺省按「正常」渲染。
enum HomeProductCardButtonStyle {
  highlighted(1),
  normal(0),
  grayed(-1);

  const HomeProductCardButtonStyle(this.code);

  final int code;

  static HomeProductCardButtonStyle fromCode(int code) {
    return HomeProductCardButtonStyle.values.firstWhere(
      (style) => style.code == code,
      orElse: () => HomeProductCardButtonStyle.normal,
    );
  }
}

/// 首页推荐列表卡（PRODUCT_LIST 模块），设计稿 `02-01` 的 `list-items_1`。
class HomeProductListCard {
  const HomeProductListCard({
    required this.id,
    required this.productName,
    required this.productLogo,
    required this.amountRange,
    required this.amountRangeDes,
    required this.loanRate,
    required this.loanRateDes,
    required this.termInfo,
    required this.termInfoText,
    required this.tips,
    required this.buttonStyle,
  });

  factory HomeProductListCard.fromJson(Map<String, dynamic> json) {
    return HomeProductListCard(
      id: json[ApiFields.itemId]?.toString() ?? '',
      // 推荐卡与大卡共用产品名 / Logo / 金额 / 利率字段，期限标签是单独的 `lxe`。
      productName: json[ApiFields.productName]?.toString() ?? '',
      productLogo: json[ApiFields.productLogo]?.toString() ?? '',
      amountRange: json[ApiFields.amountRange]?.toString() ?? '',
      amountRangeDes: json[ApiFields.amountRangeDes]?.toString() ?? '',
      loanRate: json[ApiFields.loanRate]?.toString() ?? '',
      loanRateDes: json[ApiFields.loanRateDes]?.toString() ?? '',
      termInfo: json[ApiFields.termInfo]?.toString() ?? '',
      termInfoText: json[ApiFields.termText]?.toString() ?? '',
      tips: _titles(json[ApiFields.tips]),
      buttonStyle: HomeProductCardButtonStyle.fromCode(
        int.tryParse(json[ApiFields.buttonColorCode]?.toString() ?? '') ?? 0,
      ),
    );
  }

  final String id;
  final String productName;
  final String productLogo;

  /// 已格式化的额度（例如 ₱50,000）。
  final String amountRange;

  /// 额度说明文案（设计稿的「Available up to」）。
  final String amountRangeDes;

  final String loanRate;
  final String loanRateDes;
  final String termInfo;
  final String termInfoText;

  /// 卡片底部的提示文案，多段用「 / 」拼接（设计稿的粉色一行）。
  final List<String> tips;
  final HomeProductCardButtonStyle buttonStyle;
}

List<String> _titles(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item?.toString() ?? '')
      .where((title) => title.isNotEmpty)
      .toList();
}
