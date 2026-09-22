import 'dart:convert';

import '../../core/media/identity_photo.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_fields.dart';
import '../../core/network/api_response.dart';
import '../../core/network/http_client.dart';
import '../../core/network/obfuscation_helper.dart';
import '../models/emergency_contact_data.dart';
import '../models/loan_confirm_data.dart';
import '../models/face_token_result.dart';
import '../models/id_verification_data.dart';
import '../models/bind_card_data.dart';
import '../models/personal_info_data.dart';

/// 认证项相关接口（证件 / 活体 / 个人信息 / 工作 / 紧急联系人 / 绑卡）。
///
/// 已接入证件 / 活体 / 个人信息 / 工作四项，其余认证项（紧急联系人 / 绑卡）
/// 按接口文档 `4.certify.html` 在落地对应页面时逐个补到这里。
class CertificationRepository {
  const CertificationRepository(this._client);

  final HttpClient _client;

  /// 获取用户身份信息（认证第一项）：证件类型列表。
  ///
  /// 产品维度下发，页面每次进入都会用 [productId] 拉一次（Provider 里按产品缓存）。
  Future<ApiResponse<IdVerificationData>> getIdentityInfo({
    required String productId,
  }) {
    return _client.get<IdVerificationData>(
      ApiEndpoints.identityInfo,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscateIdentityInfo: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? IdVerificationData.fromJson(data.cast<String, dynamic>())
          : const IdVerificationData(recommended: [], other: []),
    );
  }

  /// 上传身份证正面照（multipart），返回后端 OCR 识别出的信息。
  ///
  /// 文档「接口上传(face,身份证正面)（第一项）」：固定 `liquidators=11`（身份证正面），
  /// 卡类型取证件选择页的行文案，来源区分相册 / 拍照。
  Future<ApiResponse<Map<String, dynamic>>> uploadIdentityImage({
    required String filePath,
    required String cardType,
    required IdentityPhotoSource source,
  }) {
    return _client.upload<Map<String, dynamic>>(
      ApiEndpoints.uploadIdentityImage,
      filePath: filePath,
      fileField: ApiFields.uploadFileField,
      fields: {
        ApiFields.uploadType: '11',
        ApiFields.uploadImageSource: source.code,
        ApiFields.uploadCardType: cardType,
        // 身份证正面用不到活体参数，但后端要求字段存在，空串也要带上。
        ApiFields.uploadLivenessId: '',
        ApiFields.uploadLivenessLicense: '',
        ApiFields.uploadFaceType: '',
        ApiFields.uploadBizId: '',
      },
      parse: (data) =>
          data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  /// 获取 face++ token / 活体检测授权码（认证第二项）。
  ///
  /// 文档「获取face++ token」：`resex` 传订单号，`liquidators` 是类型
  /// （`0` 默认 / `1` 绑卡前的活体校验），另外带两个随机混淆字段。
  Future<ApiResponse<FaceTokenResult>> getFaceToken({
    required String orderNo,
    int type = 0,
  }) {
    return _client.post<FaceTokenResult>(
      ApiEndpoints.faceToken,
      params: {
        ApiFields.faceTokenOrderNo: orderNo,
        ApiFields.faceTokenType: '$type',
        ApiFields.obfuscateFaceToken1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateFaceToken2: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? FaceTokenResult.fromJson(data.cast<String, dynamic>())
          : const FaceTokenResult(),
    );
  }

  /// 上传活体（人脸）照片（`POST /outsulk/fashioned`，`liquidators=10`）。
  ///
  /// 与身份证正面共用同一个接口：`chromogenous` 固定 `1`（活体不接受拍照来源），
  /// `heterological` 活体不用、传空串，`gargantua` 带 SDK 返回的 livenessId，
  /// `musculopallial` 带 token 接口下发的授权码，`bassein` 是活体类型。
  Future<ApiResponse<Map<String, dynamic>>> uploadFaceImage({
    required String filePath,
    required String livenessId,
    required String license,
    required int livenessType,
    String bizId = '',
  }) {
    return _client.upload<Map<String, dynamic>>(
      ApiEndpoints.uploadIdentityImage,
      filePath: filePath,
      fileField: ApiFields.uploadFileField,
      fields: {
        ApiFields.uploadType: '10',
        ApiFields.uploadImageSource: '1',
        ApiFields.uploadCardType: '',
        ApiFields.uploadLivenessId: livenessId,
        ApiFields.uploadLivenessLicense: license,
        ApiFields.uploadFaceType: '$livenessType',
        ApiFields.uploadBizId: bizId,
      },
      parse: (data) =>
          data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  /// 保存识别出的身份证信息（认证第一项）。
  ///
  /// 文档「保存用户身份证信息（第一项）」：`liquidators=11`（身份证正面），
  /// 卡类型取证件选择页的行文案（`heterological`），`counter` 必须是 `d-m-Y`，
  /// 另外带一个随机混淆字段 `stith`。
  Future<ApiResponse<void>> saveIdentityInfo({
    required String name,
    required String idNumber,
    required String birthDate,
    required String cardType,
  }) {
    return _client.post<void>(
      ApiEndpoints.saveIdentityInfo,
      params: {
        // `harbingers` / `approach` / `counter` 与上传响应用同一批字段名。
        ApiFields.identityName: name,
        ApiFields.identityIdNumber: idNumber,
        ApiFields.identityBirthDate: birthDate,
        // 与上传接口同一个 `liquidators`：11 身份证正面 / 10 活体。
        ApiFields.uploadType: '11',
        ApiFields.uploadCardType: cardType,
        ApiFields.obfuscateSaveIdentity: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// 获取个人信息表单（认证第二项，`POST /outsulk/orchel`）。
  ///
  /// 字段（标题 / 占位 / 控件类型 / 选项 / 当前值）全部由后端下发，
  /// 页面只负责按描述渲染，不要在客户端写死任何字段或选项。
  Future<ApiResponse<PersonalInfoData>> getPersonalInfo({
    required String productId,
  }) {
    return _client.post<PersonalInfoData>(
      ApiEndpoints.personalInfo,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscatePersonalInfo: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? PersonalInfoData.fromJson(data.cast<String, dynamic>())
          : const PersonalInfoData(fields: [], tips: ''),
    );
  }

  /// 保存个人信息（认证第二项，`POST /outsulk/marantas`）。
  ///
  /// [formData] 的 key 必须是「获取用户信息（第二项）」下发的 `crucians`，
  /// 后端按同一份字段表取值；另外带两个文档标注的混淆字段。
  Future<ApiResponse<void>> savePersonalInfo({
    required String productId,
    required Map<String, String> formData,
  }) {
    return _client.post<void>(
      ApiEndpoints.savePersonalInfo,
      params: {
        ApiFields.productId: productId,
        ...formData,
        ApiFields.obfuscateSavePersonalInfo1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateSavePersonalInfo2: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// 获取工作信息表单（认证第三项，`GET /outsulk/timeling`）。
  ///
  /// 与「获取用户信息（第二项）」同一份字段描述结构（`aminate` / `befleas`），
  /// 所以复用 [PersonalInfoData]；字段 / 选项全部由后端下发，不要写死。
  Future<ApiResponse<PersonalInfoData>> getWorkInfo({
    required String productId,
  }) {
    return _client.get<PersonalInfoData>(
      ApiEndpoints.workInfo,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscateWorkInfo: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? PersonalInfoData.fromJson(data.cast<String, dynamic>())
          : const PersonalInfoData(fields: [], tips: ''),
    );
  }

  /// 保存工作信息（认证第三项，`POST /outsulk/kneeing`）。
  ///
  /// [formData] 的 key 必须是「获取工作信息（第三项）」下发的 `crucians`，
  /// 后端按同一份字段表取值；另外带三个文档标注的混淆字段。
  Future<ApiResponse<void>> saveWorkInfo({
    required String productId,
    required Map<String, String> formData,
  }) {
    return _client.post<void>(
      ApiEndpoints.saveWorkInfo,
      params: {
        ApiFields.productId: productId,
        ...formData,
        ApiFields.obfuscateSaveWorkInfo1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateSaveWorkInfo2: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateSaveWorkInfo3: ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// 地址初始化（`GET /outsulk/avern`）：省 / 市 / 区的层级数据。
  Future<ApiResponse<AddressInitData>> getAddressInit() {
    return _client.get<AddressInitData>(
      ApiEndpoints.addressInit,
      parse: (data) => AddressInitData.fromJson(data),
    );
  }

  /// 获取联系人信息（认证第四项，`GET /outsulk/liquidators`）。
  ///
  /// 除产品 id 外还要带一个文档标注的混淆字段；联系人条数与关系选项都由后端下发。
  Future<ApiResponse<EmergencyContactData>> getEmergencyContacts({
    required String productId,
  }) {
    return _client.get<EmergencyContactData>(
      ApiEndpoints.emergencyContacts,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscateEmergencyContact: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? EmergencyContactData.fromJson(data.cast<String, dynamic>())
          : const EmergencyContactData(),
    );
  }

  /// 保存联系人信息（认证第四项，`POST /outsulk/stabiliment`）。
  ///
  /// `connectedly` 是联系人数组的 JSON 字符串（不是表单数组），
  /// 每项的 `canmaker` 必须是获取接口下发的原值。
  Future<ApiResponse<void>> saveEmergencyContacts({
    required String productId,
    required List<EmergencyContactInput> contacts,
  }) {
    return _client.post<void>(
      ApiEndpoints.saveEmergencyContacts,
      params: {
        ApiFields.productId: productId,
        ApiFields.emergencyContactSaveData: jsonEncode(
          contacts.map((contact) => contact.toJson()).toList(growable: false),
        ),
        ApiFields.obfuscateSaveEmergencyContact:
            ObfuscationHelper.randomParam(),
      },
      parse: (_) {},
    );
  }

  /// 获取绑卡信息（认证第五项，`GET /outsulk/cussedly`）。
  ///
  /// 打款方式分组（E-wallet / Bank...）、每组的字段描述与下拉渠道全部由后端下发，
  /// 页面只按描述渲染，不在客户端写死任何渠道或字段。
  Future<ApiResponse<BindCardData>> getBindCardInfo({
    required String productId,
  }) {
    return _client.get<BindCardData>(
      ApiEndpoints.bindCardInfo,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscateBindCardInfo1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateBindCardInfo2: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? BindCardData.fromJson(data.cast<String, dynamic>())
          : const BindCardData(),
    );
  }

  /// 提交绑卡（认证第五项，`POST /outsulk/superidealness`）。
  ///
  /// [fields] 的 key 用获取接口下发的 `crucians` 原样回传；唯一例外是打款渠道
  /// 字段（下发 key 为语义串 `channelCode`），提交时要改成
  /// `ApiFields.bindCardSubmitChannel`。
  ///
  /// 返回 `code == 20000` 时表示后端要求先做活体：把活体结果填进
  /// [faceType] / [livenessId] / [image] / [bizId] / [license]，再带同样的
  /// [fields] 调一次本接口。
  Future<ApiResponse<Map<String, dynamic>>> submitBindCard({
    required String productId,
    required String cardType,
    required Map<String, String> fields,
    String faceType = '',
    String livenessId = '',
    String image = '',
    String bizId = '',
    String license = '',
  }) {
    final params = <String, Object?>{
      ApiFields.bindCardSubmitProductId: productId,
      ApiFields.bindCardSubmitType: cardType,
      ...fields,
      ApiFields.uploadFaceType: faceType,
      ApiFields.uploadLivenessId: livenessId,
      ApiFields.uploadFileField: image,
      ApiFields.uploadBizId: bizId,
      ApiFields.uploadLivenessLicense: license,
      ApiFields.obfuscateSubmitBindCard: ObfuscationHelper.randomParam(),
    };
    // 渠道字段改名：下发 key 是 `channelCode`，提交要换成 `entertainer`。
    final channel = params.remove(BindCardField.channelKey);
    if (channel != null) params[ApiFields.bindCardSubmitChannel] = channel;

    return _client.post<Map<String, dynamic>>(
      ApiEndpoints.submitBindCard,
      params: params,
      parse: (data) =>
          data is Map ? data.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  /// 用户账户列表（借款确认页的可选收款账户，`POST /outsulk/heartfelt`）。
  ///
  /// 账户按打款方式分组（Bank / E-wallet / Cash Pickup）下发，分节名、
  /// 每笔账户的账号 / 收款人姓名与是否默认选中都由后端给，客户端不写死。
  Future<ApiResponse<LoanConfirmData>> getUserAccounts({
    required String productId,
  }) {
    return _client.post<LoanConfirmData>(
      ApiEndpoints.userAccounts,
      params: {
        ApiFields.productId: productId,
        ApiFields.obfuscateLoanAccounts1: ObfuscationHelper.randomParam(),
        ApiFields.obfuscateLoanAccounts2: ObfuscationHelper.randomParam(),
      },
      parse: (data) => data is Map
          ? LoanConfirmData.fromJson(data.cast<String, dynamic>())
          : const LoanConfirmData(),
    );
  }

  /// 更换银行卡（借款确认页提交选中的收款账户，`POST /outsulk/bathtubs`）。
  ///
  /// [bindId] 是账户列表下发的 `moonshade`；返回订单详情页地址，由调用方决定
  /// 用 WebView 还是原生页打开。
  Future<ApiResponse<String>> changeBankCard({
    required String orderNo,
    required String bindId,
  }) {
    return _client.post<String>(
      ApiEndpoints.changeBankCard,
      params: {
        ApiFields.changeBankCardOrderNo: orderNo,
        ApiFields.changeBankCardBindId: bindId,
        ApiFields.obfuscateChangeBankCard: ObfuscationHelper.randomParam(),
      },
      parse: (data) =>
          data is Map ? _textOf(data[ApiFields.changeBankCardRedirectUrl]) : '',
    );
  }

  /// 原卡重试确认订单（订单详情 H5 的「原卡重试」，`POST /outsulk/resex`）。
  ///
  /// 入参只有订单号；返回订单详情页地址，由调用方在当前 WebView 里打开。
  Future<ApiResponse<String>> retryOrderConfirm({required String orderNo}) {
    return _client.post<String>(
      ApiEndpoints.orderRetryConfirm,
      params: {ApiFields.retryConfirmOrderNo: orderNo},
      parse: (data) =>
          data is Map ? _textOf(data[ApiFields.retryConfirmJumpUrl]) : '',
    );
  }
}

String _textOf(Object? value) => value?.toString().trim() ?? '';
