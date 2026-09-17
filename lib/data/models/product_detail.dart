import '../../core/network/api_fields.dart';

/// 产品详情（`POST /outsulk/inconstruable`）。
///
/// 准入成功后用它判断下一步要补哪个认证项；认证全部完成时用 [basicInfo]
/// 里的订单信息去换借款确认页地址。
class ProductDetail {
  const ProductDetail({
    required this.resultCode,
    required this.basicInfo,
    required this.nextStep,
    this.identityPrompt = '',
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final info = json[ApiFields.productDetail];
    final tips = json[ApiFields.detailTips];

    return ProductDetail(
      resultCode: _intOf(json[ApiFields.applyResultCode]),
      basicInfo: info is Map
          ? ProductBasicInfo.fromJson(info.cast<String, dynamic>())
          : const ProductBasicInfo(),
      nextStep: json[ApiFields.detailNextStep] is Map
          ? ProductNextStep.fromJson(
              (json[ApiFields.detailNextStep] as Map).cast<String, dynamic>(),
            )
          : const ProductNextStep(),
      identityPrompt: tips is Map
          ? tips[ApiFields.detailTipIdentity]?.toString() ?? ''
          : '',
    );
  }

  final int resultCode;
  final ProductBasicInfo basicInfo;

  /// 下一步未完成的认证项，已完成时 [ProductNextStep.taskType] 为空。
  final ProductNextStep nextStep;

  /// 证件上传页顶部引导文案（`overwhelming.splendacious`）。
  ///
  /// 低版本 / 未灰度用户可能不下发，为空时由页面用设计稿兜底文案。
  final String identityPrompt;
}

/// 产品信息（`priapi`）。
class ProductBasicInfo {
  const ProductBasicInfo({
    this.productId = '',
    this.productName = '',
    this.orderNo = '',
    this.orderId = 0,
    this.amount = '',
    this.loanTerm = '',
    this.termType = '',
  });

  factory ProductBasicInfo.fromJson(Map<String, dynamic> json) {
    return ProductBasicInfo(
      productId: json[ApiFields.itemId]?.toString() ?? '',
      productName: json[ApiFields.productName]?.toString() ?? '',
      orderNo: json[ApiFields.detailOrderNo]?.toString() ?? '',
      orderId: _intOf(json[ApiFields.detailOrderId]),
      amount: json[ApiFields.amount]?.toString() ?? '',
      loanTerm: json[ApiFields.detailTerm]?.toString() ?? '',
      termType: json[ApiFields.detailTermType]?.toString() ?? '',
    );
  }

  final String productId;
  final String productName;
  final String orderNo;
  final int orderId;
  final String amount;
  final String loanTerm;
  final String termType;
}

/// 下一步认证项（`cretonne`）。
///
/// `taskType` 是混淆值，取值见接口文档「产品详情认证项目列表」：
/// `Kegful`=身份 / `Reargued`=活体 / `FlintiestDevwsor`=个人信息 /
/// `TrussvilleUninstructively`=工作 / `Thriftiness`=紧急联系人 / `Bespattered`=绑卡。
class ProductNextStep {
  const ProductNextStep({
    this.taskType = '',
    this.title = '',
    this.url = '',
    this.type = 0,
  });

  factory ProductNextStep.fromJson(Map<String, dynamic> json) {
    return ProductNextStep(
      taskType: json[ApiFields.detailTaskType]?.toString() ?? '',
      title: json[ApiFields.itemTitle]?.toString() ?? '',
      url: json[ApiFields.jumpUrl]?.toString() ?? '',
      type: _intOf(json[ApiFields.applyJumpType]),
    );
  }

  final String taskType;
  final String title;

  /// 认证项跳转地址，可能为空（由客户端按 [taskType] 跳对应原生页面）。
  final String url;

  /// 跳转类型：0 原生 / 1 H5。
  final int type;
}

int _intOf(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
