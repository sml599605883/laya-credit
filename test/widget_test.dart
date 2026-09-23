import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laya_credit/core/device/device_params.dart';
import 'package:laya_credit/core/face/liveness_gateway.dart';
import 'package:laya_credit/core/network/api_endpoints.dart';
import 'package:laya_credit/core/network/api_exception.dart';
import 'package:laya_credit/core/network/api_fields.dart';
import 'package:laya_credit/core/network/api_protocol.dart';
import 'package:laya_credit/core/network/api_response.dart';
import 'package:laya_credit/core/network/common_params.dart';
import 'package:laya_credit/core/permissions/permission_coordinator.dart';
import 'package:laya_credit/core/certification/certification_retention_guard.dart';
import 'package:laya_credit/core/product/product_application_flow.dart';
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/core/webview/webview_action_coordinator.dart';
import 'package:laya_credit/core/webview/webview_contract.dart';
import 'package:laya_credit/data/models/face_token_result.dart';
import 'package:laya_credit/data/models/bind_card_data.dart';
import 'package:laya_credit/data/models/certification_retention.dart';
import 'package:laya_credit/data/models/emergency_contact_data.dart';
import 'package:laya_credit/data/models/home_data.dart';
import 'package:laya_credit/data/models/id_verification_data.dart';
import 'package:laya_credit/data/models/identity_recognition.dart';
import 'package:laya_credit/data/models/login_result.dart';
import 'package:laya_credit/data/models/loan_confirm_data.dart';
import 'package:laya_credit/data/models/personal_info_data.dart';
import 'package:laya_credit/data/models/sms_channel_options.dart';
import 'package:laya_credit/data/repositories/app_repository.dart';
import 'package:laya_credit/data/repositories/auth_repository.dart';
import 'package:laya_credit/data/repositories/certification_repository.dart';
import 'package:laya_credit/data/repositories/product_repository.dart';
import 'package:laya_credit/data/repositories/report_repository.dart';
import 'package:laya_credit/data/models/product_apply_result.dart';
import 'package:laya_credit/data/models/product_detail.dart';
import 'package:laya_credit/theme/app_assets.dart';
import 'package:laya_credit/theme/app_colors.dart';
import 'package:laya_credit/theme/app_spacing.dart';
import 'package:laya_credit/core/report/report.dart';
import 'package:laya_credit/main.dart';
import 'package:laya_credit/core/media/identity_photo.dart';
import 'package:laya_credit/core/navigation/navigation.dart';
import 'package:laya_credit/pages/face_verification_page.dart';
import 'package:laya_credit/pages/bind_card_page.dart';
import 'package:laya_credit/pages/emergency_contact_page.dart';
import 'package:laya_credit/pages/home_page.dart';
import 'package:laya_credit/pages/id_confirm_page.dart';
import 'package:laya_credit/pages/id_upload_page.dart';
import 'package:laya_credit/pages/id_verification_page.dart';
import 'package:laya_credit/pages/login_page.dart';
import 'package:laya_credit/pages/loan_confirm_page.dart';
import 'package:laya_credit/pages/personal_info_page.dart';
import 'package:laya_credit/pages/webview_page.dart';
import 'package:laya_credit/pages/work_information_page.dart';
import 'package:laya_credit/providers/certification_retention_provider.dart';
import 'package:laya_credit/providers/home_provider.dart';
import 'package:laya_credit/providers/liveness_provider.dart';
import 'package:laya_credit/providers/media_provider.dart';
import 'package:laya_credit/providers/network_provider.dart';
import 'package:laya_credit/providers/repository_provider.dart';
import 'package:laya_credit/providers/session_provider.dart';
import 'package:laya_credit/widgets/back_nav_bar.dart';
import 'package:laya_credit/widgets/remote_image.dart';
import 'package:laya_credit/widgets/state_views.dart';
import 'package:laya_credit/widgets/tab_bar/app_tab_bar.dart';

/// 用桩仓库替掉真实网络请求，让页面测试可预期。
/// HttpClient 只作为占位传入，桩方法不会真的发请求。
class _StubAppRepository extends AppRepository {
  _StubAppRepository({this.home, this.failure}) : super(_placeholderClient());

  final HomeData? home;
  final Object? failure;

  /// 首页接口调用次数：用于断言刷新时机（首屏、退出登录回落首页等）。
  int homeCalls = 0;

  @override
  Future<ApiResponse<HomeData>> getHomePage() async {
    homeCalls++;
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data:
          home ??
          const HomeData(banners: [], product: null, orders: [], notices: []),
    );
  }
}

/// 可控首页仓库桩：每次请求都挂起，由测试决定返回顺序，
/// 用来验证并发刷新的 last-wins（对齐 dali_cash）。
class _ControllableHomeRepository extends AppRepository {
  _ControllableHomeRepository() : super(_placeholderClient());

  final List<Completer<ApiResponse<HomeData>>> requests = [];

  @override
  Future<ApiResponse<HomeData>> getHomePage() {
    final completer = Completer<ApiResponse<HomeData>>();
    requests.add(completer);
    return completer.future;
  }
}

ApiResponse<HomeData> _homeResponse(List<String> notices) => ApiResponse(
  code: 0,
  message: 'success',
  data: HomeData(
    banners: const [],
    product: null,
    orders: const [],
    notices: notices,
  ),
);

/// 登录/发码仓库桩：只记录调用，不发网络。
class _StubAuthRepository extends AuthRepository {
  _StubAuthRepository({
    this.failure,
    this.delay,
    this.deleteAccountFailure = false,
  }) : super(_placeholderClient());

  final Object? failure;

  /// 模拟慢请求，用来观察请求进行中的 UI。
  final Duration? delay;

  /// 注销接口返回业务失败（`code != 0`），验证失败时不会误清登录态。
  final bool deleteAccountFailure;

  int sendCodeCalls = 0;
  int loginCalls = 0;
  int logoutCalls = 0;
  int deleteAccountCalls = 0;

  @override
  Future<ApiResponse<void>> sendSmsCode({
    required String phone,
    required SmsChannel channel,
  }) async {
    sendCodeCalls++;
    if (delay case final wait?) await Future<void>.delayed(wait);
    if (failure case final error?) throw error;
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }

  @override
  Future<ApiResponse<LoginResult>> login({
    required String phone,
    required String code,
  }) async {
    loginCalls++;
    if (delay case final wait?) await Future<void>.delayed(wait);
    if (failure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: LoginResult(
        sessionId: 'test-session',
        phone: phone,
        realName: '',
        isOldUser: true,
        smsMaxId: '1',
      ),
    );
  }

  @override
  Future<ApiResponse<void>> logout() async {
    logoutCalls++;
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }

  @override
  Future<ApiResponse<void>> deleteAccount() async {
    deleteAccountCalls++;
    if (deleteAccountFailure) {
      return const ApiResponse<void>(code: 400, message: 'failed', data: null);
    }
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }
}

/// 认证项仓库桩：默认下发设计稿那两组证件，可改成失败 / 慢请求 / 空数据。
class _StubCertificationRepository extends CertificationRepository {
  _StubCertificationRepository({
    this.data,
    this.failure,
    this.delay,
    this.faceToken = const FaceTokenResult(
      resultCode: 200,
      token: 'LICENSE-1',
      livenessType: 7,
    ),
  }) : super(_placeholderClient());

  final IdVerificationData? data;
  final Object? failure;
  final Duration? delay;

  /// 活体 token 接口的返回，可换成 `400` 等分支。
  final FaceTokenResult faceToken;

  /// 记录每次请求的产品 id。
  final List<String> identityInfoCalls = [];

  /// 接口文档 `magisterial` 示例的数据口径（客户端原样展示，不做文案映射）。
  static const _defaultData = IdVerificationData(
    recommended: [
      'DRIVINGLICENSE',
      'PRC',
      'SSS',
      'PASSPORT',
      'POSTALID',
      'UMID',
    ],
    other: ['TIN', 'VOTERID', 'NATIONALID', 'PAGIBIG', 'HEALTHCARD'],
  );

  @override
  Future<ApiResponse<IdVerificationData>> getIdentityInfo({
    required String productId,
  }) async {
    identityInfoCalls.add(productId);
    if (delay case final wait?) await Future<void>.delayed(wait);
    if (failure case final error?) throw error;
    return ApiResponse(code: 0, message: 'success', data: data ?? _defaultData);
  }

  /// 挽留弹窗接口的返回：默认没有素材（直接放行返回），
  /// 需要验证挽留弹窗的用例再传 [retentionImageUrl] 等素材。
  String retentionImageUrl = '';
  String retentionContinueText = '';
  String retentionExitText = '';

  /// 记录每次挽留弹窗请求：(产品 id, 类型)。
  final List<(String, String)> retentionCalls = [];

  @override
  Future<ApiResponse<CertificationRetention>> getRetentionPopup({
    required String productId,
    required String type,
  }) async {
    retentionCalls.add((productId, type));
    return ApiResponse(
      code: 0,
      message: 'success',
      data: CertificationRetention(
        imageUrl: retentionImageUrl,
        continueText: retentionContinueText,
        exitText: retentionExitText,
      ),
    );
  }

  /// 记录每次证件上传：(文件路径, 卡类型, 来源)。
  final List<(String, String, IdentityPhotoSource)> uploadCalls = [];

  /// 上传接口识别出的身份信息，口径取接口文档「接口上传(face,身份证正面)（第一项）」
  /// 的 `connectedly` 示例（出生日期后端给的是 `23/11/1993`）。
  static const uploadData = <String, dynamic>{
    'harbingers': 'NAVEEN TOM VARGHESE',
    'approach': '623099344111',
    'counter': '23/11/1993',
    'superidealness': '',
  };

  @override
  Future<ApiResponse<Map<String, dynamic>>> uploadIdentityImage({
    required String filePath,
    required String cardType,
    required IdentityPhotoSource source,
  }) async {
    uploadCalls.add((filePath, cardType, source));
    return ApiResponse(code: 0, message: 'success', data: uploadData);
  }

  /// 记录每次活体 token 请求的订单号。
  final List<String> faceTokenCalls = [];

  @override
  Future<ApiResponse<FaceTokenResult>> getFaceToken({
    required String orderNo,
    int type = 0,
  }) async {
    faceTokenCalls.add(orderNo);
    return ApiResponse(code: 0, message: 'success', data: faceToken);
  }

  /// 记录每次活体上传：(文件路径, livenessId, license, 活体类型)。
  final List<(String, String, String, int)> faceUploadCalls = [];

  @override
  Future<ApiResponse<Map<String, dynamic>>> uploadFaceImage({
    required String filePath,
    required String livenessId,
    required String license,
    required int livenessType,
    String bizId = '',
  }) async {
    faceUploadCalls.add((filePath, livenessId, license, livenessType));
    return const ApiResponse<Map<String, dynamic>>(
      code: 0,
      message: 'success',
      data: {'scabble': 99},
    );
  }

  /// 记录每次保存身份证信息：(姓名, 证件号, 出生日期, 卡类型)。
  final List<(String, String, String, String)> saveCalls = [];

  @override
  Future<ApiResponse<void>> saveIdentityInfo({
    required String name,
    required String idNumber,
    required String birthDate,
    required String cardType,
  }) async {
    saveCalls.add((name, idNumber, birthDate, cardType));
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }

  /// 个人信息表单（认证第二项）：字段 / 控件类型 / 选项口径取接口文档
  /// 「获取用户信息（第二项）」的 `aminate` 示例，覆盖枚举 / 输入 / 地址三种控件。
  static const personalInfoData = PersonalInfoData(
    tips: 'Fill in personal information truthfully and accurately',
    fields: [
      PersonalInfoField(
        title: 'Gender',
        placeholder: 'Gender',
        key: 'copies',
        control: PersonalInfoControl.selection,
        isNumeric: false,
        options: [
          PersonalInfoOption(label: 'male', value: '1'),
          PersonalInfoOption(label: 'female', value: '2'),
        ],
        initialDisplayValue: 'male',
        initialSubmitValue: '1',
      ),
      PersonalInfoField(
        title: 'Email',
        placeholder: 'Please input email',
        key: 'offer',
        control: PersonalInfoControl.text,
        isNumeric: false,
        options: [],
        initialDisplayValue: 'a@b.com',
        initialSubmitValue: 'a@b.com',
      ),
      PersonalInfoField(
        title: 'Home Phone Number',
        placeholder: 'Please enter',
        key: 'hyphal',
        control: PersonalInfoControl.text,
        isNumeric: true,
        options: [],
        initialDisplayValue: '',
        initialSubmitValue: '',
      ),
      PersonalInfoField(
        title: 'Residential Address',
        placeholder: 'Please select address',
        key: 'residential_address',
        control: PersonalInfoControl.address,
        isNumeric: false,
        options: [],
        initialDisplayValue: '',
        initialSubmitValue: '',
      ),
    ],
  );

  /// 地址层级（`GET /outsulk/avern`）：三层，最深一层没有下级。
  static const addressData = AddressInitData(
    nodes: [
      AddressNode(
        id: '1',
        code: '0001',
        name: 'Region I',
        children: [
          AddressNode(
            id: '11',
            code: '00010001',
            name: 'Pangasinan',
            children: [
              AddressNode(
                id: '111',
                code: '000100010001',
                name: 'Alcala',
                children: [],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// 记录每次拉取个人信息表单的产品 id。
  final List<String> personalInfoCalls = [];

  /// 个人信息表单返回，默认走 [personalInfoData]。
  PersonalInfoData? personalInfo;

  /// 置为异常时表单接口直接抛出，用来测错误态。
  Object? personalInfoFailure;

  /// 表单接口延迟，用来测 Loading 态。
  Duration? personalInfoDelay;

  @override
  Future<ApiResponse<PersonalInfoData>> getPersonalInfo({
    required String productId,
  }) async {
    personalInfoCalls.add(productId);
    if (personalInfoDelay case final wait?) await Future<void>.delayed(wait);
    if (personalInfoFailure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: personalInfo ?? personalInfoData,
    );
  }

  /// 记录每次保存个人信息的表单（key 是接口下发的 `crucians`）。
  final List<Map<String, String>> savePersonalInfoCalls = [];

  /// 置为异常时保存接口直接抛出。
  Object? savePersonalInfoFailure;

  @override
  Future<ApiResponse<void>> savePersonalInfo({
    required String productId,
    required Map<String, String> formData,
  }) async {
    savePersonalInfoCalls.add(Map<String, String>.from(formData));
    if (savePersonalInfoFailure case final error?) throw error;
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }

  /// 工作信息表单（认证第三项）：与个人信息同一份字段结构（`aminate`），
  /// 口径取接口文档「获取工作信息（第三项）」，覆盖输入 / 地址 / 枚举三种控件。
  static const workInfoData = PersonalInfoData(
    tips: '',
    fields: [
      PersonalInfoField(
        title: 'Company Name',
        placeholder: 'Please input company name',
        key: 'undauntable',
        control: PersonalInfoControl.text,
        isNumeric: false,
        options: [],
        initialDisplayValue: 'SPSS',
        initialSubmitValue: 'SPSS',
      ),
      PersonalInfoField(
        title: 'City You Work',
        placeholder: 'Please select company address',
        key: 'printed',
        control: PersonalInfoControl.address,
        isNumeric: false,
        options: [],
        initialDisplayValue: '',
        initialSubmitValue: '',
      ),
      PersonalInfoField(
        title: 'Type of Work',
        placeholder: 'Profession',
        key: 'profit',
        control: PersonalInfoControl.selection,
        isNumeric: false,
        options: [
          PersonalInfoOption(label: 'Student', value: '1'),
          PersonalInfoOption(label: 'Police', value: '2'),
        ],
        initialDisplayValue: 'Student',
        initialSubmitValue: '1',
      ),
    ],
  );

  /// 工作信息的发薪日（`Payday`）字段：二级选项口径取接口文档
  /// 「获取工作信息（第三项）」的嵌套 `overwhelming` 示例。
  static const paydayData = PersonalInfoData(
    tips: '',
    fields: [
      PersonalInfoField(
        title: 'Payday',
        placeholder: 'Please select payday',
        key: 'opportunities',
        control: PersonalInfoControl.selection,
        isNumeric: false,
        options: [
          PersonalInfoOption(
            label: 'Daily',
            value: '1',
            children: [PersonalInfoOption(label: 'Daily', value: '1')],
          ),
          PersonalInfoOption(
            label: 'Weekly',
            value: '2',
            children: [
              PersonalInfoOption(label: 'Mon', value: '2'),
              PersonalInfoOption(label: 'Tue', value: '3'),
            ],
          ),
          PersonalInfoOption(
            label: 'Twice per Month',
            value: '3',
            children: [
              PersonalInfoOption(label: 'Payroll Date1:1--15', value: '9'),
            ],
          ),
          PersonalInfoOption(
            label: 'Once a Month',
            value: '4',
            children: [
              PersonalInfoOption(label: '1', value: '11'),
              PersonalInfoOption(label: '2', value: '12'),
            ],
          ),
        ],
        initialDisplayValue: 'Once a Month|2',
        initialSubmitValue: '12',
      ),
    ],
  );

  /// 记录每次拉取工作信息表单的产品 id。
  final List<String> workInfoCalls = [];

  /// 工作信息表单返回，默认走 [workInfoData]。
  PersonalInfoData? workInfo;

  /// 置为异常时工作信息接口直接抛出。
  Object? workInfoFailure;

  /// 工作信息接口延迟，用来测 Loading 态。
  Duration? workInfoDelay;

  @override
  Future<ApiResponse<PersonalInfoData>> getWorkInfo({
    required String productId,
  }) async {
    workInfoCalls.add(productId);
    if (workInfoDelay case final wait?) await Future<void>.delayed(wait);
    if (workInfoFailure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: workInfo ?? workInfoData,
    );
  }

  /// 记录每次保存工作信息的表单（key 是接口下发的 `crucians`）。
  final List<Map<String, String>> saveWorkInfoCalls = [];

  /// 置为异常时保存接口直接抛出。
  Object? saveWorkInfoFailure;

  @override
  Future<ApiResponse<void>> saveWorkInfo({
    required String productId,
    required Map<String, String> formData,
  }) async {
    saveWorkInfoCalls.add(Map<String, String>.from(formData));
    if (saveWorkInfoFailure case final error?) throw error;
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }

  /// 记录地址初始化接口的调用次数。
  int addressInitCalls = 0;

  @override
  Future<ApiResponse<AddressInitData>> getAddressInit() async {
    addressInitCalls++;
    return const ApiResponse<AddressInitData>(
      code: 0,
      message: 'success',
      data: addressData,
    );
  }

  /// 紧急联系人（认证第四项）：三条联系人的口径取接口文档
  /// 「获取联系人信息（第四项）」的 `conopholis.kneeing` 示例。
  static const emergencyContactData = EmergencyContactData(
    tips: 'We will protect your personal information from disclosure',
    contacts: [
      EmergencyContact(
        number: 'first',
        relationValue: '5',
        name: 'Anna',
        mobile: '86543217190',
        relationOptions: _relationOptions,
      ),
      EmergencyContact(
        number: 'second',
        relationValue: '5',
        relationOptions: _relationOptions,
      ),
      EmergencyContact(
        number: 'third',
        relationValue: '5',
        relationOptions: _relationOptions,
      ),
    ],
  );

  /// 关系下拉的选项口径取接口文档的 `colocating` 示例（Parent…other）。
  static const _relationOptions = [
    EmergencyContactOption(label: 'Parent', value: '1'),
    EmergencyContactOption(label: 'Spouse', value: '2'),
    EmergencyContactOption(label: 'Child', value: '3'),
    EmergencyContactOption(label: 'Sibling', value: '4'),
    EmergencyContactOption(label: 'Friend', value: '5'),
    EmergencyContactOption(label: 'Colleague', value: '6'),
    EmergencyContactOption(label: 'other', value: '7'),
  ];

  /// 记录每次拉取紧急联系人的产品 id。
  final List<String> emergencyContactCalls = [];

  /// 紧急联系人返回，默认走 [emergencyContactData]。
  EmergencyContactData? emergencyContacts;

  /// 置为异常时接口直接抛出，用来测错误态。
  Object? emergencyContactFailure;

  /// 接口延迟，用来测 Loading 态。
  Duration? emergencyContactDelay;

  @override
  Future<ApiResponse<EmergencyContactData>> getEmergencyContacts({
    required String productId,
  }) async {
    emergencyContactCalls.add(productId);
    if (emergencyContactDelay case final wait?) {
      await Future<void>.delayed(wait);
    }
    if (emergencyContactFailure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: emergencyContacts ?? emergencyContactData,
    );
  }

  /// 记录每次保存紧急联系人的入参。
  final List<List<EmergencyContactInput>> saveEmergencyContactCalls = [];

  /// 置为异常时保存接口直接抛出。
  Object? saveEmergencyContactFailure;

  @override
  Future<ApiResponse<void>> saveEmergencyContacts({
    required String productId,
    required List<EmergencyContactInput> contacts,
  }) async {
    saveEmergencyContactCalls.add(List<EmergencyContactInput>.from(contacts));
    if (saveEmergencyContactFailure case final error?) throw error;
    return const ApiResponse<void>(code: 0, message: 'success', data: null);
  }

  /// 绑卡表单（认证第五项）：分组 / 字段 / 选项口径取接口文档
  /// 「获取绑卡信息（第五项）」，三个 Tab 与蓝湖稿 03-05 对齐。
  static const bindCardData = BindCardData(
    prompt: '',
    bottomPrompt:
        'Incorrect account numbers cause payout failure. '
        'Double-check all digits.',
    groups: [
      BindCardGroup(
        label: 'E-wallet',
        type: '1',
        fields: [
          BindCardField(
            title: 'Select your recipient E-wallet',
            placeholder: 'Please select',
            key: 'channelCode',
            control: BindCardControl.selection,
            options: [
              BindCardOption(
                label: 'GCash e-wallet',
                value: 'GCASH',
                logoUrl: 'https://cdn.test/gcash.png',
                available: false,
              ),
              BindCardOption(
                label: 'PayMaya e-wallet',
                value: 'PAYMAYA',
                logoUrl: 'https://cdn.test/paymaya.png',
                available: true,
              ),
              BindCardOption(
                label: 'GrabPay e-wallet',
                value: 'GRABPAY',
                logoUrl: 'https://cdn.test/grabpay.png',
                available: true,
              ),
            ],
            isNumeric: false,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
          BindCardField(
            title: 'First name',
            placeholder: 'Please enter',
            key: 'firstName',
            control: BindCardControl.text,
            options: [],
            isNumeric: false,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: 'Anna',
          ),
          BindCardField(
            title: 'Middle name',
            placeholder: 'Please enter',
            key: 'middleName',
            control: BindCardControl.text,
            options: [],
            isNumeric: false,
            isOptional: true,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
          BindCardField(
            title: 'Last name',
            placeholder: 'Please enter',
            key: 'lastName',
            control: BindCardControl.text,
            options: [],
            isNumeric: false,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
          BindCardField(
            title: 'E-wallet Account',
            placeholder: 'Please enter your E-Wallet account',
            key: 'cardNo',
            control: BindCardControl.text,
            options: [],
            isNumeric: true,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
          BindCardField(
            title: 'Repeat E-wallet Account',
            placeholder: 'Ensure the account number is correct',
            key: 'confirmCardNo',
            control: BindCardControl.text,
            options: [],
            isNumeric: true,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
        ],
      ),
      BindCardGroup(
        label: 'Outstanding',
        type: '2',
        fields: [
          BindCardField(
            title: 'Select your recipient Bank',
            placeholder: 'Please select',
            key: 'channelCode',
            control: BindCardControl.selection,
            options: [
              BindCardOption(
                label: 'BDO Unibank',
                value: 'BDO',
                logoUrl: '',
                available: true,
              ),
            ],
            isNumeric: false,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
          BindCardField(
            title: 'Bank Account',
            placeholder: 'Please enter your bank account',
            key: 'cardNo',
            control: BindCardControl.text,
            options: [],
            isNumeric: true,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
        ],
      ),
      BindCardGroup(
        label: 'Overdue',
        type: '3',
        fields: [
          BindCardField(
            title: 'Overdue Account',
            placeholder: 'Please enter your account',
            key: 'cardNo',
            control: BindCardControl.text,
            options: [],
            isNumeric: true,
            isOptional: false,
            initialDisplayValue: '',
            initialSubmitValue: '',
            suggestedValue: '',
          ),
        ],
      ),
    ],
  );

  /// 记录每次拉取绑卡表单的产品 id。
  final List<String> bindCardInfoCalls = [];

  /// 绑卡表单返回，默认走 [bindCardData]。
  BindCardData? bindCard;

  /// 置为异常时绑卡表单接口直接抛出，用来测错误态。
  Object? bindCardFailure;

  /// 接口延迟，用来测 Loading 态。
  Duration? bindCardDelay;

  @override
  Future<ApiResponse<BindCardData>> getBindCardInfo({
    required String productId,
  }) async {
    bindCardInfoCalls.add(productId);
    if (bindCardDelay case final wait?) await Future<void>.delayed(wait);
    if (bindCardFailure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: bindCard ?? bindCardData,
    );
  }

  /// 每次提交绑卡的入参（渠道字段已在仓库层改名成 `entertainer`）。
  final List<
    ({
      String cardType,
      Map<String, String> fields,
      String faceType,
      String livenessId,
      String image,
      String license,
    })
  >
  submitBindCardCalls = [];

  /// 逐次返回的提交状态码：第一个 `20000` 触发活体，随后成功。
  List<int> submitBindCardCodes = const [0];

  /// 置为异常时提交接口直接抛出。
  Object? submitBindCardFailure;

  @override
  Future<ApiResponse<Map<String, dynamic>>> submitBindCard({
    required String productId,
    required String cardType,
    required Map<String, String> fields,
    String faceType = '',
    String livenessId = '',
    String image = '',
    String bizId = '',
    String license = '',
  }) async {
    submitBindCardCalls.add((
      cardType: cardType,
      fields: Map<String, String>.from(fields),
      faceType: faceType,
      livenessId: livenessId,
      image: image,
      license: license,
    ));
    if (submitBindCardFailure case final error?) throw error;
    final index = submitBindCardCalls.length - 1;
    final code = index < submitBindCardCodes.length
        ? submitBindCardCodes[index]
        : 0;
    return ApiResponse(
      code: code,
      message: code == 0 ? 'success' : 'Liveness required',
      data: const {'moonshade': 123},
    );
  }

  /// 记录每次拉取用户账户列表的产品 id。
  final List<String> userAccountsCalls = [];

  /// 账户列表返回，默认走 [loanAccountsData]；置为异常测错误态。
  LoanConfirmData? userAccounts;
  Object? userAccountsFailure;
  Duration? userAccountsDelay;

  /// 接口文档「用户账户列表」示例口径：Bank（默认选中且维护中）/ E-wallet /
  /// Cash Pickup 三组，覆盖两种排版与 `isMain` 预选。
  static const loanAccountsData = LoanConfirmData(
    selectedId: '555',
    groups: [
      LoanAccountGroup(
        title: 'Bank',
        accounts: [
          LoanAccount(
            id: '555',
            name: 'BDO',
            available: false,
            isMain: true,
            receiptAccount: '5490163575561234',
            logoUrl: 'https://x/bdo.png',
          ),
        ],
      ),
      LoanAccountGroup(
        title: 'E-wallet',
        accounts: [
          LoanAccount(
            id: '556',
            name: 'GCash',
            receiptAccount: '5490163575561234',
          ),
        ],
      ),
      LoanAccountGroup(
        title: 'Cash Pickup',
        accounts: [
          LoanAccount(
            id: '557',
            name: 'M Lhuillier',
            kind: LoanAccountKind.cashPickup,
            firstName: 'Anna',
            middleName: 'Oliver',
            lastName: 'Mark',
          ),
        ],
      ),
    ],
  );

  @override
  Future<ApiResponse<LoanConfirmData>> getUserAccounts({
    required String productId,
  }) async {
    userAccountsCalls.add(productId);
    if (userAccountsDelay case final wait?) await Future<void>.delayed(wait);
    if (userAccountsFailure case final error?) throw error;
    return ApiResponse(
      code: 0,
      message: 'success',
      data: userAccounts ?? loanAccountsData,
    );
  }

  /// 每次提交换绑的入参。
  final List<({String orderNo, String bindId})> changeBankCardCalls = [];

  /// 置为异常时换绑接口直接抛出。
  Object? changeBankCardFailure;

  /// 换绑成功返回的订单详情页地址。
  String changeBankCardUrl = 'https://h5.example.com/order/1';

  @override
  Future<ApiResponse<String>> changeBankCard({
    required String orderNo,
    required String bindId,
  }) async {
    changeBankCardCalls.add((orderNo: orderNo, bindId: bindId));
    if (changeBankCardFailure case final error?) throw error;
    return ApiResponse(code: 0, message: 'success', data: changeBankCardUrl);
  }

  /// 每次「原卡重试确认订单」的订单号。
  final List<String> retryOrderCalls = [];

  /// 置为异常时重试接口直接抛出。
  Object? retryOrderFailure;

  /// 重试成功返回的订单详情页地址。
  String retryOrderUrl = 'https://h5.example.com/order/9';

  @override
  Future<ApiResponse<String>> retryOrderConfirm({
    required String orderNo,
  }) async {
    retryOrderCalls.add(orderNo);
    if (retryOrderFailure case final error?) throw error;
    return ApiResponse(code: 0, message: 'success', data: retryOrderUrl);
  }
}

/// 证件照服务桩：不弹系统 UI，直接返回固定路径。
class _StubIdentityPhotoService extends IdentityPhotoService {
  static const pickedPath = '/tmp/id-card.jpg';

  final List<IdentityPhotoSource> pickCalls = [];

  @override
  Future<String?> pick(IdentityPhotoSource source) async {
    pickCalls.add(source);
    return pickedPath;
  }

  @override
  Future<String?> compressToLimit(String path) async => path;
}

/// 活体人脸图（base64）桩数据：内容不重要，页面只是把它落盘再上传。
const _faceImageBase64 = 'ZmFrZS1mYWNl';

/// 活体网关桩：不弹原生 SDK，直接返回可配的结果。
class _StubLivenessGateway extends LivenessGateway {
  _StubLivenessGateway({
    this.outcome = const LivenessOutcome(
      passed: true,
      livenessId: 'LIVE-1',
      imageBase64: _faceImageBase64,
    ),
  });

  final LivenessOutcome outcome;

  /// 记录每次传入 SDK 的授权码。
  final List<String> licenses = [];

  @override
  Future<LivenessOutcome> run(String license) async {
    licenses.add(license);
    return outcome;
  }
}

/// 产品申请仓库桩：记录准入调用，返回可配的准入 / 详情结果。
class _StubProductRepository extends ProductRepository {
  _StubProductRepository({
    this.applyResult = const ProductApplyResult(
      statusCode: 200,
      jumpUrl: '',
      jumpType: 0,
      message: '',
    ),
    this.detail = const ProductDetail(
      resultCode: 200,
      basicInfo: ProductBasicInfo(orderNo: 'ORDER-1'),
      nextStep: ProductNextStep(taskType: 'Kegful', title: 'Identity'),
    ),
  }) : super(_placeholderClient());

  final ProductApplyResult applyResult;
  final ProductDetail detail;

  /// 认证全部完成后 `getOrderPushUrl` 换回的确认用款 H5 地址。
  String pushUrl = 'https://h5.example.com/confirm/1';

  /// (productId, apiRemind)
  final List<(String, int)> applyCalls = [];
  int detailCalls = 0;
  int pushUrlCalls = 0;

  @override
  Future<ApiResponse<ProductApplyResult>> applyProduct({
    required String productId,
    int apiRemind = 0,
  }) async {
    applyCalls.add((productId, apiRemind));
    return ApiResponse(code: 0, message: 'success', data: applyResult);
  }

  @override
  Future<ApiResponse<ProductDetail>> getProductDetail({
    required String productId,
  }) async {
    detailCalls++;
    return ApiResponse(code: 0, message: 'success', data: detail);
  }

  @override
  Future<ApiResponse<String>> getOrderPushUrl({
    required String orderNo,
    required String amount,
    required String loanTerm,
    required String termType,
  }) async {
    pushUrlCalls++;
    return ApiResponse(code: 0, message: 'success', data: pushUrl);
  }
}

HttpClient _placeholderClient() {
  return HttpClient(
    config: NetworkConfig(
      apiBase: Uri.parse('https://localhost/'),
      signSecret: 'test',
      marketIdentifier: 'test',
    ),
    device: const DeviceParams(
      deviceId: 'test-device',
      appVersion: '1.0.0',
      modelName: 'test',
      systemVersion: '1.0',
      advertisingId: '',
    ),
    getUserToken: () => null,
    onAuthExpired: () {},
  );
}

/// 只记录请求、不发网络，用来校验仓库层传出的字段名。
class _RecordingClient extends HttpClient {
  _RecordingClient()
    : super(
        config: NetworkConfig(
          apiBase: Uri.parse('https://localhost/'),
          signSecret: 'test',
          marketIdentifier: 'test',
        ),
        device: const DeviceParams(
          deviceId: 'test-device',
          appVersion: '1.0.0',
          modelName: 'test',
          systemVersion: '1.0',
          advertisingId: '',
        ),
        getUserToken: () => null,
        onAuthExpired: () {},
      );

  final List<(String, Map<String, Object?>)> calls = [];

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    required Map<String, Object?> params,
    required T Function(Object? data) parse,
  }) async {
    calls.add((path, params));
    return ApiResponse<T>(code: 0, message: 'success', data: parse(null));
  }

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, Object?>? params,
    required T Function(Object? data) parse,
  }) async {
    calls.add((path, params ?? const {}));
    return ApiResponse<T>(code: 0, message: 'success', data: parse(null));
  }

  final List<(String, String, Map<String, Object?>)> uploads = [];

  @override
  Future<ApiResponse<T>> upload<T>(
    String path, {
    required String filePath,
    required String fileField,
    required Map<String, Object?> fields,
    required T Function(Object? data) parse,
  }) async {
    uploads.add((path, fileField, fields));
    return ApiResponse<T>(code: 0, message: 'success', data: parse(null));
  }
}

/// 会带固定业务数据回调 [parse] 的记录客户端，用来验证解析分支。
class _PayloadRecordingClient extends _RecordingClient {
  _PayloadRecordingClient(this.payload);

  final Object? payload;

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    required Map<String, Object?> params,
    required T Function(Object? data) parse,
  }) async {
    calls.add((path, params));
    return ApiResponse<T>(code: 0, message: 'success', data: parse(payload));
  }
}

/// 首页额度大卡 + 授信进度阶段（蓝湖稿 02-01 / 02-02 的 LARGE_CARD）。
const _productCard = HomeProductCard(
  id: '1',
  productName: 'Pera Cash',
  productLogo: '',
  buttonText: 'Apply Now',
  amountRange: '\u20b160,000',
  amountRangeDes: 'Available up to',
  termInfo: '180 Days',
  termInfoDes: 'Loan terms',
  loanRate: '\u2264 0.5% Day',
  loanRateDes: 'Interest rate',
  certifyFinished: false,
  account: '',
  accountText: '',
  progressText: 'Credit activation progress',
  steps: [
    HomeProgressStep(
      title: 'Identity',
      amount: '\u20b1 30,000',
      selected: true,
    ),
    HomeProgressStep(title: 'Living', amount: '\u20b1 40,000', selected: false),
    HomeProgressStep(
      title: 'Basic information',
      amount: '\u20b150,000',
      selected: false,
    ),
    HomeProgressStep(
      title: 'Bank Card',
      amount: '\u20b160,000',
      selected: false,
    ),
  ],
);

/// 两个阶段已解锁（`estamp` = 1）的进度卡，用来验证多段解锁。
const _productCardTwoUnlocked = HomeProductCard(
  id: '1',
  productName: 'Pera Cash',
  productLogo: '',
  buttonText: 'Apply Now',
  amountRange: '\u20b160,000',
  amountRangeDes: 'Available up to',
  termInfo: '180 Days',
  termInfoDes: 'Loan terms',
  loanRate: '\u2264 0.5% Day',
  loanRateDes: 'Interest rate',
  certifyFinished: false,
  account: '',
  accountText: '',
  progressText: 'Credit activation progress',
  steps: [
    HomeProgressStep(
      title: 'Identity',
      amount: '\u20b1 30,000',
      selected: true,
    ),
    HomeProgressStep(title: 'Living', amount: '\u20b1 40,000', selected: true),
    HomeProgressStep(
      title: 'Basic information',
      amount: '\u20b150,000',
      selected: false,
    ),
    HomeProgressStep(
      title: 'Bank Card',
      amount: '\u20b160,000',
      selected: false,
    ),
  ],
);

/// 进行中的借款订单卡。
const _orderCard = HomeOrderCard(
  orderNo: '39236372837263237',
  productId: 1,
  productName: 'Pera Agad(AA)',
  productLogo: '',
  title: 'Already in default, please repay',
  displayAmount: '\u20b150,000',
  amountText: 'Loan Amount',
  date: '28-12-2022',
  dateText: 'Application date',
  orderStatusText: 'To repay',
  status: HomeOrderCardStatus.toRepay,
  progressText: '',
  steps: [],
  jumpUrl: '',
);

/// 推荐列表里的产品卡（蓝湖稿 02-01 的 PRODUCT_LIST 模块）。
const _recommendationCard = HomeProductListCard(
  id: '1',
  productName: 'PG Finance',
  productLogo: '',
  amountRange: '\u20b160,000',
  amountRangeDes: 'Available up to',
  loanRate: '\u2264 0.5% Day',
  loanRateDes: 'Interest rate',
  termInfo: '\u2264 0.5% Day',
  termInfoText: 'Loan terms',
  tips: ['Low interest rates', 'Ages 17 years and over can borrow'],
  buttonStyle: HomeProductCardButtonStyle.highlighted,
);

void _usePhoneSurface(WidgetTester tester) {
  // 默认的 800x600 测试窗口会把页面下半部分裁掉，断言会失真。
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// permission_handler 的 method channel：测试里没有原生实现，
/// 需要按用例把相机权限状态伪造出来（1=granted，0=denied，4=permanentlyDenied）。
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

int _cameraSettingsOpened = 0;

void _mockCameraPermission(int status) {
  _cameraSettingsOpened = 0;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_permissionChannel, (call) async {
        switch (call.method) {
          case 'checkPermissionStatus':
            return status;
          case 'requestPermissions':
            return {for (final id in call.arguments as List) id: status};
          case 'openAppSettings':
            _cameraSettingsOpened++;
            return true;
          default:
            return null;
        }
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });
}

/// flutter_native_contact_picker 的 method channel：测试里没有原生实现，
/// 需要按用例把用户选中的联系人伪造出来（系统选人面板不需要通讯录权限）。
const _contactPickerChannel = MethodChannel('flutter_native_contact_picker');

void _mockPickedContact({required String name, required String phone}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_contactPickerChannel, (call) async {
        if (call.method == 'selectContact') {
          return <String, Object?>{
            'fullName': name,
            'selectedPhoneNumber': phone,
          };
        }
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_contactPickerChannel, null);
  });
}

/// 上传页 / 上传方式面板按 375pt 设计稿等比换算的缩放系数
/// （测试机宽 402pt，`AppLayout` 上限 1.2 倍还没触顶）。
const _designScale = 402 / 375;

/// 直接打开证件上传页（走和证件选择页一样的路由与入参）。
void _openIdUploadPage(
  WidgetTester tester, {
  String productId = '7',
  String cardType = 'PRC',
}) {
  AppNavigator.push(
    AppRoutes.idUpload,
    arguments: IdUploadPageArguments(productId: productId, cardType: cardType),
  );
}

/// 接口文档里识别出的身份信息示例（出生日期已归一成保存接口要求的 d-m-Y）。
const _recognition = IdentityRecognition(
  name: 'NAVEEN TOM VARGHESE',
  idNumber: '623099344111',
  birthDate: '23-11-1993',
);

/// 直接打开证件信息确认页（走和上传页一样的路由与入参）。
void _openIdConfirmPage(
  WidgetTester tester, {
  String productId = '7',
  String cardType = 'PRC',
  IdentityRecognition recognition = _recognition,
  String orderNo = '',
}) {
  AppNavigator.push(
    AppRoutes.idConfirm,
    arguments: IdConfirmPageArguments(
      productId: productId,
      cardType: cardType,
      recognition: recognition,
      orderNo: orderNo,
    ),
  );
}

/// 直接打开人脸识别页（走和产品申请流程一样的路由与入参）。
void _openFaceVerificationPage(
  WidgetTester tester, {
  String productId = '7',
  String orderNo = 'ORDER-1',
}) {
  AppNavigator.push(
    AppRoutes.faceVerification,
    arguments: FaceVerificationPageArguments(
      productId: productId,
      orderNo: orderNo,
    ),
  );
}

/// 直接打开个人信息认证页（走和产品申请流程一样的路由与入参）。
void _openPersonalInfoPage(
  WidgetTester tester, {
  String productId = '7',
  String orderNo = '',
}) {
  AppNavigator.push(
    AppRoutes.personalInfo,
    arguments: PersonalInfoPageArguments(
      productId: productId,
      orderNo: orderNo,
    ),
  );
}

/// 直接打开工作信息认证页（走和产品申请流程一样的路由与入参）。
void _openWorkInfoPage(WidgetTester tester, {String productId = '7'}) {
  AppNavigator.push(
    AppRoutes.workInfo,
    arguments: WorkInfoPageArguments(productId: productId),
  );
}

/// 页面级用例用的挽留拦截器：全局 Loading 换成空实现。
///
/// BotToast 的 Loading 是全局单例，用例之间会互相影响（上一个用例的插入动画
/// 会让下一个用例的 `pumpAndSettle` 等不到静止帧），所以这里点掉它。
CertificationRetentionGuard _noopLoadingGuard(
  CertificationRepository repository,
) {
  return CertificationRetentionGuard(
    repository: repository,
    showLoading: () {},
    hideLoading: () {},
  );
}

/// 点顶部导航行的返回图标（热区 40x40，点图标本身即可命中）。
Future<void> _tapNavBarBack(WidgetTester tester) {
  return tester.tap(
    find.descendant(
      of: find.byType(BackNavBar),
      matching: _assetImage(AppAssets.back),
    ),
  );
}

/// 直接打开紧急联系人认证页（走和产品申请流程一样的路由与入参）。
void _openEmergencyContactPage(
  WidgetTester tester, {
  String productId = '7',
  String orderNo = '',
}) {
  AppNavigator.push(
    AppRoutes.emergencyContact,
    arguments: EmergencyContactPageArguments(
      productId: productId,
      orderNo: orderNo,
    ),
  );
}

/// 直接打开绑卡认证页（走和产品申请流程一样的路由与入参）。
void _openBindCardPage(
  WidgetTester tester, {
  String productId = '7',
  String orderNo = 'ORDER-1',
  bool isAccountChange = false,
}) {
  AppNavigator.push(
    AppRoutes.bindCard,
    arguments: BindCardPageArguments(
      productId: productId,
      orderNo: orderNo,
      isAccountChange: isAccountChange,
    ),
  );
}

/// 填满绑卡页 E-wallet 分组的必填项（渠道 / 名 / 姓 / 账号 / 确认账号）。
Future<void> _fillBindCardForm(
  WidgetTester tester, {
  String channel = 'PAYMAYA',
  String firstName = 'Anna',
  String lastName = 'Cruz',
  String account = '1234567890',
  String? confirm,
}) async {
  await tester.tap(find.byKey(const Key('bind-card-field-channelCode')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('bind-card-option-$channel')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('bind-card-option-done')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('bind-card-field-firstName')),
    firstName,
  );
  await tester.enterText(
    find.byKey(const Key('bind-card-field-lastName')),
    lastName,
  );
  await tester.enterText(
    find.byKey(const Key('bind-card-field-cardNo')),
    account,
  );
  await tester.enterText(
    find.byKey(const Key('bind-card-field-confirmCardNo')),
    confirm ?? account,
  );
  await tester.pumpAndSettle();
}

/// 读取登录页协议行的勾选切图，用来判断当前是否勾选。
String _loginCheckboxAsset(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byKey(const Key('login-agreement-checkbox')),
      matching: find.byType(Image),
    ),
  );
  return (image.image as AssetImage).assetName;
}

/// 页面上某张切图资源（按 [AppAssets] 常量找）。
Finder _assetImage(String assetName) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == assetName,
);

/// 登录页底部运营 Banner（文案已含在切图里）。
Finder _loginBanner() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == AppAssets.loginBanner,
);

/// 登录输入框当前的文本。
String _loginFieldValue(WidgetTester tester, Key fieldKey) {
  return tester.widget<TextField>(find.byKey(fieldKey)).controller!.text;
}

/// 某个登录输入框当前是否持有焦点（有焦点即键盘会弹出）。
bool _loginFieldFocused(WidgetTester tester, Key fieldKey) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(EditableText),
    ),
  );
  return editable.focusNode.hasFocus;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  AppRepository? repository,
  AuthRepository? authRepository,
  ProductRepository? productRepository,
  CertificationRepository? certificationRepository,
  CertificationRetentionGuard? certificationRetentionGuard,
  IdentityPhotoService? identityPhotoService,
  LivenessGateway? livenessGateway,
  Future<void> Function(ProviderContainer container)? setUp,
}) async {
  _usePhoneSurface(tester);
  const app = LayaCreditApp();

  // 只建一个容器：嵌套 UncontrolledProviderScope + ProviderScope 会让
  // override 落在子容器上，父容器里的 session 与仓库对不上，测试结论会失真。
  final container = ProviderContainer(
    overrides: [
      // 测试进程里没有 device_info_plus / package_info_plus 的原生实现，
      // 真跑 DeviceParamsLoader 会一直等插件回调、挂到 8 秒超时后留下未完成的定时器。
      // 直接给一份固定设备信息，顺带让「APP Version」这类展示变得可断言。
      deviceParamsProvider.overrideWith(
        (ref) async => const DeviceParams(
          deviceId: 'test-device',
          appVersion: '1.0.0',
          modelName: 'iPhone',
          systemVersion: '18.2',
          advertisingId: '',
        ),
      ),
      if (repository != null)
        appRepositoryProvider.overrideWith((ref) async => repository),
      if (authRepository != null)
        authRepositoryProvider.overrideWith((ref) async => authRepository),
      if (productRepository != null)
        productRepositoryProvider.overrideWith(
          (ref) async => productRepository,
        ),
      if (certificationRepository != null)
        certificationRepositoryProvider.overrideWith(
          (ref) async => certificationRepository,
        ),
      // 挽留拦截器里的全局 Loading 是 BotToast 的全局单例，用例之间会互相
      // 影响（上一个用例的插入动画会让下一个用例的 `pumpAndSettle` 等不到静止帧），
      // 所以页面级用例直接注入一个空 Loading 的拦截器。
      if (certificationRetentionGuard != null)
        certificationRetentionGuardProvider.overrideWith(
          (ref) async => certificationRetentionGuard,
        ),
      if (identityPhotoService != null)
        identityPhotoServiceProvider.overrideWithValue(identityPhotoService),
      if (livenessGateway != null)
        livenessGatewayProvider.overrideWithValue(livenessGateway),
    ],
  );
  addTearDown(container.dispose);

  if (setUp != null) await setUp(container);

  // 申请流程会先做定位检查：测试进程里没有 permission_handler 原生实现，
  // 默认按「已授权」放行，避免准入被误拦（对应用例可自行覆盖）。
  final previousLocationChecker = ProductApplicationFlow.locationChecker;
  ProductApplicationFlow.locationChecker = () async =>
      CertificationLocationDecision.granted;
  addTearDown(
    () => ProductApplicationFlow.locationChecker = previousLocationChecker,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}

/// 假装弹出的键盘高度（pt）。
const _keyboard = 330.0;

/// 把 [ReportService.current] 换成走 [client] 的记录版，用来断言页面埋点请求。
///
/// 测试里的 App 根没挂 `ReportLifecycleHost`，`ReportService.current` 默认为空，
/// 页面的 `ReportService.current?.reportRisk(...)` 不会真的发请求，所以手动注入。
void _useRecordingReportService(_RecordingClient client) {
  ReportService.reset();
  ReportService.current = ReportService(
    ReportRepository(client),
    ReportBridge(),
    store: ReportStore.memory(),
    encryptKey: '0123456789abcdef',
    encryptIv: '0123456789abcdef',
    accessToken: () => 'token',
  );
  addTearDown(ReportService.reset);
}

void main() {
  testWidgets('首页渲染标题与底部导航', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    expect(find.text('Laya Credit'), findsOneWidget);
    expect(find.byKey(const Key('app-tab-bar')), findsOneWidget);
  });

  testWidgets('悬浮底部导航不遮挡首页内容', (tester) async {
    const safeBottom = 34.0;
    // 真机底部安全区（刘海屏 34pt）：底栏在安全区之上再让出胶囊的高度。
    tester.view.padding = const FakeViewPadding(bottom: safeBottom * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: safeBottom * 3);
    // 内容必须比屏幕高，才能验证「滚到底之后不被胶囊挡住」。
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: _productCard,
          notices: [],
          orders: [_orderCard, _orderCard],
        ),
      ),
    );

    final bar = find.byKey(const Key('app-tab-bar'));
    final barRect = tester.getRect(bar);
    final pillRect = tester.getRect(find.byKey(const Key('app-tab-bar-pill')));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // 底栏自身高度就是页面要避让的遮挡高度（胶囊 + 下间距 + 安全区），
    // 各 Tab 页照着这个值预留底部内边距，两边必须一致。
    expect(
      barRect.height,
      moreOrLessEquals(AppTabBar.overlapHeight(tester.element(bar))),
    );
    expect(barRect.height, greaterThan(pillRect.height + safeBottom));
    expect(pillRect.top, moreOrLessEquals(barRect.top));

    // 内容铺到屏幕底部（extendBody），从胶囊下方穿过，而不是被截在胶囊顶边。
    final listRect = tester.getRect(
      find.descendant(
        of: find.byType(HomePage),
        matching: find.byType(ListView),
      ),
    );
    expect(listRect.bottom, moreOrLessEquals(screenHeight));

    // 滚到底后最后一条内容停在胶囊上方，不会被永久遮住。
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    final lastCard = find.text('Already in default, please repay').last;
    expect(tester.getRect(lastCard).bottom, lessThanOrEqualTo(pillRect.top));
  });

  testWidgets('首页没有产品大卡时只渲染运营位，不出现设计稿以外的空态卡', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    expect(find.byKey(const Key('home-banner')), findsOneWidget);
    // 设计稿 02-01 只有「额度头图 + 运营位」，没有空态卡与兜底申请按钮
    // （02-03 的进度空态属于进度页）。
    expect(find.text('No loan in progress'), findsNothing);
    expect(find.byKey(const Key('home-apply-button')), findsNothing);
  });

  testWidgets('首页按设计稿 02-02 渲染授信进度卡', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: _productCard,
          orders: [],
          notices: [],
        ),
      ),
    );

    // 卡片视觉是设计稿导出的整卡底图（标题文字烘焙在底图里），页面只叠三行内容。
    expect(find.byKey(const Key('home-progress-card')), findsOneWidget);
    expect(find.text('Credit activation progress'), findsNothing);
    expect(find.text('\u20b1 30,000'), findsOneWidget);
    // \u20b160,000 在额度头图里也有一份，进度卡里是第 4 个阶段。
    expect(find.text('\u20b150,000'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Bank Card'), findsOneWidget);
    // 金额 / 文案要同轴，并且都居中在进度槽对应的阶段金币上（设计稿 02-02）：
    // 金币第一枚距卡左边缘 24pt、间距 90.5pt、宽 21.7pt。
    final card = find.byKey(const Key('home-progress-card'));
    final cardRect = tester.getRect(card);
    final scale = cardRect.width / 343;
    final stages = [
      ('\u20b1 30,000', 'Identity'),
      ('\u20b1 40,000', 'Living'),
      ('\u20b150,000', 'Basic information'),
      ('\u20b160,000', 'Bank Card'),
    ];
    for (final (index, (amount, label)) in stages.indexed) {
      final expected = cardRect.left + (24 + index * 90.5 + 21.7 / 2) * scale;
      final amountCenter = tester.getCenter(
        find.descendant(of: card, matching: find.text(amount)),
      );
      final labelCenter = tester.getCenter(
        find.descendant(of: card, matching: find.text(label)),
      );
      expect(amountCenter.dx, moreOrLessEquals(expected, epsilon: 1));
      expect(labelCenter.dx, moreOrLessEquals(expected, epsilon: 1));
      expect(amountCenter.dx, moreOrLessEquals(labelCenter.dx, epsilon: 0.5));
    }
    // 申请入口在额度卡里，只此一处。
    expect(find.byKey(const Key('home-apply-button')), findsOneWidget);
  });

  testWidgets('首页进度卡按 estamp 点亮所有已解锁阶段', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: _productCardTwoUnlocked,
          orders: [],
          notices: [],
        ),
      ),
    );

    final card = find.byKey(const Key('home-progress-card'));
    Color? amountColor(String text) => tester
        .widget<Text>(find.descendant(of: card, matching: find.text(text)))
        .style
        ?.color;

    // 前两项 estamp=1：两段金额都高亮，未解锁的第 3 项仍是深灰。
    expect(amountColor('\u20b1 40,000'), AppColors.creditProgressAmountCurrent);
    expect(amountColor('\u20b1 30,000'), AppColors.creditProgressAmountCurrent);
    expect(amountColor('\u20b150,000'), AppColors.creditProgressAmount);

    // 进度槽填充到第 2 个阶段（2/4）。
    Finder box(Color color) => find.descendant(
      of: card,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == color,
      ),
    );
    final trackWidth = tester.getSize(box(AppColors.creditProgressTrack)).width;
    final fillWidth = tester.getSize(box(AppColors.creditProgressFill)).width;
    expect(fillWidth / trackWidth, moreOrLessEquals(0.5, epsilon: 0.01));
  });

  testWidgets('首页有进行中订单时展示借款进度卡', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: null,
          notices: [],
          orders: [
            HomeOrderCard(
              orderNo: '39236372837263237',
              productId: 1,
              productName: 'Pera Agad(AA)',
              productLogo: '',
              title: 'Already in default, please repay',
              displayAmount: '\u20b150,000',
              amountText: 'Loan Amount',
              date: '28-12-2022',
              dateText: 'Application date',
              orderStatusText: 'To repay',
              status: HomeOrderCardStatus.toRepay,
              progressText: '',
              steps: [],
              jumpUrl: '',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Already in default, please repay'), findsOneWidget);
    expect(find.text('\u20b150,000'), findsOneWidget);
  });

  testWidgets('首页按设计稿 02-01 渲染推荐列表，标题右侧不出现 More 与箭头', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: null,
          orders: [],
          notices: [],
          productList: [_recommendationCard],
        ),
      ),
    );

    expect(find.text('Recommendation'), findsOneWidget);
    // 设计稿标题右侧的「More + 箭头」按产品要求不渲染。
    expect(find.text('More'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    expect(find.text('PG Finance'), findsOneWidget);
    expect(find.text('\u20b160,000'), findsOneWidget);
    expect(find.text('Available up to'), findsOneWidget);
    expect(find.text('Interest rate'), findsOneWidget);
    expect(find.text('Loan terms'), findsOneWidget);
    expect(
      find.text('Low interest rates / Ages 17 years and over can borrow'),
      findsOneWidget,
    );

    // 按钮是整块切图，按后端 `holts` 选三态配色（这里是高亮）。
    final button = tester.widget<Image>(
      find.byKey(const ValueKey('home-recommendation-apply-1')),
    );
    expect(
      (button.image as AssetImage).assetName,
      AppAssets.homeApplyNowHighlight,
    );
  });

  testWidgets('首页推荐卡整块可点击：点空白处同样走申请流程', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: null,
          orders: [],
          notices: [],
          productList: [_recommendationCard],
        ),
      ),
    );

    await tester.tap(find.text('PG Finance'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('首页没有推荐列表时整块不渲染，不出现空态标题', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    expect(find.text('Recommendation'), findsNothing);
  });

  testWidgets('首页额度头图渲染后端下发的产品、额度、期限与申请入口', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: HomeProductCard(
            id: '1',
            productName: 'Pera Cash',
            productLogo: '',
            buttonText: 'Apply Now',
            amountRange: '\u20b160,000',
            amountRangeDes: 'Available up to',
            termInfo: '180 Days',
            termInfoDes: 'Loan terms',
            loanRate: '\u2264 0.5% Day',
            loanRateDes: 'Interest rate',
            certifyFinished: false,
            account: '',
            accountText: '',
            progressText: '',
            steps: [],
          ),
        ),
      ),
    );

    expect(find.text('Pera Cash'), findsOneWidget);
    expect(find.text('\u20b160,000'), findsOneWidget);
    expect(find.text('Available up to'), findsOneWidget);
    expect(find.text('180 Days'), findsOneWidget);
    expect(find.text('\u2264 0.5% Day'), findsOneWidget);
    expect(find.text('Apply Now'), findsOneWidget);
    expect(find.text('Confirm your loan\uFF0CCash hits fast.'), findsOneWidget);
    // 申请入口在额度卡里，不再额外渲染兜底按钮。
    expect(find.byKey(const Key('home-apply-button')), findsOneWidget);
  });

  testWidgets('首页额度大卡整块可点击：点空白区域同样进入申请流程', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
    );

    // 点在卡片上的非按钮区域（期限文案），而不是 Apply 按钮。
    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    // 游客点击整卡会走和按钮一致的登录引导。
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('首页运营位多条 banner 自动轮播', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [
            HomeBanner(
              id: '1',
              imageUrl: 'https://cdn.example.com/a.png',
              jumpUrl: '',
            ),
            HomeBanner(
              id: '2',
              imageUrl: 'https://cdn.example.com/b.png',
              jumpUrl: '',
            ),
          ],
          product: null,
          orders: [],
          notices: [],
        ),
      ),
    );

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    final start = controller.page!;

    // 每 3 秒切到下一条：等一拍定时器 + 300ms 切换动画。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 350));

    expect(controller.page, closeTo(start == 0 ? 1 : 0, 0.01));

    // 卸载页面，取消轮播定时器，避免测试结束时留下 pending timer。
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('首页接口失败时展示错误态而不是闪退', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        failure: const ApiException(
          type: ApiFailureType.noConnection,
          message: '网络连接失败，请检查网络设置',
        ),
      ),
    );

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('网络连接失败，请检查网络设置'), findsOneWidget);
  });

  test('首页并发刷新时只采纳最后一次请求的结果', () async {
    final repository = _ControllableHomeRepository();
    final container = ProviderContainer(
      overrides: [
        appRepositoryProvider.overrideWith((ref) async => repository),
        // 遮蔽真实 BotToast，单测只关心请求竞态。
        homeLoadingIndicatorProvider.overrideWithValue(
          HomeLoadingIndicator(show: () {}, hide: () {}),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(homeDataProvider.notifier);
    await pumpEventQueue();
    repository.requests[0].complete(_homeResponse(['initial']));
    await container.read(homeDataProvider.future);
    expect(container.read(homeDataProvider).value?.notices, ['initial']);

    // 两次刷新前后脚发出：后发起的先返回，先发起的慢一拍才返回。
    final stale = notifier.refresh();
    final latest = notifier.refresh();
    await pumpEventQueue();
    expect(repository.requests, hasLength(3));
    repository.requests[2].complete(_homeResponse(['latest']));
    await latest;
    repository.requests[1].complete(_homeResponse(['stale']));
    await stale;

    // 慢的旧请求回来后不能覆盖新数据。
    expect(container.read(homeDataProvider).value?.notices, ['latest']);
  });

  testWidgets('未登录时点击受保护的 Tab 会跳转登录页', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter mobile number'), findsOneWidget);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
  });

  testWidgets('未登录时进度 Tab 同样需要登录', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-progress')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter mobile number'), findsOneWidget);
  });

  testWidgets('切到进度 Tab 会刷新首页数据源', (tester) async {
    // 进度卡来自首页接口的 PROCESS_LIST，与首页共用 homeDataProvider；
    // 进入进度 Tab 必须重新拉一次，否则展示的是上次的旧数据。
    final repository = _StubAppRepository();
    await _pumpApp(
      tester,
      repository: repository,
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
    );
    // 首屏首页接口已拉一次。
    expect(repository.homeCalls, 1);

    await tester.tap(find.byKey(const Key('tab-progress')));
    await tester.pumpAndSettle();

    expect(repository.homeCalls, 2);
    expect(find.text('No progress yet'), findsOneWidget);
  });

  testWidgets('进度卡 Try again 调原卡重试确认订单并打开返回的订单详情地址', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..retryOrderUrl = 'https://h5.example.com/order/9';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          product: null,
          orders: [
            HomeOrderCard(
              orderNo: 'ORD-9',
              productId: 7,
              productName: 'Cash Moca',
              productLogo: '',
              title: 'Credit activation progress',
              displayAmount: '₱20.000',
              amountText: 'Loan Amount',
              date: '12-07-2024',
              dateText: 'Loan Date',
              orderStatusText: '',
              status: HomeOrderCardStatus.failed1,
              progressText: '',
              steps: [],
              // 重试接口拿到地址前，卡片上那份旧地址不该被打开。
              jumpUrl: 'https://h5.example.com/stale',
            ),
          ],
          notices: [],
        ),
      ),
      certificationRepository: certificationRepository,
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
    );

    await tester.tap(find.byKey(const Key('tab-progress')));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    // WebView 首帧自带 loading 指示器，pumpAndSettle 不会收敛，按帧推进即可。
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 只带订单号调重试接口，拿它返回的地址开 H5，不回落卡片上的 jumpUrl。
    expect(certificationRepository.retryOrderCalls, ['ORD-9']);
    expect(find.byType(WebViewPage), findsOneWidget);
  });

  testWidgets('登录页在未填手机号时禁用获取验证码与提交', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    final sendCode = tester.widget<TextButton>(
      find.byKey(const Key('login-send-code-button')),
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit-button')),
    );

    expect(sendCode.onPressed, isNull);
    expect(submit.onPressed, isNull);
  });

  testWidgets('登录页手机号或验证码没填完时不发登录请求', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    // 差一位：按钮保持禁用，也不会触发自动登录。
    await tester.enterText(find.byKey(const Key('login-code-field')), '12345');
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit-button')))
          .onPressed,
      isNull,
    );
    expect(auth.loginCalls, 0);
  });

  testWidgets('登录页验证码填满 6 位自动提交，登录成功后关掉登录页', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 1);
    expect(find.byKey(const Key('login-phone-field')), findsNothing);
  });

  testWidgets('提交登录时收起键盘并显示全屏 loading', (tester) async {
    final auth = _StubAuthRepository(delay: const Duration(milliseconds: 300));
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    // 填满 6 位触发自动提交。
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 请求进行中：键盘收起 + 整屏 loading。
    expect(_loginFieldFocused(tester, const Key('login-code-field')), isFalse);
    // 两个转圈：提交按钮内嵌的那个 + 全屏 loading 的那个。
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('login-phone-field')), findsNothing);
  });

  testWidgets('自动登录失败会清空验证码并回焦，错误走通用文案', (tester) async {
    final auth = _StubAuthRepository(
      failure: const ApiException(
        type: ApiFailureType.noConnection,
        message: '网络连接失败，请检查网络设置',
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();

    expect(find.text('网络连接失败，请检查网络设置'), findsOneWidget);
    expect(_loginFieldValue(tester, const Key('login-code-field')), isEmpty);
    expect(_loginFieldFocused(tester, const Key('login-code-field')), isTrue);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('登录态失效不弹错误提示，交给全局登出流程', (tester) async {
    final auth = _StubAuthRepository(
      failure: const ApiException(
        type: ApiFailureType.authentication,
        message: '登录已过期',
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();

    expect(find.text('登录已过期'), findsNothing);
    expect(find.text('Unable to complete the request.'), findsNothing);
  });

  testWidgets('发码成功后进入倒计时并聚焦验证码框', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.sendCodeCalls, 1);
    expect(find.text('Verification code sent.'), findsOneWidget);
    expect(find.text('60 S'), findsOneWidget);
    expect(_loginFieldFocused(tester, const Key('login-code-field')), isTrue);

    // 收掉倒计时，避免测试结束时还有未完成的计时器。
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('退出登录后登录页回填上次的手机号', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      setUp: (container) async {
        final session = container.read(userSessionProvider.notifier);
        await session.setSession(
          token: 'test-session',
          userId: '1',
          phone: '9171234567',
        );
        // 退出登录只清 token，手机号留着给下次登录回填。
        await session.clearSession();
      },
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    expect(
      _loginFieldValue(tester, const Key('login-phone-field')),
      '9171234567',
    );
    // 手机号回填后「Get it」直接可用。
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('login-send-code-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('未勾选协议时不发请求，点提交浮出提示条', (tester) async {
    final auth = _StubAuthRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      authRepository: auth,
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    // 设计稿默认态协议就是勾上的。
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxChecked);

    // 先取消勾选再填验证码：自动提交静默失败，不发请求。
    await tester.tap(find.byKey(const Key('login-agreement-checkbox')));
    await tester.pump();
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxUnchecked);

    await tester.enterText(
      find.byKey(const Key('login-phone-field')),
      '9171234567',
    );
    await tester.enterText(find.byKey(const Key('login-code-field')), '123456');
    await tester.pumpAndSettle();
    expect(auth.loginCalls, 0);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);

    // 手动提交才浮出设计稿里的提示条。
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();
    expect(
      find.text('Please read and agree to the Privacy Agreement'),
      findsOneWidget,
    );

    // 提示条 2 秒后自动收起。
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('Please read and agree to the Privacy Agreement'),
      findsNothing,
    );
    expect(auth.loginCalls, 0);
  });

  testWidgets('登录页协议里的链接响应点击，不会连带切换勾选态', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    // 点 `Privacy Policy` 只走链接回调，勾选态保持默认的已勾选。
    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    await tester.pump();
    expect(_loginCheckboxAsset(tester), AppAssets.loginCheckboxChecked);

    // 放掉链接回调里的 Toast 动画，避免测试结束时有未完成的计时器。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('登录页点击空白处收起键盘', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    const phoneField = Key('login-phone-field');
    await tester.tap(find.byKey(phoneField));
    await tester.pumpAndSettle();
    expect(_loginFieldFocused(tester, phoneField), isTrue);

    // 点标题下方的空白背景（品牌行左侧）。
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(_loginFieldFocused(tester, phoneField), isFalse);
  });

  testWidgets('键盘弹出时底部 Banner 不被顶起，只有表单区让位', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    final formArea = find.descendant(
      of: find.byType(LoginPage),
      matching: find.byType(SingleChildScrollView),
    );
    final bannerBefore = tester.getRect(_loginBanner());
    final formBefore = tester.getRect(formArea);
    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // Banner 下方的留白（Banner + 间距 + 安全区）不算被键盘盖住。
    final bottomBlock = screenBottom - formBefore.bottom;

    // 测试面是 3 倍图，990 物理像素 = 330pt 键盘。
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 3);
    await tester.pumpAndSettle();

    expect(tester.getRect(_loginBanner()), bannerBefore);
    // 表单区底部正好停在键盘上沿，中间不留空白。
    expect(tester.getRect(formArea).bottom, screenBottom - _keyboard);
    expect(
      tester.getRect(formArea).height,
      formBefore.height - (_keyboard - bottomBlock),
    );
  });

  testWidgets('登录后个人中心按蓝湖稿 07-01 展示头图与两组入口', (tester) async {
    await _pumpApp(
      tester,
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
      repository: _StubAppRepository(),
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    // 头图：标题 + 手机号脱敏（设计稿 `962 **** 1300`）。
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('917 **** 4567'), findsOneWidget);

    // 订单入口四个筛选项，顺序与设计稿 `list_3` 一致。
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);

    // 两组入口都是客户端固定内容，不依赖后端下发。
    expect(find.text('Customer Service'), findsOneWidget);
    expect(find.text('Smart customer service'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('APP Version'), findsOneWidget);
    expect(find.text('Privacy Agreement'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // 订单卡底部那块薄荷色「肩线」是设计稿 `image_2` 的切图，别退回手画。
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                AppAssets.mineOrderCardShoulder,
      ),
      findsOneWidget,
    );
  });

  testWidgets('个人中心 Account 行弹出设计稿里的退出面板', (tester) async {
    // 设计稿的面板画到 812pt 底边，没有留手势条的位置，真机上必须自己让开。
    const safeBottom = 34.0;
    tester.view.padding = const FakeViewPadding(bottom: safeBottom * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: safeBottom * 3);

    await _pumpApp(
      tester,
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
      repository: _StubAppRepository(),
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();

    // 设计稿 `07-01 - 个人中心-退出` 的三个行动项。
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Quit'), findsOneWidget);

    // 面板背景铺到底，但最后一行要整个待在安全区之上。
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(
      sheet.bottom - tester.getRect(find.text('Quit')).bottom,
      greaterThanOrEqualTo(safeBottom),
    );
  });

  testWidgets('退出登录挽留弹窗：Track Now 只关弹窗，不发退出请求', (tester) async {
    final authRepository = _StubAuthRepository();
    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: _StubAppRepository(),
      setUp: (container) => container
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    // 设计稿 `07-01 - 个人中心-退出挽留弹窗`：整卡用用户提供的 `编组@3x` 切图
    // （标题 / 正文烘焙在图里），只有胶囊按钮文案和次要行动由代码叠加。
    expect(_assetImage(AppAssets.mineLogoutRetention), findsOneWidget);
    expect(find.text('Track Now'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);

    // 主按钮只关弹窗，不退出登录。
    await tester.tap(find.byKey(const Key('account-retention-stay')));
    await tester.pumpAndSettle();
    expect(_assetImage(AppAssets.mineLogoutRetention), findsNothing);
    expect(authRepository.logoutCalls, 0);
  });

  testWidgets('退出登录挽留弹窗：Log Out 真正退出并清掉登录态', (tester) async {
    late ProviderContainer container;
    final authRepository = _StubAuthRepository();
    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: _StubAppRepository(),
      setUp: (c) {
        container = c;
        return c
            .read(userSessionProvider.notifier)
            .setSession(
              token: 'test-session',
              userId: '1',
              phone: '9171234567',
            );
      },
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-retention-exit')));
    await tester.pumpAndSettle();

    expect(authRepository.logoutCalls, 1);
    expect(_assetImage(AppAssets.mineLogoutRetention), findsNothing);
    expect(container.read(userSessionProvider).isLoggedIn, isFalse);
  });

  testWidgets('退出登录回落到首页时会重新拉首页数据', (tester) async {
    final repository = _StubAppRepository();
    await _pumpApp(
      tester,
      authRepository: _StubAuthRepository(),
      repository: repository,
      setUp: (c) => c
          .read(userSessionProvider.notifier)
          .setSession(token: 'test-session', userId: '1', phone: '9171234567'),
    );

    // 首屏加载过一次。
    expect(repository.homeCalls, 1);

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    final beforeLogout = repository.homeCalls;
    await tester.tap(find.byKey(const Key('account-retention-exit')));
    await tester.pumpAndSettle();

    // 回到首页时必须重新拉一次：游客态额度 / 订单与登录态不同。
    expect(repository.homeCalls, greaterThan(beforeLogout));
  });

  testWidgets('注销挽留弹窗：Delete 调注销接口并清掉登录态', (tester) async {
    late ProviderContainer container;
    final authRepository = _StubAuthRepository();
    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: _StubAppRepository(),
      setUp: (c) {
        container = c;
        return c
            .read(userSessionProvider.notifier)
            .setSession(
              token: 'test-session',
              userId: '1',
              phone: '9171234567',
            );
      },
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    // 设计稿 `07-01 - 个人中心-注销挽留弹窗`：同样用整卡切图，文案在图里。
    expect(_assetImage(AppAssets.mineDeleteAccountRetention), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // 主按钮只关弹窗，不注销。
    await tester.tap(find.byKey(const Key('account-retention-stay')));
    await tester.pumpAndSettle();
    expect(_assetImage(AppAssets.mineDeleteAccountRetention), findsNothing);
    expect(authRepository.deleteAccountCalls, 0);
    expect(container.read(userSessionProvider).isLoggedIn, isTrue);

    // 再次打开并确认注销。
    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-retention-exit')));
    await tester.pumpAndSettle();

    expect(authRepository.deleteAccountCalls, 1);
    expect(_assetImage(AppAssets.mineDeleteAccountRetention), findsNothing);
    expect(container.read(userSessionProvider).isLoggedIn, isFalse);
  });

  testWidgets('注销接口失败时保留登录态，弹窗不关闭', (tester) async {
    late ProviderContainer container;
    final authRepository = _StubAuthRepository(deleteAccountFailure: true);
    await _pumpApp(
      tester,
      authRepository: authRepository,
      repository: _StubAppRepository(),
      setUp: (c) {
        container = c;
        return c
            .read(userSessionProvider.notifier)
            .setSession(
              token: 'test-session',
              userId: '1',
              phone: '9171234567',
            );
      },
    );

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-account-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-retention-exit')));
    await tester.pumpAndSettle();

    expect(authRepository.deleteAccountCalls, 1);
    // 后端没删成功：弹窗留着、登录态不能清，避免用户以为账号已注销。
    expect(_assetImage(AppAssets.mineDeleteAccountRetention), findsOneWidget);
    expect(container.read(userSessionProvider).isLoggedIn, isTrue);
  });

  test('注销账号接口走 /outsulk/norseled 并带 sickee 混淆字段', () async {
    expect(ApiEndpoints.deleteAccount, '/outsulk/norseled');
    expect(ApiFields.obfuscateDeleteAccount, 'sickee');

    final client = _RecordingClient();
    await AuthRepository(client).deleteAccount();

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.deleteAccount);
    expect(params[ApiFields.obfuscateDeleteAccount], isNotEmpty);
  });

  // ---------- 接口文档字段契约 ----------
  // 后端字段名是混淆串，写错了不会报错、只会静默读到 null，这里锁住映射。

  test('首页 PROCESS_LIST 用订单卡自己的字段名解析', () {
    final home = HomeData.fromJson(const {
      'kneeing': [
        {
          'liquidators': 'PROCESS_LIST',
          'stabiliment': [
            {
              'resex': '39236372837263237',
              'tartarizing': 1,
              'current': 'Pera Agad(AA)',
              'unpaying': 'https://cdn.example.com/logo.png',
              'upbear': 'Already in default, please repay',
              'libertytown': '\u20b150,000',
              'cuboid': 'To repay',
              'satin': 2,
              'superidealness': 'ph://laya-credit/ios/IdeogrammicCothurni',
            },
          ],
        },
      ],
    });

    final order = home.orders.single;
    expect(order.productName, 'Pera Agad(AA)');
    expect(order.productLogo, 'https://cdn.example.com/logo.png');
    expect(order.displayAmount, '\u20b150,000');
    expect(order.status, HomeOrderCardStatus.toRepay);
  });

  test('首页 PRODUCT_LIST 用 Sixcylinder 混淆值解析推荐列表', () {
    final home = HomeData.fromJson(const {
      'kneeing': [
        {
          'liquidators': 'Sixcylinder',
          'stabiliment': [
            {
              'cussedly': 1,
              'heartfelt': 'Pera Pitaka(AA)',
              'bathtubs': 'https://cdn.example.com/logo.png',
              'wastefulnesses': '\u20b150,000',
              'octodentate': 'Maximum Loan Amount Upto',
              'mesometral': 'Interest Rate',
              'antibilious': '\u2264 0.5% Day',
              'lxe': 'Loan terms',
              'gundy': '121day',
              'islet': ['Low Interest Rates', '17 years old can be borrowed'],
              'holts': 1,
            },
          ],
        },
      ],
    });

    final card = home.productList.single;
    expect(card.id, '1');
    expect(card.productName, 'Pera Pitaka(AA)');
    expect(card.productLogo, 'https://cdn.example.com/logo.png');
    expect(card.amountRange, '\u20b150,000');
    expect(card.amountRangeDes, 'Maximum Loan Amount Upto');
    expect(card.loanRateDes, 'Interest Rate');
    expect(card.loanRate, '\u2264 0.5% Day');
    expect(card.termInfoText, 'Loan terms');
    expect(card.termInfo, '121day');
    expect(card.tips, ['Low Interest Rates', '17 years old can be borrowed']);
    expect(card.buttonStyle, HomeProductCardButtonStyle.highlighted);
    // 推荐列表不是产品大卡，不能顶掉头图的 LARGE_CARD。
    expect(home.product, isNull);
  });

  test('推荐卡按钮配色 holts 覆盖三态，缺省回落正常态', () {
    HomeProductCardButtonStyle styleOf(Object? holts) => HomeData.fromJson({
      'kneeing': [
        {
          'liquidators': 'PRODUCT_LIST',
          'stabiliment': [
            {'heartfelt': 'Pera Pitaka(AA)', 'holts': holts},
          ],
        },
      ],
    }).productList.single.buttonStyle;

    expect(styleOf(1), HomeProductCardButtonStyle.highlighted);
    expect(styleOf(0), HomeProductCardButtonStyle.normal);
    expect(styleOf(-1), HomeProductCardButtonStyle.grayed);
    expect(styleOf(null), HomeProductCardButtonStyle.normal);
  });

  test('首页 kneeing 用测试环境下发的混淆模块名解析', () {
    // 文档 `7.map.html` 写的是 BANNER / LARGE_CARD / AD_LIST，
    // 测试环境下发的却是混淆串，两种都要能解析。
    final home = HomeData.fromJson(const {
      'kneeing': [
        {
          'liquidators': 'MalvernePlucked',
          'stabiliment': [
            {
              'cussedly': '1',
              'avern': 'https://cdn.example.com/banner.png',
              'superidealness': 'ph://banner',
            },
          ],
        },
        {
          'liquidators': 'LupusesWheelrace',
          'stabiliment': [
            {
              'heartfelt': 'Pera Cash',
              'bathtubs': 'https://cdn.example.com/logo.png',
              'curitiba': 'Apply Now',
              'wastefulnesses': '\u20b160,000',
              'octodentate': 'Available up to',
              'gundy': '180 Days',
              'solomon': 'Loan terms',
              'antibilious': '\u2264 0.5% Day',
              'mesometral': 'Interest rate',
              'vesperal': 'Credit activation progress',
              'kailua': 0,
              'unobtrusiveness': [
                {
                  'upbear': 'Identity',
                  'beingless': '\u20b1 30,000',
                  'estamp': 1,
                },
                {'upbear': 'Living', 'beingless': '\u20b1 40,000', 'estamp': 0},
              ],
            },
          ],
        },
        {
          'liquidators': 'BelliferousOverfertilizing',
          'stabiliment': [
            {'upbear': '<span>2,000 pesos</span>'},
          ],
        },
      ],
    });

    expect(home.banners.first.imageUrl, 'https://cdn.example.com/banner.png');
    expect(home.product?.productName, 'Pera Cash');
    expect(home.product?.termInfo, '180 Days');
    expect(home.product?.steps.map((step) => step.title), [
      'Identity',
      'Living',
    ]);
    expect(home.product?.steps.first.selected, isTrue);
    expect(home.notices, hasLength(1));
  });

  test('加签覆盖的参数与实际下发的公共参数完全一致', () {
    final common = CommonParams.create(
      deviceId: 'device',
      market: 'market',
      appVersion: '1.0.0',
      deviceName: 'iPhone 16 Pro',
      osVersion: '18.2',
      advertisingId: 'device',
    );
    final signInput = CommonParams.signable(common, '/outsulk/connectedly');

    // 后端是拿收到的参数重算签名的：多签一个没下发的字段（曾经 gruelled
    // 只在签名里出现）会被判成 code 400。
    final signedKeys = signInput.keys.toSet()
      ..remove(ApiProtocol.signaturePath);
    expect(signedKeys, common.keys.toSet());
    expect(common.containsKey(ApiProtocol.clientType), isTrue);
    // stith 与签名本身不参与签名。
    expect(signInput.containsKey(ApiProtocol.obfuscation), isFalse);
    expect(signInput.containsKey(ApiProtocol.signature), isFalse);
  });

  test('banner 点击上报带的是文档字段 geheimrat', () async {
    final client = _RecordingClient();
    await AppRepository(client).recordBannerClick('1394');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.bannerClick);
    expect(params[ApiFields.bannerConfigId], '1394');
    expect(params.containsKey(ApiFields.obfuscateBannerClick), isTrue);
  });

  test('点击申请接口带产品 id、来源标识与固定的模块参数', () async {
    final client = _RecordingClient();
    await ProductRepository(client).applyProduct(productId: '7', apiRemind: 0);

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.productApply);
    expect(params[ApiFields.productId], '7');
    expect(params[ApiFields.apiRemind], '0');
    // 文档标注已弃用，但仍要固定下发。
    expect(params.containsKey(ApiFields.obfuscateApply1), isTrue);
    expect(params.containsKey(ApiFields.obfuscateApply2), isTrue);
  });

  test('产品详情解析 priapi 与 cretonne 下一步认证项', () {
    final detail = ProductDetail.fromJson({
      ApiFields.applyResultCode: 200,
      ApiFields.productDetail: {
        ApiFields.itemId: '7',
        ApiFields.productName: 'Pera Agad',
        ApiFields.detailOrderNo: 'ORDER-9',
        ApiFields.detailOrderId: 266561,
        ApiFields.amount: '1000',
        ApiFields.detailTerm: '91',
        ApiFields.detailTermType: '1',
      },
      ApiFields.detailNextStep: {
        ApiFields.detailTaskType: 'Bespattered',
        ApiFields.itemTitle: 'Informasi bank',
        ApiFields.jumpUrl: '',
        ApiFields.applyJumpType: 0,
      },
      // 各认证页文案容器：身份认证文案取 `splendacious` 这一条。
      ApiFields.detailTips: {
        ApiFields.detailTipIdentity: 'Upload a clear photo of your valid ID.',
        'bocking': 'ignored',
      },
    });

    expect(detail.identityPrompt, 'Upload a clear photo of your valid ID.');
    expect(detail.resultCode, 200);
    expect(detail.basicInfo.productId, '7');
    expect(detail.basicInfo.orderNo, 'ORDER-9');
    expect(detail.basicInfo.orderId, 266561);
    expect(detail.basicInfo.loanTerm, '91');
    expect(detail.basicInfo.termType, '1');
    expect(detail.nextStep.taskType, 'Bespattered');
    expect(detail.nextStep.title, 'Informasi bank');
  });

  test('产品详情不下发 overwhelming 时身份认证文案为空', () {
    final detail = ProductDetail.fromJson({
      ApiFields.applyResultCode: 200,
      ApiFields.productDetail: {ApiFields.itemId: '7'},
    });

    expect(detail.identityPrompt, isEmpty);
  });

  test('准入结果解析 countercharged / superidealness 与跳转类型', () {
    final result = ProductApplyResult.fromJson({
      ApiFields.applyResultCode: 302,
      ApiFields.jumpUrl: 'ph://laya-credit/ios/IntervesicularSauder',
      ApiFields.applyJumpType: 0,
      ApiFields.applyMessage: 'success',
    });

    expect(result.statusCode, 302);
    expect(result.hasJump, isTrue);
    expect(result.isAdmitted, isFalse);
    expect(result.jumpType, 0);
  });

  testWidgets('已登录用户点额度大卡会发起点击申请', (tester) async {
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      // 默认详情里的下一步是身份认证，准入成功后会压栈证件选择页，
      // 这一条不需要验证那一页，给个桩仓库避免真发请求。
      certificationRepository: _StubCertificationRepository(),
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    // 点大卡的非按钮区域，走的是同一处 _openApply 逻辑。
    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(productRepository.applyCalls, [('1', 0)]);
  });

  testWidgets('准入失败时不继续拉产品详情', (tester) async {
    final productRepository = _StubProductRepository(
      applyResult: const ProductApplyResult(
        statusCode: 505,
        jumpUrl: '',
        jumpType: 0,
        message: 'Risk rejected',
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(productRepository.applyCalls, hasLength(1));
    expect(productRepository.detailCalls, 0);
    expect(find.text('Risk rejected'), findsOneWidget);
  });

  testWidgets('定位检查未通过时不发起准入', (tester) async {
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    ProductApplicationFlow.locationChecker = () async =>
        CertificationLocationDecision.denied;
    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(productRepository.applyCalls, isEmpty);
  });

  testWidgets('准入成功后拉产品详情并按下一步认证项提示', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-1'),
        nextStep: ProductNextStep(
          taskType: 'UnhandledStep',
          title: 'Informasi bank',
        ),
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(productRepository.applyCalls, hasLength(1));
    expect(productRepository.detailCalls, 1);
    expect(find.text('Please complete Informasi bank'), findsOneWidget);
  });

  testWidgets('证件选择页展示接口下发的证件类型', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );

    // 申请流程里「身份认证」这一项跳的就是这个路由，这里直接按同样的方式打开。
    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(productId: '7'),
    );
    await tester.pumpAndSettle();

    // 证件类型必须来自接口，不能在客户端写死。
    expect(certificationRepository.identityInfoCalls, ['7']);

    // 头图与返回按钮都是设计稿切图，不要在代码里重画。
    expect(_assetImage(AppAssets.idVerifyHeader), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
    expect(find.text('ID Verification'), findsOneWidget);

    // 两张卡的标题。
    expect(find.text('Recommended ID Type'), findsOneWidget);
    expect(find.text('Other Options'), findsOneWidget);

    // 推荐证件：`magisterial[0]`，顺序与后端下发一致，文案原样展示。
    expect(find.text('DRIVINGLICENSE'), findsOneWidget);
    expect(find.text('PRC'), findsOneWidget);
    expect(find.text('SSS'), findsOneWidget);
    expect(find.text('PASSPORT'), findsOneWidget);
    expect(find.text('POSTALID'), findsOneWidget);
    expect(find.text('UMID'), findsOneWidget);

    // 其他证件：`magisterial[1]`。
    expect(find.text('TIN'), findsOneWidget);
    expect(find.text('VOTERID'), findsOneWidget);
    expect(find.text('NATIONALID'), findsOneWidget);
    expect(find.text('PAGIBIG'), findsOneWidget);
    expect(find.text('HEALTHCARD'), findsOneWidget);

    // 卡片比头图底边高 19pt，白色标题块压在头图下沿上（设计稿 `top: -19`）。
    final headerRect = tester.getRect(_assetImage(AppAssets.idVerifyHeader));
    final cardRect = tester.getRect(
      find
          .ancestor(
            of: find.text('Recommended ID Type'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    // 设计稿 `section_3` 顶边 237 与 `text-wrapper_4` 的 `top: -19`：白卡压住头图 19pt。
    expect(headerRect.bottom - cardRect.top, greaterThan(0));

    // 选中证件后进上传页：卡类型原样带下去（也是上传 / 保存接口的取值）。
    await tester.tap(find.text('PRC'));
    await tester.pumpAndSettle();

    expect(find.byType(IdUploadPage), findsOneWidget);
    final uploadPage = tester.widget<IdUploadPage>(find.byType(IdUploadPage));
    expect(uploadPage.productId, '7');
    expect(uploadPage.cardType, 'PRC');
  });

  testWidgets('证件上传页按蓝湖稿 03-01 渲染头图、引导块与 Upload 按钮', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());
    _openIdUploadPage(tester);
    await tester.pumpAndSettle();

    // 头图 / 返回按钮 / 引导块 / 按钮底图都是设计稿切图，不要在代码里重画。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadDemo), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);
    expect(find.text('ID Verification'), findsOneWidget);

    // 引导段落按设计稿的四行断行，不跟着系统字体漂。
    expect(
      find.text(
        'Valid official credentials\n'
        'avoid rejection and\n'
        'quickly unlock your loan\n'
        'service access.',
      ),
      findsOneWidget,
    );
    // 设计稿 `text_4 { width: 204px }`。
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text(
                    'Valid official credentials\n'
                    'avoid rejection and\n'
                    'quickly unlock your loan\n'
                    'service access.',
                  ),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      closeTo(204 * _designScale, 0.5),
    );

    // 引导块顶边比头图底边高 19pt（设计稿 `text-wrapper_5 { top: 194 }`）。
    final headerRect = tester.getRect(
      _assetImage(AppAssets.idVerifyHeaderBlank),
    );
    final demoRect = tester.getRect(_assetImage(AppAssets.idVerifyUploadDemo));

    expect(headerRect.bottom - demoRect.top, closeTo(19 * _designScale, 0.5));
    // 引导块与按钮之间的间距（设计稿 614 -> 714）。
    expect(
      tester.getRect(_assetImage(AppAssets.idVerifyUploadButton)).top -
          demoRect.bottom,
      closeTo(100 * _designScale, 0.5),
    );
  });

  testWidgets('上传页点 Upload 弹出选择上传方式面板，底部按设计稿留距', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());
    _openIdUploadPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.byType(UploadMethodSheet), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Album'), findsOneWidget);
    expect(find.text('Quit'), findsOneWidget);
    // 面板是盖在上传页上的，页面本身不跳走。
    expect(find.byType(IdUploadPage), findsOneWidget);

    // 设计稿：Camera / Album 行高各 57、中间 1pt 分隔线；Quit 前面 8pt 间隔带、
    // 行高 59，所以两段行距是 58 与 66。
    double centerY(Finder finder) => tester.getCenter(finder).dy;
    expect(
      centerY(find.text('Album')) - centerY(find.text('Camera')),
      closeTo(58 * _designScale, 0.5),
    );
    expect(
      centerY(find.text('Quit')) - centerY(find.text('Album')),
      closeTo(66 * _designScale, 0.5),
    );
    // Quit 行比 Camera 行高（59 vs 57）：上下各 20pt 内边距 + 19pt 行高。
    expect(
      tester.getSize(find.text('Quit')).height,
      greaterThan(tester.getSize(find.text('Camera')).height),
    );
  });

  testWidgets('上传方式面板点 Quit 关掉面板，Album 走取图 -> 压缩 -> 上传', (tester) async {
    final photo = _StubIdentityPhotoService();
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      identityPhotoService: photo,
    );
    _openIdUploadPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quit'));
    await tester.pumpAndSettle();
    expect(find.byType(UploadMethodSheet), findsNothing);

    // 相册取图（相册不需要相机权限）后压缩并以「卡类型 + 来源 1」上传。
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();

    expect(find.byType(UploadMethodSheet), findsNothing);
    expect(photo.pickCalls, [IdentityPhotoSource.album]);
    expect(certificationRepository.uploadCalls, hasLength(1));
    expect(certificationRepository.uploadCalls.single.$2, 'PRC');
    expect(
      certificationRepository.uploadCalls.single.$3,
      IdentityPhotoSource.album,
    );

    // 上传成功后进证件信息确认页核对识别结果，识别结果由上传响应带过来。
    expect(find.byType(IdConfirmPage), findsOneWidget);
    expect(find.text('NAVEEN TOM VARGHESE'), findsOneWidget);
    expect(find.text('623099344111'), findsOneWidget);
    // 后端给的 `23/11/1993` 要归一成设计稿那种带横杠的 `23-11-1993`。
    expect(find.text('23-11-1993'), findsOneWidget);
  });

  testWidgets('证件上传页引导文案优先用产品详情下发的 overwhelming.splendacious', (tester) async {
    const apiPrompt =
        'Upload a clear, well-lit photo of your valid ID to speed up review.';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      setUp: (container) async {
        container
            .read(sessionStoreProvider)
            .saveProductDetailIdentityPrompt(apiPrompt);
      },
    );
    _openIdUploadPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(apiPrompt), findsOneWidget);
    expect(find.textContaining('Valid official credentials'), findsNothing);
  });

  testWidgets('证件上传页返回按钮回到证件选择页', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(productId: '7'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PRC'));
    await tester.pumpAndSettle();
    expect(find.byType(IdUploadPage), findsOneWidget);

    // 返回热区 40x40 在导航行左端，点图标本身即可命中。
    await tester.tap(
      find.descendant(
        of: find.byType(BackNavBar),
        matching: _assetImage(AppAssets.back),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IdUploadPage), findsNothing);
    expect(find.byType(IdVerificationPage), findsOneWidget);
  });

  testWidgets('证件选择页返回命中身份认证挽留弹窗，Continue 留在当前页', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..retentionImageUrl = 'https://cdn.example/retention.png'
      ..retentionContinueText = 'Track Now'
      ..retentionExitText = 'Exit';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      certificationRetentionGuard: _noopLoadingGuard(certificationRepository),
    );
    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(productId: '7'),
    );
    await tester.pumpAndSettle();

    await _tapNavBarBack(tester);
    await tester.pumpAndSettle();

    // 证件选择页按接口 `type=0` 拉挽留素材，按钮文案用后端下发的，不在客户端写死。
    expect(certificationRepository.retentionCalls, [('7', '0')]);
    expect(
      find.byKey(const Key('certification-retention-card')),
      findsOneWidget,
    );
    expect(find.text('Track Now'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);

    await tester.tap(find.byKey(const Key('certification-retention-stay')));
    await tester.pumpAndSettle();

    // 「留下」只是关掉弹窗，页面不动。
    expect(find.byType(IdVerificationPage), findsOneWidget);
    expect(
      find.byKey(const Key('certification-retention-card')),
      findsNothing,
    );
  });

  testWidgets('证件选择页挽留弹窗点 Exit 才真正返回', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..retentionImageUrl = 'https://cdn.example/retention.png';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      certificationRetentionGuard: _noopLoadingGuard(certificationRepository),
    );
    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(productId: '7'),
    );
    await tester.pumpAndSettle();

    await _tapNavBarBack(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('certification-retention-exit')));
    await tester.pumpAndSettle();

    expect(find.byType(IdVerificationPage), findsNothing);
  });

  testWidgets('个人信息页返回用挽留类型 2', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      certificationRetentionGuard: _noopLoadingGuard(certificationRepository),
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    await _tapNavBarBack(tester);
    await tester.pumpAndSettle();

    expect(certificationRepository.retentionCalls, [('7', '2')]);
    // 没有素材时直接返回，不弹空壳弹窗。
    expect(certificationRepository.personalInfoCalls, isNotEmpty);
    expect(
      find.byKey(const Key('certification-retention-card')),
      findsNothing,
    );
  });

  testWidgets('工作信息页返回用挽留类型 3', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      certificationRetentionGuard: _noopLoadingGuard(certificationRepository),
    );
    _openWorkInfoPage(tester);
    await tester.pumpAndSettle();

    await _tapNavBarBack(tester);
    await tester.pumpAndSettle();

    expect(certificationRepository.retentionCalls, [('7', '3')]);
  });

  testWidgets('借款确认页返回用挽留类型 5', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      certificationRetentionGuard: _noopLoadingGuard(certificationRepository),
    );
    AppNavigator.push(
      AppRoutes.loanConfirm,
      arguments: const LoanConfirmPageArguments(productId: '7', orderNo: 'ORD-1'),
    );
    await tester.pumpAndSettle();

    await _tapNavBarBack(tester);
    await tester.pumpAndSettle();

    expect(certificationRepository.retentionCalls, [('7', '5')]);
  });

  testWidgets('证件信息确认页按蓝湖稿 03-01 渲染证件照、三行识别结果与 Upload 按钮', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());
    _openIdConfirmPage(tester);
    await tester.pumpAndSettle();

    // 头图 / 证件照 / 按钮底图都是设计稿切图，不要在代码里重画。
    // 确认页按需求不允许返回上一页，所以没有返回按钮。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsNothing);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);
    expect(find.text('ID Verification'), findsOneWidget);

    // 证件照地址为空时用设计稿切图兜底。
    expect(find.byType(RemoteImage), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyIdCard), findsOneWidget);

    // 三行识别结果：左字段名、右字段值。
    for (final label in ['Full Name', 'ID No.', 'Date of Birth']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('NAVEEN TOM VARGHESE'), findsOneWidget);
    expect(find.text('623099344111'), findsOneWidget);
    expect(find.text('23-11-1993'), findsOneWidget);

    // 引导段落按设计稿的三行断行，不跟着系统字体漂。
    expect(
      find.text(
        'Confirm your ID details\n'
        'below to ensure funds\n'
        'land in your account.',
      ),
      findsOneWidget,
    );

    // 证件照 319x200（设计稿 `box_5`，2pt 白描边含在尺寸里）。
    final idCardRect = tester.getRect(
      find
          .ancestor(
            of: _assetImage(AppAssets.idVerifyIdCard),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(idCardRect.width, closeTo(319 * _designScale, 0.5));
    expect(idCardRect.height, closeTo(200 * _designScale, 0.5));

    // 证件照顶边压在头图下沿上 7pt（白卡 top 194 + 1pt 分隔线 + 11pt）。
    final headerRect = tester.getRect(
      _assetImage(AppAssets.idVerifyHeaderBlank),
    );
    expect(headerRect.bottom - idCardRect.top, closeTo(7 * _designScale, 0.5));

    // 信息行高 48 + 行距 8（设计稿 `text-wrapper_4`：14 + 20 + 14，margin-bottom 8）。
    double centerY(Finder finder) => tester.getCenter(finder).dy;
    expect(
      centerY(find.text('ID No.')) - centerY(find.text('Full Name')),
      closeTo(56 * _designScale, 0.5),
    );
    expect(
      centerY(find.text('Date of Birth')) - centerY(find.text('ID No.')),
      closeTo(56 * _designScale, 0.5),
    );

    // 白卡与按钮之间的间距（设计稿 590 -> 714）。
    expect(
      tester.getRect(_assetImage(AppAssets.idVerifyUploadButton)).top -
          idCardRect.bottom,
      closeTo(308 * _designScale, 0.5),
    );
  });

  testWidgets('证件信息确认页不允许返回上一页（无返回按钮、系统返回也拦下）', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());
    _openIdConfirmPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(IdConfirmPage), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsNothing);

    // 系统返回手势（Android 物理返回 / iOS 侧滑）同样不能把页面弹掉。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(IdConfirmPage), findsOneWidget);
  });

  testWidgets('证件信息确认页引导文案优先用产品详情下发的 overwhelming.bocking', (tester) async {
    const apiPrompt =
        'Confirm they are correct and watch your approval odds climb!';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      setUp: (container) async {
        container
            .read(sessionStoreProvider)
            .saveProductDetailIdentitySuccessPrompt(apiPrompt);
      },
    );
    _openIdConfirmPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(apiPrompt), findsOneWidget);
    expect(find.textContaining('Confirm your ID details'), findsNothing);
  });

  testWidgets('证件信息确认页点 Upload 保存识别结果并继续下一步认证', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      productRepository: productRepository,
    );
    _openIdConfirmPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // 识别结果原样回传（出生日期是归一后的 d-m-Y），卡类型取证件选择页的行文案。
    expect(certificationRepository.saveCalls, [
      ('NAVEEN TOM VARGHESE', '623099344111', '23-11-1993', 'PRC'),
    ]);
    // 保存成功后继续拉产品详情，走下一步认证。
    expect(productRepository.detailCalls, 1);
  });

  testWidgets('识别结果为空时确认页不发保存请求', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openIdConfirmPage(tester, recognition: const IdentityRecognition());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(certificationRepository.saveCalls, isEmpty);
    expect(find.text('Please complete all fields'), findsOneWidget);
  });

  testWidgets('证件信息确认页可修改识别结果后提交', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openIdConfirmPage(tester);
    await tester.pumpAndSettle();

    // OCR 会认错，姓名 / 证件号要能就地改，提交用改后的值。
    await tester.enterText(find.byKey(const Key('id-confirm-name')), 'BANBU');
    await tester.enterText(
      find.byKey(const Key('id-confirm-id-number')),
      '387740 980198 7862',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(certificationRepository.saveCalls, [
      ('BANBU', '387740 980198 7862', '23-11-1993', 'PRC'),
    ]);
  });

  testWidgets('证件信息确认页点生日弹日期选择面板，Done 回填 dd-MM-yyyy', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());
    _openIdConfirmPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('id-confirm-birth-date')));
    await tester.pumpAndSettle();

    // 面板按蓝湖稿 03-02：右上角灰色 Done + 日 / 月 / 年三列滚轮。
    expect(find.text('Done'), findsOneWidget);
    expect(find.byKey(const Key('id-confirm-birth-day')), findsOneWidget);
    expect(find.byKey(const Key('id-confirm-birth-month')), findsOneWidget);
    expect(find.byKey(const Key('id-confirm-birth-year')), findsOneWidget);

    await tester.tap(find.byKey(const Key('id-confirm-birth-done')));
    await tester.pumpAndSettle();

    // 选完回填的仍是保存接口要的 dd-MM-yyyy。
    expect(find.text('23-11-1993'), findsOneWidget);
  });

  testWidgets('证件选择页请求中显示 Loading，失败可重试', (tester) async {
    final certificationRepository = _StubCertificationRepository(
      delay: const Duration(seconds: 1),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );

    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(productId: '7'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 请求还没回来：头图 + Loading，不能是白屏。
    expect(_assetImage(AppAssets.idVerifyHeader), findsOneWidget);
    expect(find.byType(LoadingView), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LoadingView), findsNothing);
    expect(find.text('PRC'), findsOneWidget);
  });

  testWidgets('证件选择页接口失败给错误态与重试入口', (tester) async {
    final certificationRepository = _StubCertificationRepository(
      failure: const ApiException(
        type: ApiFailureType.noConnection,
        message: 'Network unreachable',
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );

    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(productId: '7'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Network unreachable'), findsOneWidget);

    // 重试会按同一个产品 id 再请求一次。
    // 注意 Riverpod 3 默认会对失败的 provider 做指数退避重试（最多 10 次），
    // 这里只推一帧，断言「确实又发起了请求」，不去和自动重试的次数较劲。
    final callsBeforeRetry = certificationRepository.identityInfoCalls.length;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(
      certificationRepository.identityInfoCalls.length,
      greaterThan(callsBeforeRetry),
    );
  });

  testWidgets('证件选择页在后端不下发证件时走空态', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(
        data: const IdVerificationData(recommended: [], other: []),
      ),
    );

    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(productId: '7'),
    );
    await tester.pumpAndSettle();

    // 空态：给文案，而不是两张没有内容的空卡片。
    expect(find.text('No ID types available yet'), findsOneWidget);
    expect(find.text('Recommended ID Type'), findsNothing);
    expect(find.text('Other Options'), findsNothing);
  });

  testWidgets('身份认证项直接进入证件选择页并带上产品 id', (tester) async {
    // 桩仓库默认的下一步认证项就是身份认证（`taskType = Kegful`）。
    final productRepository = _StubProductRepository();
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      certificationRepository: certificationRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(find.byType(IdVerificationPage), findsOneWidget);
    expect(find.text('Recommended ID Type'), findsOneWidget);
    // 认证项按产品下发：大卡的产品 id 必须传到证件选择页。
    expect(certificationRepository.identityInfoCalls, ['1']);
  });

  testWidgets('人脸识别页按蓝湖稿 03-01 渲染头图、示范图、标题与主按钮', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());
    _openFaceVerificationPage(tester);
    await tester.pumpAndSettle();

    // 头图 / 示范图 / 返回按钮 / 按钮底图都是设计稿切图，不要在代码里重画。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.faceVerifyDemo), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);
    expect(find.text('Face verification'), findsOneWidget);

    // 引导段落按设计稿的三行断行。
    expect(
      find.text(
        'Move naturally, ensure\n'
        'good light. Once passed,\n'
        'your identity is verified.',
      ),
      findsOneWidget,
    );

    // 示范图顶边压在头图下沿上 19pt（设计稿 top 194，头图 213）。
    final headerRect = tester.getRect(
      _assetImage(AppAssets.idVerifyHeaderBlank),
    );
    final demoRect = tester.getRect(_assetImage(AppAssets.faceVerifyDemo));
    expect(headerRect.bottom - demoRect.top, closeTo(19 * _designScale, 0.5));
    expect(demoRect.width, closeTo(343 * _designScale, 0.5));
    expect(demoRect.height, closeTo(420 * _designScale, 0.5));

    // 示范图与按钮之间的间距（设计稿 614 -> 714）。
    expect(
      tester.getRect(_assetImage(AppAssets.idVerifyUploadButton)).top -
          demoRect.bottom,
      closeTo(100 * _designScale, 0.5),
    );
  });

  testWidgets('人脸识别页引导文案优先用产品详情下发的 overwhelming.seisin', (tester) async {
    const apiPrompt = 'Smile for the camera. Position your face clearly.';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      setUp: (container) async {
        container
            .read(sessionStoreProvider)
            .saveProductDetailLivenessPrompt(apiPrompt);
      },
    );
    _openFaceVerificationPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(apiPrompt), findsOneWidget);
    expect(find.textContaining('Move naturally'), findsNothing);
  });

  testWidgets('人脸识别页取 token、拉起活体、回传抓拍图并继续下一步', (tester) async {
    _mockCameraPermission(1);
    final certificationRepository = _StubCertificationRepository();
    final livenessGateway = _StubLivenessGateway();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      productRepository: productRepository,
      certificationRepository: certificationRepository,
      livenessGateway: livenessGateway,
    );
    _openFaceVerificationPage(tester, orderNo: 'ORDER-9');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // token 接口拿订单号，SDK 用下发的授权码拉起。
    expect(certificationRepository.faceTokenCalls, ['ORDER-9']);
    expect(livenessGateway.licenses, ['LICENSE-1']);

    // 抓拍图上传用 SDK 的 livenessId + token，活体类型 7（trustdecision）。
    expect(certificationRepository.faceUploadCalls, hasLength(1));
    final (facePath, livenessId, license, livenessType) =
        certificationRepository.faceUploadCalls.single;
    expect(facePath, isNotEmpty);
    expect(livenessId, 'LIVE-1');
    expect(license, 'LICENSE-1');
    expect(livenessType, 7);

    // 上传成功后继续产品详情：默认下一步仍是身份认证。
    expect(productRepository.detailCalls, greaterThan(0));
    expect(find.byType(IdVerificationPage), findsOneWidget);
  });

  testWidgets('人脸识别页活体未通过时不回传抓拍图并提示', (tester) async {
    _mockCameraPermission(1);
    final certificationRepository = _StubCertificationRepository();
    final livenessGateway = _StubLivenessGateway(
      outcome: const LivenessOutcome(passed: false, message: 'Liveness failed'),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      livenessGateway: livenessGateway,
    );
    _openFaceVerificationPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(livenessGateway.licenses, ['LICENSE-1']);
    // 没过活体就没有抓拍图，不能发上传请求。
    expect(certificationRepository.faceUploadCalls, isEmpty);
    expect(find.text('Liveness failed'), findsOneWidget);
  });

  testWidgets('人脸识别页相机权限被拒时弹引导、不取 token 也不拉起活体', (tester) async {
    _mockCameraPermission(0);
    final certificationRepository = _StubCertificationRepository();
    final livenessGateway = _StubLivenessGateway();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      livenessGateway: livenessGateway,
    );
    _openFaceVerificationPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // 权限没过：先弹引导弹窗，token 与 SDK 都不能动。
    expect(find.text('Enable Camera to Continue'), findsOneWidget);
    expect(certificationRepository.faceTokenCalls, isEmpty);
    expect(livenessGateway.licenses, isEmpty);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(_cameraSettingsOpened, 1);
    expect(find.text('Enable Camera to Continue'), findsNothing);
  });

  testWidgets('人脸识别页 token 返回 400 时引导重新上传身份证', (tester) async {
    _mockCameraPermission(1);
    final certificationRepository = _StubCertificationRepository(
      faceToken: const FaceTokenResult(resultCode: 400),
    );
    final livenessGateway = _StubLivenessGateway();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      livenessGateway: livenessGateway,
    );
    _openFaceVerificationPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Upload Your ID Again'), findsOneWidget);
    // 还没拿到 token，不能拉起活体 SDK。
    expect(livenessGateway.licenses, isEmpty);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(IdVerificationPage), findsOneWidget);
  });

  testWidgets('产品详情下一步是活体时进入人脸识别页并带上订单号', (tester) async {
    _mockCameraPermission(1);
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-9'),
        nextStep: ProductNextStep(taskType: 'Reargued', title: 'Living'),
      ),
    );
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      certificationRepository: certificationRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(find.byType(FaceVerificationPage), findsOneWidget);

    // 订单号带下去后，点主按钮直接用产品详情的订单号取 token。
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(certificationRepository.faceTokenCalls, ['ORDER-9']);
  });

  test('获取身份信息接口带产品 id 与业务混淆字段', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).getIdentityInfo(productId: '7');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.identityInfo);
    expect(params[ApiFields.productId], '7');
    expect(params.containsKey(ApiFields.obfuscateIdentityInfo), isTrue);
  });

  test('证件上传接口带上传类型、来源、卡类型与文件字段', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).uploadIdentityImage(
      filePath: '/tmp/id-card.jpg',
      cardType: 'PRC',
      source: IdentityPhotoSource.camera,
    );

    final (path, fileField, fields) = client.uploads.single;
    expect(path, ApiEndpoints.uploadIdentityImage);
    expect(fileField, ApiFields.uploadFileField);
    // 固定「身份证正面」，来源取枚举，卡类型原样带下去。
    expect(fields[ApiFields.uploadType], '11');
    expect(
      fields[ApiFields.uploadImageSource],
      IdentityPhotoSource.camera.code,
    );
    expect(fields[ApiFields.uploadCardType], 'PRC');
    // 活体参数用不到，但字段必须存在且带空串。
    for (final key in [
      ApiFields.uploadLivenessId,
      ApiFields.uploadLivenessLicense,
      ApiFields.uploadFaceType,
      ApiFields.uploadBizId,
    ]) {
      expect(fields.containsKey(key), isTrue, reason: key);
      expect(fields[key], isEmpty, reason: key);
    }
  });

  test('身份信息解析 magisterial 的推荐 / 其他两段证件', () {
    final data = IdVerificationData.fromJson(const {
      ApiFields.idCardGroups: [
        ['DRIVINGLICENSE', 'PRC', 'SSS'],
        ['TIN', 'VOTERID'],
      ],
    });

    // 第一段是推荐、第二段是其他，顺序照抄，文案不做映射。
    expect(data.recommended, ['DRIVINGLICENSE', 'PRC', 'SSS']);
    expect(data.other, ['TIN', 'VOTERID']);
    expect(data.isEmpty, isFalse);
  });

  test('身份信息丢掉 magisterial 里的空文案', () {
    final data = IdVerificationData.fromJson(const {
      ApiFields.idCardGroups: [
        ['PRC', '', null],
        ['TIN'],
      ],
    });

    expect(data.recommended, ['PRC']);
    expect(data.other, ['TIN']);
  });

  test('保存身份证信息接口带姓名、证件号、d-m-Y 出生日期与卡类型', () async {
    final client = _RecordingClient();
    final repository = CertificationRepository(client);

    await repository.saveIdentityInfo(
      name: 'NAVEEN TOM VARGHESE',
      idNumber: '623099344111',
      birthDate: '23-11-1993',
      cardType: 'PRC',
    );

    expect(client.calls, hasLength(1));
    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.saveIdentityInfo);
    expect(params[ApiFields.identityName], 'NAVEEN TOM VARGHESE');
    expect(params[ApiFields.identityIdNumber], '623099344111');
    expect(params[ApiFields.identityBirthDate], '23-11-1993');
    expect(params[ApiFields.uploadType], '11');
    expect(params[ApiFields.uploadCardType], 'PRC');
    // 混淆字段必须带且非空。
    expect(params[ApiFields.obfuscateSaveIdentity], isNotEmpty);
  });

  test('产品详情解析 overwhelming.bocking 作为确认页引导文案', () {
    final detail = ProductDetail.fromJson({
      ApiFields.applyResultCode: 200,
      ApiFields.detailTips: {
        ApiFields.detailTipIdentity: 'upload prompt',
        ApiFields.detailTipIdentitySuccess: 'confirm prompt',
      },
    });

    expect(detail.identityPrompt, 'upload prompt');
    expect(detail.identitySuccessPrompt, 'confirm prompt');
  });

  test('产品详情解析 overwhelming.seisin 作为人脸页引导文案', () {
    final detail = ProductDetail.fromJson({
      ApiFields.applyResultCode: 200,
      ApiFields.detailTips: {
        ApiFields.detailTipIdentity: 'upload prompt',
        ApiFields.detailTipIdentitySuccess: 'confirm prompt',
        ApiFields.detailTipLiveness: 'face prompt',
      },
    });

    expect(detail.livenessPrompt, 'face prompt');
    // 三个认证页各取各的一条，不能串味。
    expect(detail.identityPrompt, 'upload prompt');
    expect(detail.identitySuccessPrompt, 'confirm prompt');
  });

  test('face token 响应解析 result_code / token / 活体类型', () {
    final result = FaceTokenResult.fromJson(const {
      ApiFields.faceTokenResultCode: '200',
      ApiFields.faceTokenBizUrl: 'https://facepp.example',
      ApiFields.faceToken: 'TOKEN-1',
      ApiFields.faceTokenError: '',
      ApiFields.uploadFaceType: 7,
    });

    expect(result.resultCode, 200);
    expect(result.bizUrl, 'https://facepp.example');
    expect(result.token, 'TOKEN-1');
    expect(result.livenessType, 7);
    expect(result.canStartLiveness, isTrue);
    expect(result.needsIdentityResubmit, isFalse);

    // `400` 是「重新上传身份证」，缺 token 时不能拉起 SDK。
    final resubmit = FaceTokenResult.fromJson(const {
      ApiFields.faceTokenResultCode: 400,
    });
    expect(resubmit.needsIdentityResubmit, isTrue);
    expect(resubmit.canStartLiveness, isFalse);
  });

  test('获取 face token 接口带订单号、类型与两个混淆字段', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).getFaceToken(orderNo: 'ORDER-1');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.faceToken);
    expect(params[ApiFields.faceTokenOrderNo], 'ORDER-1');
    expect(params[ApiFields.faceTokenType], '0');
    expect(params[ApiFields.obfuscateFaceToken1], isNotEmpty);
    expect(params[ApiFields.obfuscateFaceToken2], isNotEmpty);
  });

  test('上传活体照片接口带 type=10、来源 1 与活体参数', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).uploadFaceImage(
      filePath: '/tmp/face.jpg',
      livenessId: 'LIVE-1',
      license: 'LICENSE-1',
      livenessType: 7,
    );

    final (path, fileField, fields) = client.uploads.single;
    expect(path, ApiEndpoints.uploadIdentityImage);
    expect(fileField, ApiFields.uploadFileField);
    expect(fields[ApiFields.uploadType], '10');
    expect(fields[ApiFields.uploadImageSource], '1');
    expect(fields[ApiFields.uploadLivenessId], 'LIVE-1');
    expect(fields[ApiFields.uploadLivenessLicense], 'LICENSE-1');
    expect(fields[ApiFields.uploadFaceType], '7');
  });

  test('上传响应里的出生日期归一成保存接口要求的 dd-MM-yyyy', () {
    final recognition = IdentityRecognition.fromUploadResponse(
      _StubCertificationRepository.uploadData,
    );

    expect(recognition.name, 'NAVEEN TOM VARGHESE');
    expect(recognition.idNumber, '623099344111');
    expect(recognition.birthDate, '23-11-1993');
    expect(recognition.imageUrl, '');
  });

  test('出生日期同时支持 dd/MM/yyyy 与 yyyy/MM/dd，统一成 dd-MM-yyyy', () {
    // 上传响应是日在先，身份信息 gaonate 响应是年在先。
    expect(IdentityRecognition.normalizeBirthDate('23/11/1993'), '23-11-1993');
    expect(IdentityRecognition.normalizeBirthDate('1969/11/03'), '03-11-1969');
    expect(IdentityRecognition.normalizeBirthDate('1993-11-23'), '23-11-1993');
    expect(IdentityRecognition.normalizeBirthDate('1993.11.23'), '23-11-1993');
    // 不存在的日期不瞎猜，原样返回交给用户改。
    expect(IdentityRecognition.normalizeBirthDate('1993/02/30'), '1993/02/30');
    expect(IdentityRecognition.normalizeBirthDate(''), '');
  });

  test('身份信息没有下发证件配置时按空处理', () {
    // 低版本 / 未灰度用户：`wollongong` 缺失或为空。
    expect(IdVerificationData.fromJson(const {}).isEmpty, isTrue);
    expect(
      IdVerificationData.fromJson(const {ApiFields.idCardGroups: []}).isEmpty,
      isTrue,
    );
  });

  testWidgets('个人信息页按蓝湖稿 03-02 渲染头图、进度缎带与字段列表', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    // 头图复用证件上传页那张不带标题的渐变 + 吉祥物切图。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
    // 进度缎带与 Upload 按钮底图都是设计稿切图，不要在代码里重画。
    expect(_assetImage(AppAssets.personalInfoProgressRibbon), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);

    expect(find.text('Basic identity information'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    // 字段标题与当前值都来自接口下发的表单。
    for (final title in [
      'Gender',
      'Email',
      'Home Phone Number',
      'Residential Address',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('male'), findsOneWidget);
    expect(find.text('a@b.com'), findsOneWidget);
    // 未填的输入框展示接口下发的占位文案。
    expect(find.text('Please enter'), findsOneWidget);

    // 表单接口的 `befleas` 作为引导文案（产品详情没下发时）。
    expect(
      find.text('Fill in personal information truthfully and accurately'),
      findsOneWidget,
    );

    // 缎带顶边比头图下沿高 28pt（设计稿 185 与 213）。
    final headerRect = tester.getRect(
      _assetImage(AppAssets.idVerifyHeaderBlank),
    );
    final ribbonRect = tester.getRect(
      _assetImage(AppAssets.personalInfoProgressRibbon),
    );
    expect(headerRect.bottom - ribbonRect.top, closeTo(28 * _designScale, 1));

    // 输入框取值行也要撑满 48pt 并垂直居中，不缩到文字高度贴着行顶
    // （选项行的 Align 本来就会撑满，拿输入框才测得出问题）。
    final valueRow = find
        .ancestor(
          of: find.byKey(const Key('personal-info-field-offer')),
          matching: find.byType(Row),
        )
        .first;
    expect(tester.getSize(valueRow).height, closeTo(48 * _designScale, 0.5));

    // 字段行距 94pt（标题 22 + 8 + 行 48 + 字段间距 16）。
    double centerY(Finder finder) => tester.getCenter(finder).dy;
    expect(
      centerY(find.text('Email')) - centerY(find.text('Gender')),
      closeTo(94 * _designScale, 0.5),
    );
    expect(
      centerY(find.text('Home Phone Number')) - centerY(find.text('Email')),
      closeTo(94 * _designScale, 0.5),
    );
  });

  testWidgets('个人信息页引导文案优先用产品详情下发的 overwhelming.deerherd', (tester) async {
    const apiPrompt =
        'Fill it out accurately, clean data lifts approval odds to 98%.';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
      setUp: (container) async {
        container
            .read(sessionStoreProvider)
            .saveProductDetailPersonalPrompt(apiPrompt);
      },
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(apiPrompt), findsOneWidget);
    expect(find.textContaining('truthfully and accurately'), findsNothing);
  });

  testWidgets('个人信息页后端不下发文案时用设计稿兜底引导段', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    certificationRepository.personalInfo = PersonalInfoData(
      tips: '',
      fields: _StubCertificationRepository.personalInfoData.fields,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Share your info securely.\n'
        'It\'s the first step toward\n'
        'getting the funds you\n'
        'need.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('个人信息页枚举字段弹选项面板，Done 回填展示文案与提交值', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      productRepository: productRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('personal-info-field-copies')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-info-option-done')), findsOneWidget);

    // 滚到第二项（female / 2），确认后写回行文案。
    // 只有两项，滚过头会被夹到最后一项，不用和滚轮的吸附距离较劲。
    await tester.drag(
      find.byKey(const Key('personal-info-option-wheel')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-info-option-done')));
    await tester.pumpAndSettle();

    expect(find.text('female'), findsOneWidget);
    expect(find.text('male'), findsNothing);

    // 提交的是选项的 `liquidators`（2），不是展示文案。
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(certificationRepository.savePersonalInfoCalls.single['copies'], '2');
  });

  testWidgets('个人信息页地址字段拉地址层级并回填拼好的完整地址', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('personal-info-field-residential_address')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('personal-info-address-sheet')),
      findsOneWidget,
    );
    expect(certificationRepository.addressInitCalls, 1);

    // 逐层点下去：省 -> 市 -> 区，最深一层没有下级就收面板。
    for (var level = 0; level < 3; level++) {
      await tester.tap(find.byKey(const Key('personal-info-address-option-0')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Region I-Pangasinan-Alcala'), findsOneWidget);

    // 同一页面再点一次不再重复拉地址数据。
    await tester.tap(
      find.byKey(const Key('personal-info-field-residential_address')),
    );
    await tester.pumpAndSettle();
    expect(certificationRepository.addressInitCalls, 1);
  });

  testWidgets('个人信息页点 Upload 按 crucians 回传表单并继续下一步认证', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      productRepository: productRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // key 用接口下发的 `crucians`，值用 `fed` / 选项的 `liquidators`。
    expect(certificationRepository.savePersonalInfoCalls, [
      {
        'copies': '1',
        'offer': 'a@b.com',
        'hyphal': '',
        'residential_address': '',
      },
    ]);
    // 保存成功后继续拉产品详情，走下一步认证。
    expect(productRepository.detailCalls, 1);
  });

  testWidgets('个人信息页输入框改动后提交改后的值', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('personal-info-field-hyphal')),
      '03211234567',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(
      certificationRepository.savePersonalInfoCalls.single['hyphal'],
      '03211234567',
    );
  });

  testWidgets('个人信息页表单接口失败给错误态与重试入口', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..personalInfoFailure = const ApiException(
        type: ApiFailureType.business,
        message: 'Load failed',
        code: -1,
      );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Load failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(certificationRepository.personalInfoCalls, isNotEmpty);

    // Riverpod 3 默认会对失败的 provider 做指数退避重试，次数不可预期；
    // 只断言「点 Retry 会再发起一次请求」，重试成功后渲染出字段。
    final callsBeforeRetry = certificationRepository.personalInfoCalls.length;
    certificationRepository.personalInfoFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(
      certificationRepository.personalInfoCalls.length,
      greaterThan(callsBeforeRetry),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('个人信息页接口请求中显示 Loading', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..personalInfoDelay = const Duration(milliseconds: 300);
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LoadingView), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Gender'), findsOneWidget);
  });

  testWidgets('个人信息页后端不下发字段时走空态而不是空表单', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..personalInfo = const PersonalInfoData(tips: '', fields: []);
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('No information required yet'), findsOneWidget);

    // 空表单不能提交。
    await tester.tap(find.text('Upload'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(certificationRepository.savePersonalInfoCalls, isEmpty);
  });

  testWidgets('产品详情下一步是个人信息时进入个人信息页并带上产品 id', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-9'),
        nextStep: ProductNextStep(
          taskType: 'FlintiestDevwsor',
          title: 'Personal information',
        ),
      ),
    );
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      certificationRepository: certificationRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(find.byType(PersonalInfoPage), findsOneWidget);
    expect(certificationRepository.personalInfoCalls, isNotEmpty);
  });

  testWidgets('工作信息页按蓝湖稿 03-03 渲染头图、进度缎带与字段列表', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openWorkInfoPage(tester);
    await tester.pumpAndSettle();

    // 头图与进度缎带都复用个人信息页那两张切图，工作信息稿只是换了文案。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
    expect(_assetImage(AppAssets.personalInfoProgressRibbon), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);

    expect(find.text('Job information'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    // 字段标题与当前值都来自工作信息接口下发的表单。
    for (final title in ['Company Name', 'City You Work', 'Type of Work']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('SPSS'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    // 未填的地址字段展示接口下发的占位文案。
    expect(find.text('Please select company address'), findsOneWidget);

    // 接口没给 `befleas`、产品详情也没下发时用工作信息稿的兜底引导段。
    expect(
      find.text(
        'Your job info stays\n'
        'confidential and is only\n'
        'used for credit\n'
        'assessment. Share it\n'
        'with confidence.',
      ),
      findsOneWidget,
    );

    // 缎带顶边比头图下沿高 28pt（设计稿 185 与 213），与个人信息页一致。
    final headerRect = tester.getRect(
      _assetImage(AppAssets.idVerifyHeaderBlank),
    );
    final ribbonRect = tester.getRect(
      _assetImage(AppAssets.personalInfoProgressRibbon),
    );
    expect(headerRect.bottom - ribbonRect.top, closeTo(28 * _designScale, 1));
  });

  testWidgets('工作信息页引导文案优先用产品详情下发的 overwhelming.ssn', (tester) async {
    const apiPrompt =
        'Tell us about your job, solid work info keeps the green light flashing.';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
      setUp: (container) async {
        container
            .read(sessionStoreProvider)
            .saveProductDetailWorkPrompt(apiPrompt);
      },
    );
    _openWorkInfoPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(apiPrompt), findsOneWidget);
    // 工作信息的接口文案不会串到个人信息页那条 `deerherd` 上。
    expect(find.textContaining('confidential and is only'), findsNothing);
  });

  testWidgets('工作信息页点 Upload 走保存工作信息接口并继续下一步认证', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      productRepository: productRepository,
    );
    _openWorkInfoPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // key 用工作信息接口下发的 `crucians`，值用 `fed` / 选项的 `liquidators`。
    expect(certificationRepository.saveWorkInfoCalls, [
      {'undauntable': 'SPSS', 'printed': '', 'profit': '1'},
    ]);
    // 保存成功后再拉产品详情，走下一步认证。
    expect(productRepository.detailCalls, 1);
    // 下一步默认是身份认证，说明保存后的跳转链路真的走通了，
    // 并且顶层认证跳转会清掉工作信息页。
    expect(find.byType(IdVerificationPage), findsOneWidget);
    expect(find.byType(WorkInformationPage), findsNothing);
  });

  testWidgets('产品详情下一步是工作信息时进入工作信息页并带上产品 id', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-9'),
        nextStep: ProductNextStep(
          taskType: 'TrussvilleUninstructively',
          title: 'Job information',
        ),
      ),
    );
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      certificationRepository: certificationRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkInformationPage), findsOneWidget);
    expect(certificationRepository.workInfoCalls, ['1']);
  });

  testWidgets('从个人信息进入工作信息时清掉上一个认证页（顶层认证）', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();
    expect(find.byType(PersonalInfoPage), findsOneWidget);

    // 与 ProductApplicationFlow 进入下一个认证项时用的是同一条路径。
    AppNavigator.pushTopLevelCertification(
      AppRoutes.workInfo,
      arguments: const WorkInfoPageArguments(productId: '7'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WorkInformationPage), findsOneWidget);
    expect(find.byType(PersonalInfoPage), findsNothing);
    expect(certificationRepository.workInfoCalls, ['7']);
  });

  testWidgets('选项面板不预选：重开时停在第一项', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..personalInfo = const PersonalInfoData(
        tips: '',
        fields: [
          PersonalInfoField(
            title: 'Education',
            placeholder: 'Please select education',
            key: 'phillis',
            control: PersonalInfoControl.selection,
            isNumeric: false,
            options: [
              PersonalInfoOption(label: 'Primary School', value: '1'),
              PersonalInfoOption(label: 'High School', value: '2'),
              PersonalInfoOption(label: 'Undergraduate', value: '3'),
            ],
            initialDisplayValue: 'Undergraduate',
            initialSubmitValue: '3',
          ),
        ],
      );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openPersonalInfoPage(tester);
    await tester.pumpAndSettle();

    // 行上仍按接口下发的 `fed` 展示已保存的值。
    expect(find.text('Undergraduate'), findsOneWidget);

    // 打开面板：停在第一项，不回填当前值；直接 Done 就选到第一项。
    await tester.tap(find.byKey(const Key('personal-info-field-phillis')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-info-option-done')));
    await tester.pumpAndSettle();

    expect(find.text('Primary School'), findsOneWidget);
    expect(find.text('Undergraduate'), findsNothing);
  });

  test('工作信息发薪日字段解析二级选项并把 fed 还原成提交值', () {
    // 口径取接口文档「获取工作信息（第三项）」的 Payday 字段：
    // 一级是发薪周期，周期自己再带一组下级选项；`fed` 是「一级文案|二级文案」。
    final data = PersonalInfoData.fromJson(const {
      ApiFields.infoFieldList: [
        {
          ApiFields.infoFieldKey: 'opportunities',
          ApiFields.infoFieldTitle: 'Payday',
          ApiFields.infoFieldControl: 'stepped',
          ApiFields.infoFieldValue: 'Once a Month|1',
          ApiFields.infoFieldOptions: [
            {
              ApiFields.infoOptionLabel: 'Once a Month',
              ApiFields.infoOptionValue: 4,
              ApiFields.infoFieldOptions: [
                {ApiFields.infoOptionLabel: 1, ApiFields.infoOptionValue: 11},
                {ApiFields.infoOptionLabel: 2, ApiFields.infoOptionValue: 12},
              ],
            },
            {
              ApiFields.infoOptionLabel: 'Daily',
              ApiFields.infoOptionValue: 1,
              ApiFields.infoFieldOptions: [
                {
                  ApiFields.infoOptionLabel: 'Daily',
                  ApiFields.infoOptionValue: 1,
                },
              ],
            },
          ],
        },
      ],
    });

    final field = data.fields.single;
    expect(field.hasNestedOptions, isTrue);
    // 一级选项顺序按后端下发，不在客户端排序。
    expect(field.options.map((option) => option.label), [
      'Once a Month',
      'Daily',
    ]);
    expect(field.options.first.children.map((child) => child.value), [
      '11',
      '12',
    ]);
    // 展示保留 `一级|二级`，提交值要换成二级的 `liquidators`。
    expect(field.initialDisplayValue, 'Once a Month|1');
    expect(field.initialSubmitValue, '11');
    // 下游接口原样回传的二级值（`fed` 只给文案、不给 value）也要能还原。
    final byChildValue = PersonalInfoData.fromJson(const {
      ApiFields.infoFieldList: [
        {
          ApiFields.infoFieldKey: 'opportunities',
          ApiFields.infoFieldControl: 'stepped',
          ApiFields.infoFieldValue: 12,
          ApiFields.infoFieldOptions: [
            {
              ApiFields.infoOptionLabel: 'Once a Month',
              ApiFields.infoOptionValue: 4,
              ApiFields.infoFieldOptions: [
                {ApiFields.infoOptionLabel: 1, ApiFields.infoOptionValue: 11},
                {ApiFields.infoOptionLabel: 2, ApiFields.infoOptionValue: 12},
              ],
            },
          ],
        },
      ],
    });
    expect(byChildValue.fields.single.initialDisplayValue, 'Once a Month|2');
    expect(byChildValue.fields.single.initialSubmitValue, '12');
  });

  testWidgets('工作信息发薪日字段先选周期再选具体日期，提交二级 liquidators', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..workInfo = _StubCertificationRepository.paydayData;
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      productRepository: _StubProductRepository(),
    );
    _openWorkInfoPage(tester);
    await tester.pumpAndSettle();

    // 回填口径：行上展示 `周期|发薪日`，不是接口原样字符串。
    expect(find.text('Once a Month|2'), findsOneWidget);

    // 打开面板：先出周期，且从第一项（Daily）开始，不回填上次选中的值。
    await tester.tap(
      find.byKey(const Key('personal-info-field-opportunities')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-info-option-done')), findsOneWidget);

    // 向上滚一项：Daily -> Weekly。
    await tester.drag(
      find.byKey(const Key('personal-info-option-wheel')),
      const Offset(0, -70),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-info-option-done')));
    await tester.pumpAndSettle();

    // 选中有下级的周期后再弹一次，这次只列该周期的下级选项。
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Daily'), findsNothing);

    // 下级同样从第一项（Mon）开始：向上滚一项 -> Tue。
    await tester.drag(
      find.byKey(const Key('personal-info-option-wheel')),
      const Offset(0, -70),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-info-option-done')));
    await tester.pumpAndSettle();

    expect(find.text('Weekly|Tue'), findsOneWidget);

    // 再点一次：周期面板回到第一项 Daily，而不是上次选的 Weekly。
    await tester.tap(
      find.byKey(const Key('personal-info-field-opportunities')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Weekly'), findsOneWidget);
    // 直接 Done 走到 Daily 的下级（只有 Daily 一项），再 Done。
    await tester.tap(find.byKey(const Key('personal-info-option-done')));
    await tester.pumpAndSettle();
    expect(find.text('Mon'), findsNothing);
    await tester.tap(find.byKey(const Key('personal-info-option-done')));
    await tester.pumpAndSettle();
    expect(find.text('Daily|Daily'), findsOneWidget);
    expect(find.text('Weekly|Tue'), findsNothing);

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    // 提交的是二级选项的 `liquidators`，Daily 的下级值就是 1。
    expect(
      certificationRepository.saveWorkInfoCalls.single['opportunities'],
      '1',
    );
  });

  testWidgets('紧急联系人页按蓝湖稿 03-04 渲染头图、进度缎带与三组联系人', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    expect(certificationRepository.emergencyContactCalls, ['7']);

    // 头图和进度缎带都复用前两页那两张切图。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
    expect(_assetImage(AppAssets.personalInfoProgressRibbon), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);
    // 行尾通讯录图标是用户提供的切图，不要在代码里重画。
    expect(_assetImage(AppAssets.emergencyContactPicker), findsNWidgets(3));

    expect(find.text('Urgent contact person'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);

    // 三条联系人由后端下发，分组标题按位置号顺序生成。
    for (var index = 1; index <= 3; index++) {
      expect(
        find.text('Relationship with Emergency Contacts - $index'),
        findsOneWidget,
      );
    }
    expect(find.text('Relationship'), findsNWidgets(3));
    expect(find.text('Contact Information'), findsNWidgets(3));
    expect(find.text('telephone number'), findsNWidgets(3));

    // 第一条带姓名与手机号，后两条走设计稿的占位文案。
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('86543217190'), findsOneWidget);
    expect(find.text('Friend'), findsNWidgets(3));
    expect(find.text('Name'), findsNWidgets(2));
    expect(find.text('Phone Number'), findsNWidgets(2));

    // 接口的 `befleas` 作为引导文案（产品详情没下发时）。
    expect(
      find.text('We will protect your personal information from disclosure'),
      findsOneWidget,
    );

    // 缎带顶边比头图下沿高 28pt（设计稿 185 与 213），
    // 且与个人信息页同一张切图、铺满 343pt 白卡宽。
    final headerRect = tester.getRect(
      _assetImage(AppAssets.idVerifyHeaderBlank),
    );
    final ribbonRect = tester.getRect(
      _assetImage(AppAssets.personalInfoProgressRibbon),
    );
    expect(headerRect.bottom - ribbonRect.top, closeTo(28 * _designScale, 1));
    expect(ribbonRect.width, closeTo(343 * _designScale, 0.5));
    expect(
      ribbonRect.center.dx,
      closeTo(tester.getSize(find.byType(EmergencyContactPage)).width / 2, 1),
    );
    // 缎带下沿 33pt + 白卡内顶距 12pt 到第一个分组标题（设计稿 218 / 230）。
    final cardRect = tester.getRect(
      find.byKey(const Key('emergency-contact-title-first')),
    );
    expect(cardRect.top - ribbonRect.top, closeTo((33 + 12) * _designScale, 1));

    // 分组间距 308pt（标题 18 + 16 + 22 + 8 + 48 + 12 + 22 + 8 + 48 + 12 +
    // 22 + 22 + 20 + 30）。
    double centerY(Finder finder) => tester.getCenter(finder).dy;
    expect(
      centerY(find.text('Relationship with Emergency Contacts - 2')) -
          centerY(find.text('Relationship with Emergency Contacts - 1')),
      closeTo(308 * _designScale, 0.5),
    );
    expect(
      centerY(find.text('Relationship with Emergency Contacts - 3')) -
          centerY(find.text('Relationship with Emergency Contacts - 2')),
      closeTo(308 * _designScale, 0.5),
    );
  });

  testWidgets('紧急联系人页引导文案优先用产品详情下发的 overwhelming.embol', (tester) async {
    const apiPrompt =
        'Emergency contacts are only used to reach you, never for marketing.';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
      setUp: (container) async {
        container
            .read(sessionStoreProvider)
            .saveProductDetailEmergencyContactPrompt(apiPrompt);
      },
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(apiPrompt), findsOneWidget);
    // 接口的 `befleas` 不会顶掉产品详情那条文案。
    expect(
      find.textContaining('protect your personal information'),
      findsNothing,
    );
  });

  testWidgets('紧急联系人页后端不下发文案时用设计稿兜底引导段', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    certificationRepository.emergencyContacts = EmergencyContactData(
      contacts: _StubCertificationRepository.emergencyContactData.contacts,
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Emergency contacts help\n'
        'secure your account. We\n'
        'respect every contact\'s\n'
        'privacy.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('紧急联系人页关系下拉弹选项面板，Done 回填展示文案', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('emergency-contact-relation-first')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-info-option-done')), findsOneWidget);

    // 面板不预选，从第一项 Parent 开始：向上滚一项 -> Spouse。
    await tester.drag(
      find.byKey(const Key('personal-info-option-wheel')),
      const Offset(0, -70),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-info-option-done')));
    await tester.pumpAndSettle();

    expect(find.text('Spouse'), findsOneWidget);
    expect(find.text('Friend'), findsNWidgets(2));

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    // 提交回传的是选项的 `liquidators`，不是展示文案。
    expect(
      certificationRepository
          .saveEmergencyContactCalls
          .single
          .first
          .relationValue,
      '2',
    );
  });

  testWidgets('紧急联系人页点手机号区域也打开通讯录选人并一起回填', (tester) async {
    _mockPickedContact(name: 'Bob Lee', phone: '9171234567');
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    // 后两条默认没选人，姓名 / 手机号都走占位文案。
    expect(find.text('Name'), findsNWidgets(2));
    expect(find.text('Phone Number'), findsNWidgets(2));

    // 点手机号区域（设计稿 `text_13`）同样拉起系统选人。
    final phoneRow = find.byKey(const Key('emergency-contact-phone-second'));
    await tester.ensureVisible(phoneRow);
    await tester.pumpAndSettle();
    await tester.tap(phoneRow);
    await tester.pumpAndSettle();

    // 姓名与手机号一起回填，占位文案各少一个。
    expect(find.text('Bob Lee'), findsOneWidget);
    expect(find.text('9171234567'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);

    // 提交回传的是选中的联系人。
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    final saved = certificationRepository.saveEmergencyContactCalls.single;
    expect(saved[1].name, 'Bob Lee');
    expect(saved[1].mobile, '9171234567');
  });

  testWidgets('紧急联系人页点 Upload 按 canmaker 回传三条联系人并继续下一步认证', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      productRepository: productRepository,
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    final saved = certificationRepository.saveEmergencyContactCalls.single;
    expect(saved.map((contact) => contact.number), [
      'first',
      'second',
      'third',
    ]);
    // 姓名 / 手机号 / 关系都按接口下发的原值回传。
    expect(saved.first.name, 'Anna');
    expect(saved.first.mobile, '86543217190');
    expect(saved.first.relationValue, '5');
    // 后两条没选人，回传空串而不是本地占位文案。
    expect(saved[1].name, '');
    expect(saved[1].mobile, '');

    // 保存成功后再拉产品详情，走下一步认证。
    expect(productRepository.detailCalls, 1);
    expect(find.byType(IdVerificationPage), findsOneWidget);
    expect(find.byType(EmergencyContactPage), findsNothing);
  });

  testWidgets('紧急联系人页接口失败给错误态与重试入口', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    certificationRepository.emergencyContactFailure = const ApiException(
      type: ApiFailureType.business,
      message: 'Contacts unavailable',
      code: 500,
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Contacts unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Riverpod 3 默认会对失败的 provider 做指数退避重试，次数不可预期；
    // 只断言「点 Retry 会再发起一次请求」，重试成功后渲染出联系人。
    final callsBeforeRetry =
        certificationRepository.emergencyContactCalls.length;
    certificationRepository.emergencyContactFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(
      certificationRepository.emergencyContactCalls.length,
      greaterThan(callsBeforeRetry),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Relationship with Emergency Contacts - 1'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('紧急联系人页接口请求中显示 Loading', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    certificationRepository.emergencyContactDelay = const Duration(
      milliseconds: 300,
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openEmergencyContactPage(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LoadingView), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LoadingView), findsNothing);
    expect(
      find.text('Relationship with Emergency Contacts - 1'),
      findsOneWidget,
    );
  });

  testWidgets('紧急联系人页后端不下发联系人时走空态而不是空表单', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    certificationRepository.emergencyContacts = const EmergencyContactData();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openEmergencyContactPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('No emergency contacts required yet'), findsOneWidget);
    expect(
      find.textContaining('Relationship with Emergency Contacts'),
      findsNothing,
    );
  });

  testWidgets('产品详情下一步是紧急联系人时进入紧急联系人页并带上产品 id', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-9'),
        nextStep: ProductNextStep(
          taskType: 'Thriftiness',
          title: 'Urgent contact person',
        ),
      ),
    );
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      certificationRepository: certificationRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyContactPage), findsOneWidget);
    expect(certificationRepository.emergencyContactCalls, ['1']);
  });

  testWidgets('产品详情下一步是绑卡时进入绑卡页并带上产品 id 与订单号', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-9'),
        nextStep: ProductNextStep(
          taskType: 'Bespattered',
          title: 'Informasi bank',
        ),
      ),
    );
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      certificationRepository: certificationRepository,
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    await tester.pumpAndSettle();

    expect(find.byType(BindCardPage), findsOneWidget);
    final page = tester.widget<BindCardPage>(find.byType(BindCardPage));
    expect(page.productId, '1');
    // 提交后要活体会用到订单号，必须从产品详情带下来。
    expect(page.orderNo, 'ORDER-9');
    expect(certificationRepository.bindCardInfoCalls, ['1']);
  });

  test('个人信息表单解析两套控件类型命名', () {
    // 值映射给的是 `enum` / `txt` / `citySelect`，
    // 响应示例给的是 `stepped` / `onto` / `stage`，两套都要认得。
    final mapped = PersonalInfoData.fromJson(const {
      ApiFields.infoFieldTips: 'tip',
      ApiFields.infoFieldList: [
        {
          ApiFields.infoFieldKey: 'a',
          ApiFields.infoFieldTitle: 'A',
          ApiFields.infoFieldControl: 'enum',
          ApiFields.infoFieldValue: 'x',
          ApiFields.infoFieldOptions: [
            {ApiFields.infoOptionLabel: 'x', ApiFields.infoOptionValue: 1},
          ],
        },
        {ApiFields.infoFieldKey: 'b', ApiFields.infoFieldControl: 'txt'},
        {ApiFields.infoFieldKey: 'c', ApiFields.infoFieldControl: 'citySelect'},
      ],
    });
    expect(mapped.tips, 'tip');
    expect(mapped.fields.map((field) => field.control), [
      PersonalInfoControl.selection,
      PersonalInfoControl.text,
      PersonalInfoControl.address,
    ]);
    // 选项的 `fed` 是文案时，提交要换成 `liquidators`。
    expect(mapped.fields.first.initialDisplayValue, 'x');
    expect(mapped.fields.first.initialSubmitValue, '1');

    final example = PersonalInfoData.fromJson(const {
      ApiFields.infoFieldList: [
        {ApiFields.infoFieldKey: 'a', ApiFields.infoFieldControl: 'stepped'},
        {ApiFields.infoFieldKey: 'b', ApiFields.infoFieldControl: 'onto'},
        {ApiFields.infoFieldKey: 'c', ApiFields.infoFieldControl: 'stage'},
        {ApiFields.infoFieldKey: 'd', ApiFields.infoFieldControl: 'unknown'},
      ],
    });
    expect(example.fields.map((field) => field.control), [
      PersonalInfoControl.selection,
      PersonalInfoControl.text,
      PersonalInfoControl.address,
      PersonalInfoControl.unsupported,
    ]);
    // 没有业务 key 的字段直接丢掉，不渲染成空行。
    expect(
      PersonalInfoData.fromJson(const {
        ApiFields.infoFieldList: [
          {ApiFields.infoFieldTitle: 'no key'},
        ],
      }).isEmpty,
      isTrue,
    );
  });

  test('产品详情解析 overwhelming.deerherd 作为个人信息页引导文案', () {
    final detail = ProductDetail.fromJson({
      ApiFields.applyResultCode: 200,
      ApiFields.detailTips: {
        ApiFields.detailTipIdentity: 'upload prompt',
        ApiFields.detailTipPersonal: 'personal prompt',
      },
    });

    expect(detail.personalInfoPrompt, 'personal prompt');
    expect(detail.identityPrompt, 'upload prompt');
    // 没下发的认证页文案保持空，页面自己兜底。
    expect(detail.livenessPrompt, '');
  });

  test('获取个人信息接口带产品 id 与业务混淆字段', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).getPersonalInfo(productId: '7');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.personalInfo);
    expect(params[ApiFields.productId], '7');
    expect(params.containsKey(ApiFields.obfuscatePersonalInfo), isTrue);
  });

  test('保存个人信息接口按 crucians 回传表单并带两个混淆字段', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).savePersonalInfo(
      productId: '7',
      formData: const {'copies': '2', 'residential_address': 'Region I-A-B'},
    );

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.savePersonalInfo);
    expect(params[ApiFields.productId], '7');
    expect(params['copies'], '2');
    expect(params['residential_address'], 'Region I-A-B');
    expect(params[ApiFields.obfuscateSavePersonalInfo1], isNotEmpty);
    expect(params[ApiFields.obfuscateSavePersonalInfo2], isNotEmpty);
  });

  test('地址初始化解析三层 kneeing，丢掉没有名称的脏数据', () {
    final data = AddressInitData.fromJson(const {
      ApiFields.addressNodes: [
        {
          ApiFields.addressName: 'Region I',
          ApiFields.addressCode: '0001',
          ApiFields.addressChildren: [
            {
              ApiFields.addressName: 'Pangasinan',
              ApiFields.addressCode: '00010001',
              ApiFields.addressChildren: [
                {
                  ApiFields.addressName: 'Alcala',
                  ApiFields.addressCode: '000100010001',
                },
                {ApiFields.addressName: 'no code'},
              ],
            },
          ],
        },
        {ApiFields.addressCode: 'missing name'},
      ],
    });

    expect(data.nodes, hasLength(1));
    final province = data.nodes.single.children.single;
    expect(province.name, 'Pangasinan');
    // 只有名称没有编码的下级被丢掉。
    expect(province.children.single.name, 'Alcala');
    expect(province.children.single.children, isEmpty);
  });

  test('地址初始化兼容省列表直接下发在 burner 下、节点缺编码', () {
    final data = AddressInitData.fromJson(const {
      ApiFields.addressChildren: [
        {
          ApiFields.addressName: 'Pangasinan',
          ApiFields.addressCode: '0001',
          ApiFields.addressChildren: [
            {ApiFields.addressName: 'Alcala'},
          ],
        },
      ],
    });

    expect(data.nodes, hasLength(1));
    expect(data.nodes.single.name, 'Pangasinan');
    // 整层都没有编码时退回按名称展示，而不是整片空白。
    expect(data.nodes.single.children.single.name, 'Alcala');
  });

  test('紧急联系人解析 conopholis.kneeing 与关系选项', () {
    final data = EmergencyContactData.fromJson(const {
      ApiFields.emergencyContactTips: 'protect your data',
      ApiFields.emergencyContactEmergent: {
        ApiFields.emergencyContactList: [
          {
            ApiFields.emergencyContactNumber: 'first',
            ApiFields.emergencyContactRelation: '5',
            ApiFields.emergencyContactName: 'Anna',
            ApiFields.emergencyContactMobile: '86543217190',
            ApiFields.emergencyContactDropdown: [
              {
                ApiFields.emergencyContactOptionLabel: 'Parent',
                ApiFields.emergencyContactOptionValue: 1,
              },
              {
                ApiFields.emergencyContactOptionLabel: 'Friend',
                ApiFields.emergencyContactOptionValue: 5,
              },
              {ApiFields.emergencyContactOptionLabel: 'Broken'},
            ],
          },
          {
            ApiFields.emergencyContactNumber: 'second',
            ApiFields.emergencyContactRelation: '5',
          },
        ],
      },
    });

    expect(data.tips, 'protect your data');
    expect(data.contacts, hasLength(2));
    final first = data.contacts.first;
    expect(first.number, 'first');
    expect(first.name, 'Anna');
    expect(first.mobile, '86543217190');
    // 选项的取值是数字也要当字符串；缺取值的那条被丢掉。
    expect(first.relationOptions.map((option) => option.value), ['1', '5']);
    expect(first.relationLabel, 'Friend');
    // 没选关系时不给占位文案，由页面兜底。
    expect(data.contacts[1].relationLabel, '');
  });

  test('紧急联系人只认 conopholis.kneeing，脏数据不整片丢掉', () {
    final data = EmergencyContactData.fromJson(const {
      ApiFields.emergencyContactEmergent: {
        ApiFields.emergencyContactList: [
          {ApiFields.emergencyContactNumber: 'first'},
          'dirty',
          null,
        ],
      },
    });
    // 非对象元素被丢掉，剩下的照常解析。
    expect(data.contacts.single.number, 'first');

    // 没有 `conopholis` 这一层时不猜结构，按空处理。
    expect(EmergencyContactData.fromJson(const {}).contacts, isEmpty);
  });

  test('保存联系人按 canmaker 回传，键名走混淆字段', () {
    const input = EmergencyContactInput(
      number: 'second',
      relationValue: '5',
      name: ' Anna ',
      mobile: ' 86543217190 ',
    );

    expect(input.toJson(), {
      ApiFields.emergencyContactMobile: '86543217190',
      ApiFields.emergencyContactName: 'Anna',
      ApiFields.emergencyContactRelation: '5',
      // 位置号原样回传，首尾空白不 trim（对齐获取接口下发值）。
      ApiFields.emergencyContactNumber: 'second',
    });
  });

  test('产品详情解析 overwhelming.embol 作为紧急联系人页引导文案', () {
    const detail = ProductDetail(
      resultCode: 200,
      basicInfo: ProductBasicInfo(),
      nextStep: ProductNextStep(),
      emergencyContactPrompt: '',
    );
    expect(detail.emergencyContactPrompt, '');

    final parsed = ProductDetail.fromJson(const {
      ApiFields.applyResultCode: 200,
      ApiFields.detailTips: {
        ApiFields.detailTipEmergencyContact:
            'Emergency contacts are only used to reach you.',
        ApiFields.detailTipWork: 'work tip',
      },
    });
    expect(
      parsed.emergencyContactPrompt,
      'Emergency contacts are only used to reach you.',
    );
    // 五条文案各管各的页，不会互相顶替。
    expect(parsed.workInfoPrompt, 'work tip');
    expect(parsed.personalInfoPrompt, '');
  });

  testWidgets('绑卡页按蓝湖稿 03-05 渲染头图、进度缎带与打款方式表单', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    // 分组 / 字段按产品 id 从接口拉取，客户端不写死。
    expect(certificationRepository.bindCardInfoCalls, ['7']);

    // 头图 / 返回按钮 / 进度缎带 / Upload 底图都是设计稿切图。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
    expect(_assetImage(AppAssets.personalInfoProgressRibbon), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);

    expect(find.text('Account management'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // 打款方式 Tab 由接口下发（设计稿 E-wallet 选中）。
    expect(find.text('E-wallet'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);

    // 字段标题与占位文案照接口下发原样展示。
    expect(find.text('Select your recipient E-wallet'), findsOneWidget);
    expect(find.text('Please select'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Middle name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
    expect(find.text('E-wallet Account'), findsOneWidget);
    expect(find.text('Repeat E-wallet Account'), findsOneWidget);
    expect(find.text('Please enter'), findsNWidgets(3));
    expect(find.text('Please enter your E-Wallet account'), findsOneWidget);

    // 底部红字提示取接口下发的 revision。
    expect(
      find.text(
        'Incorrect account numbers cause payout failure. '
        'Double-check all digits.',
      ),
      findsOneWidget,
    );

    // 输入框取值行也要撑满 48pt 并垂直居中，不缩到文字高度贴着行顶
    // （选项行的 Align 本来就会撑满，拿输入框才测得出问题）。
    final valueRow = find
        .ancestor(
          of: find.byKey(const Key('bind-card-field-firstName')),
          matching: find.byType(Row),
        )
        .first;
    expect(tester.getSize(valueRow).height, closeTo(48 * _designScale, 0.5));

    // 缎带顶边比头图下沿高 28pt（设计稿 185 与 213）。
    final headerRect = tester.getRect(
      _assetImage(AppAssets.idVerifyHeaderBlank),
    );
    final ribbonRect = tester.getRect(
      _assetImage(AppAssets.personalInfoProgressRibbon),
    );
    expect(headerRect.bottom - ribbonRect.top, closeTo(28 * _designScale, 1));
  });

  testWidgets('绑卡页引导文案优先用产品详情下发的 overwhelming.mobilization', (tester) async {
    const apiPrompt =
        'Confirm the account status and ensure the smooth arrival of cash.';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
      setUp: (container) async {
        container
            .read(sessionStoreProvider)
            .saveProductDetailBindCardPrompt(apiPrompt);
      },
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(apiPrompt), findsOneWidget);
    expect(find.textContaining('Check that your receiving'), findsNothing);
  });

  testWidgets('绑卡页后端不下发引导文案时用设计稿兜底引导段', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Check that your receiving\n'
        'account is active, belongs\n'
        'to you, and can receive\n'
        'funds before continuing.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('绑卡页切换打款方式 Tab 显示对应分组的字段', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Outstanding'));
    await tester.pumpAndSettle();

    expect(find.text('Select your recipient Bank'), findsOneWidget);
    expect(find.text('Bank Account'), findsOneWidget);
    expect(find.text('E-wallet Account'), findsNothing);
  });

  testWidgets('绑卡页渠道字段弹单选面板，维护中渠道给提示且 Done 回填', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bind-card-field-channelCode')));
    await tester.pumpAndSettle();

    expect(find.text('GCash e-wallet'), findsOneWidget);
    expect(find.text('PayMaya e-wallet'), findsOneWidget);
    expect(find.text('GrabPay e-wallet'), findsOneWidget);
    // 维护中的渠道仍可选中，只在名字下面补一行红字。
    expect(
      find.text('Under maintenance. Loans may be delayed'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('bind-card-option-PAYMAYA')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bind-card-option-done')));
    await tester.pumpAndSettle();

    // Done 后把渠道名回填到行上，占位文案消失。
    expect(find.text('PayMaya e-wallet'), findsOneWidget);
    expect(find.text('Please select'), findsNothing);
  });

  testWidgets('绑卡页输入框聚焦且为空时弹建议气泡，关闭后不再弹', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bind-card-field-firstName')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('bind-card-suggestion-firstName')),
      findsOneWidget,
    );
    expect(find.text('Anna'), findsOneWidget);
    // 关闭按钮用设计稿切图，不要在代码里重画。
    expect(_assetImage(AppAssets.bindCardSuggestionClose), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('bind-card-suggestion-close-firstName')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('bind-card-suggestion-firstName')),
      findsNothing,
    );
    // 已经填过的字段不会再冒气泡。
    expect(find.text('Anna'), findsNothing);
  });

  testWidgets('绑卡页账号不一致时不发请求', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    await _fillBindCardForm(tester, account: '1234567890', confirm: '098765');
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Account numbers do not match'), findsOneWidget);
    expect(certificationRepository.submitBindCardCalls, isEmpty);
  });

  testWidgets('绑卡页提交按下发 key 回传字段并继续下一步', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      productRepository: productRepository,
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    await _fillBindCardForm(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    final submission = certificationRepository.submitBindCardCalls.single;
    expect(submission.cardType, '1');
    // 页面按接口下发的 `crucians` 原样回传；改名发生在仓库层（见仓库单测）。
    expect(submission.fields[BindCardField.channelKey], 'PAYMAYA');
    expect(submission.fields['firstName'], 'Anna');
    expect(submission.fields['cardNo'], '1234567890');

    // 提交成功后再拉产品详情，走下一步认证。
    expect(productRepository.detailCalls, greaterThan(0));
    expect(find.byType(BindCardPage), findsNothing);
  });

  testWidgets('绑卡页提交返回 20000 时先做活体再补交一次', (tester) async {
    _mockCameraPermission(1);
    final certificationRepository = _StubCertificationRepository()
      ..submitBindCardCodes = const [20000, 0];
    final livenessGateway = _StubLivenessGateway();
    final productRepository = _StubProductRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
      livenessGateway: livenessGateway,
      productRepository: productRepository,
    );
    _openBindCardPage(tester, orderNo: 'ORDER-9');
    await tester.pumpAndSettle();

    await _fillBindCardForm(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // 第一次提交没有活体参数。
    expect(certificationRepository.submitBindCardCalls, hasLength(2));
    expect(certificationRepository.submitBindCardCalls.first.faceType, '');
    expect(certificationRepository.submitBindCardCalls.first.image, '');

    // 活体 token 用订单号取（绑卡类型 1），SDK 用下发的授权码拉起。
    expect(certificationRepository.faceTokenCalls, ['ORDER-9']);
    expect(livenessGateway.licenses, ['LICENSE-1']);

    // 补交带上活体结果与原字段。
    final retry = certificationRepository.submitBindCardCalls.last;
    expect(retry.faceType, '7');
    expect(retry.livenessId, 'LIVE-1');
    expect(retry.license, 'LICENSE-1');
    expect(retry.image, isNotEmpty);
    expect(retry.fields[BindCardField.channelKey], 'PAYMAYA');
    expect(retry.fields['firstName'], 'Anna');

    expect(productRepository.detailCalls, greaterThan(0));
  });

  testWidgets('绑卡页接口失败给错误态与重试入口', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    certificationRepository.bindCardFailure = const ApiException(
      type: ApiFailureType.business,
      message: 'Bind card unavailable',
      code: 500,
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Bind card unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Riverpod 3 默认会对失败的 provider 做指数退避重试，次数不可预期；
    // 只断言「点 Retry 会再发起一次请求」，重试成功后渲染出字段。
    final callsBeforeRetry = certificationRepository.bindCardInfoCalls.length;
    certificationRepository.bindCardFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(
      certificationRepository.bindCardInfoCalls.length,
      greaterThan(callsBeforeRetry),
    );
    await tester.pumpAndSettle();

    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('绑卡页接口请求中显示 Loading', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..bindCardDelay = const Duration(milliseconds: 300);
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openBindCardPage(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LoadingView), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LoadingView), findsNothing);
    expect(find.text('First name'), findsOneWidget);
  });

  testWidgets('绑卡页后端不下发分组时走空态而不是空表单', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    certificationRepository.bindCard = const BindCardData();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    _openBindCardPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('No payment methods available'), findsOneWidget);

    // 空表单不能提交。
    await tester.tap(find.text('Upload'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(certificationRepository.submitBindCardCalls, isEmpty);
  });

  test('绑卡信息解析分组 / 渠道选项与维护状态', () {
    final data = BindCardData.fromJson(const {
      ApiFields.bindCardTips: 'Check your account',
      ApiFields.bindCardBottomTips: 'Double-check all digits',
      ApiFields.bindCardGroups: [
        {
          ApiFields.bindCardGroupLabel: 'E-wallet',
          ApiFields.bindCardGroupType: '1',
          ApiFields.bindCardGroupFields: [
            {
              ApiFields.bindCardFieldTitle: 'Select your recipient E-wallet',
              ApiFields.bindCardFieldPlaceholder: 'Please select',
              ApiFields.bindCardFieldKey: 'channelCode',
              // 值映射给的是混淆名，也要认得。
              ApiFields.bindCardFieldControl: 'Obesity',
              ApiFields.bindCardFieldOptions: [
                {
                  ApiFields.bindCardOptionLabel: 'GCash e-wallet',
                  ApiFields.bindCardOptionValue: 'GCASH',
                  ApiFields.bindCardOptionLogo: 'https://x/g.png',
                  ApiFields.bindCardOptionStatus: 0,
                },
                {
                  ApiFields.bindCardOptionLabel: 'PayMaya e-wallet',
                  ApiFields.bindCardOptionValue: 'PAYMAYA',
                  ApiFields.bindCardOptionStatus: 1,
                },
              ],
            },
            {
              ApiFields.bindCardFieldTitle: 'First name',
              ApiFields.bindCardFieldKey: 'firstName',
              ApiFields.bindCardFieldControl: 'txt',
              ApiFields.bindCardFieldSuggested: ' Anna ',
            },
            // 没有 title / key 的脏字段直接丢掉。
            {ApiFields.bindCardFieldControl: 'txt'},
          ],
        },
        // 没有字段的分组不渲染成空 Tab。
        {
          ApiFields.bindCardGroupLabel: 'Empty',
          ApiFields.bindCardGroupType: '9',
          ApiFields.bindCardGroupFields: [],
        },
      ],
    });

    expect(data.prompt, 'Check your account');
    expect(data.bottomPrompt, 'Double-check all digits');
    expect(data.groups, hasLength(1));
    final group = data.groups.single;
    expect(group.label, 'E-wallet');
    expect(group.type, '1');
    expect(group.fields.map((field) => field.key), [
      'channelCode',
      'firstName',
    ]);

    final channel = group.fields.first;
    expect(channel.control, BindCardControl.selection);
    expect(channel.isSelectable, isTrue);
    // 维护中（`catchpenny == 0`）仍可选中，只是标不可用。
    expect(channel.options.first.available, isFalse);
    // 银行不下发 `catchpenny`，缺省按可用。
    expect(channel.options[1].available, isTrue);

    final name = group.fields[1];
    expect(name.control, BindCardControl.text);
    expect(name.suggestedValue, 'Anna');
  });

  test('绑卡信息没有下发分组时按空处理', () {
    // 低版本 / 未灰度用户：`aminate` 缺失或为空。
    expect(BindCardData.fromJson(const {}).isEmpty, isTrue);
    expect(
      BindCardData.fromJson(const {ApiFields.bindCardGroups: []}).isEmpty,
      isTrue,
    );
  });

  test('获取绑卡信息接口带产品 id 与业务混淆字段', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).getBindCardInfo(productId: '7');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.bindCardInfo);
    expect(params[ApiFields.productId], '7');
    expect(params[ApiFields.obfuscateBindCardInfo1], isNotEmpty);
    expect(params[ApiFields.obfuscateBindCardInfo2], isNotEmpty);
  });

  test('提交绑卡把 channelCode 改名 entertainer 并带上活体参数', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).submitBindCard(
      productId: '7',
      cardType: '1',
      fields: const {
        'channelCode': 'PAYMAYA',
        'firstName': 'Anna',
        'cardNo': '1234567890',
      },
      faceType: '7',
      livenessId: 'LIVE-1',
      image: 'ZmFrZQ==',
      license: 'LICENSE-1',
    );

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.submitBindCard);
    expect(params[ApiFields.bindCardSubmitProductId], '7');
    expect(params[ApiFields.bindCardSubmitType], '1');
    // 下发 key `channelCode` 在上送前换成 `entertainer`，原 key 不能出现。
    expect(params[ApiFields.bindCardSubmitChannel], 'PAYMAYA');
    expect(params.containsKey(BindCardField.channelKey), isFalse);
    expect(params['firstName'], 'Anna');
    expect(params[ApiFields.uploadFaceType], '7');
    expect(params[ApiFields.uploadLivenessId], 'LIVE-1');
    expect(params[ApiFields.uploadLivenessLicense], 'LICENSE-1');
    expect(params[ApiFields.uploadFileField], 'ZmFrZQ==');
    expect(params[ApiFields.obfuscateSubmitBindCard], isNotEmpty);
  });

  testWidgets('借款确认页拉账户列表并按蓝湖稿 04-01 渲染分节与底部 Upload', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    AppNavigator.push(
      AppRoutes.loanConfirm,
      arguments: const LoanConfirmPageArguments(
        productId: '7',
        orderNo: 'ORD-1',
      ),
    );
    await tester.pumpAndSettle();

    // 账户列表按产品 id 拉一次，页面不写死任何一条账户。
    expect(certificationRepository.userAccountsCalls, ['7']);

    // 导航标题与三个分节标题（设计稿 text_3 / text_4 / text_9 / text_12）。
    expect(find.byType(LoanConfirmPage), findsOneWidget);
    expect(find.text('Loan Confirmation'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('E-wallet'), findsOneWidget);
    expect(find.text('Cash Pickup'), findsOneWidget);

    // 银行 / 电子钱包是一行「Receipt Account + 账号」，现金网点是三列姓名。
    expect(find.text('BDO'), findsOneWidget);
    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('M Lhuillier'), findsOneWidget);
    expect(find.text('Receipt Account'), findsNWidgets(2));
    expect(find.text('5490163575561234'), findsNWidgets(2));
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Middle Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Oliver'), findsOneWidget);
    expect(find.text('Mark'), findsOneWidget);

    // 维护中的账户（`catchpenny == 0`）仍可选中，红色提示照设计稿展示。
    expect(
      find.text(
        'The bank is under maintenance. Loans may be delayed. '
        'Please wait or choose another option',
      ),
      findsOneWidget,
    );

    // 默认选中后端标了 `isMain` 的 Bank 那笔，其余两张是未选中态。
    expect(_assetImage(AppAssets.loanConfirmRadioChecked), findsOneWidget);
    expect(_assetImage(AppAssets.loanConfirmRadioUnchecked), findsNWidgets(2));

    // Add 整块按钮 / Upload 胶囊 / 返回键都是设计稿切图。
    expect(_assetImage(AppAssets.loanConfirmAddMethod), findsOneWidget);
    expect(_assetImage(AppAssets.idVerifyUploadButton), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);

    // 账户卡左右各留 16pt、宽 343（设计稿 section_3 / section_5 / section_6）。
    for (final id in ['555', '556', '557']) {
      final rect = tester.getRect(find.byKey(Key('loan-confirm-card-$id')));
      expect(rect.left, closeTo(AppSpacing.pageHorizontal * _designScale, 0.5));
      expect(rect.width, closeTo(343 * _designScale, 0.5));
    }

    // 分节顺序与下发顺序一致，不能由页面自己按名字重排。
    final bankTop = tester
        .getRect(find.byKey(const Key('loan-confirm-card-555')))
        .top;
    final ewalletTop = tester
        .getRect(find.byKey(const Key('loan-confirm-card-556')))
        .top;
    final cashTop = tester
        .getRect(find.byKey(const Key('loan-confirm-card-557')))
        .top;
    expect(bankTop, lessThan(ewalletTop));
    expect(ewalletTop, lessThan(cashTop));
  });

  testWidgets('借款确认页点另一张账户卡就切换选中态', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    AppNavigator.push(
      AppRoutes.loanConfirm,
      arguments: const LoanConfirmPageArguments(
        productId: '7',
        orderNo: 'ORD-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(_assetImage(AppAssets.loanConfirmRadioChecked), findsOneWidget);
    expect(_assetImage(AppAssets.loanConfirmRadioUnchecked), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('loan-confirm-card-556')));
    await tester.pumpAndSettle();

    // 单选：勾选圈跟着走，同一时刻只有一张卡是选中态。
    final checked = find.descendant(
      of: find.byKey(const Key('loan-confirm-card-556')),
      matching: _assetImage(AppAssets.loanConfirmRadioChecked),
    );
    expect(checked, findsOneWidget);
    expect(_assetImage(AppAssets.loanConfirmRadioChecked), findsOneWidget);
    expect(_assetImage(AppAssets.loanConfirmRadioUnchecked), findsNWidgets(2));
  });

  testWidgets('借款确认页 Upload 换绑成功后把订单详情地址回给调用方', (tester) async {
    final certificationRepository = _StubCertificationRepository();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    final popped = AppNavigator.push<LoanConfirmResult>(
      AppRoutes.loanConfirm,
      arguments: const LoanConfirmPageArguments(
        productId: '7',
        orderNo: 'ORD-1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 提交的是默认选中的 Bank 账户（`bindId`），订单号从页面入参带下来。
    expect(certificationRepository.changeBankCardCalls, [
      (orderNo: 'ORD-1', bindId: '555'),
    ]);
    // 页面自己换绑，但跳转留给调用方：pop 出订单详情页地址。
    final result = await popped;
    expect(result, isA<LoanConfirmAccountChanged>());
    expect(
      (result! as LoanConfirmAccountChanged).url,
      'https://h5.example.com/order/1',
    );
    expect(find.byType(LoanConfirmPage), findsNothing);
  });

  testWidgets('借款确认页账户列表失败时展示错误态并可重试', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..userAccountsFailure = const ApiException(
        type: ApiFailureType.business,
        message: 'Unable to load accounts',
        code: 1,
      );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    AppNavigator.push(
      AppRoutes.loanConfirm,
      arguments: const LoanConfirmPageArguments(
        productId: '7',
        orderNo: 'ORD-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Unable to load accounts'), findsOneWidget);
    // 列表没回来时 Upload 置灰，点不动。
    expect(certificationRepository.changeBankCardCalls, isEmpty);

    certificationRepository.userAccountsFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Riverpod 对失败的 Provider 会再排一次自动重试，加上手动 Retry，
    // 这里只断言「确实又拉了一次并且列表出来了」。
    expect(
      certificationRepository.userAccountsCalls.length,
      greaterThanOrEqualTo(2),
    );
    expect(find.text('BDO'), findsOneWidget);
  });

  testWidgets('借款确认页没有可选账户时自动把「去绑卡」回给调用方', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..userAccounts = const LoanConfirmData();
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );
    final popped = AppNavigator.push<LoanConfirmResult>(
      AppRoutes.loanConfirm,
      arguments: const LoanConfirmPageArguments(
        productId: '7',
        orderNo: 'ORD-1',
      ),
    );
    await tester.pumpAndSettle();

    // 一笔可选账户都没有时不再停在空态等用户点，自动回「要新增账户」，
    // 由调用方接着压绑卡页的改卡模式（口径对齐 peso_shield）。
    expect(await popped, isA<LoanConfirmAddPaymentMethod>());
    expect(find.byType(LoanConfirmPage), findsNothing);
  });

  testWidgets('借款确认页 Add other payment methods 把「去绑卡」回给调用方', (tester) async {
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    final popped = AppNavigator.push<LoanConfirmResult>(
      AppRoutes.loanConfirm,
      arguments: const LoanConfirmPageArguments(
        productId: '7',
        orderNo: 'ORD-1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('loan-confirm-add-method')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // 页面不自己跳绑卡页，只把「要新增账户」回给调用方（两个入口共用同一页）。
    expect(await popped, isA<LoanConfirmAddPaymentMethod>());
    expect(find.byType(LoanConfirmPage), findsNothing);
  });

  testWidgets('认证全部完成后换确认用款 H5 地址并打开 WebView', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-1'),
        // 认证全部完成：没有下一步认证项 → 换地址进确认用款 WebView。
        nextStep: ProductNextStep(),
      ),
    );
    await _pumpApp(
      tester,
      repository: _StubAppRepository(
        home: const HomeData(
          banners: [],
          orders: [],
          notices: [],
          product: _productCard,
        ),
      ),
      productRepository: productRepository,
      certificationRepository: _StubCertificationRepository(),
      setUp: (container) async {
        await container
            .read(userSessionProvider.notifier)
            .setSession(token: 'token', userId: '1', phone: '855123456');
      },
    );

    await tester.tap(find.text('180 Days'));
    // WebView 首帧自带 loading 指示器，pumpAndSettle 不会收敛，按帧推进即可。
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 认证做完后不再进原生账号列表，而是换地址直接打开订单 H5。
    expect(productRepository.pushUrlCalls, 1);
    expect(find.byType(WebViewPage), findsOneWidget);
    expect(find.byType(LoanConfirmPage), findsNothing);
  });

  testWidgets('绑卡页改卡模式提交成功后换绑并 pop 订单详情地址', (tester) async {
    final certificationRepository = _StubCertificationRepository()
      ..changeBankCardUrl = 'https://h5.example.com/order/7';
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: certificationRepository,
    );

    final popped = AppNavigator.push<String>(
      AppRoutes.bindCard,
      arguments: const BindCardPageArguments(
        productId: '7',
        orderNo: 'ORD-1',
        isAccountChange: true,
      ),
    );
    await tester.pumpAndSettle();

    await _fillBindCardForm(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // 改卡模式不发下一步认证，而是拿提交返回的绑卡 id 直接换绑。
    expect(certificationRepository.submitBindCardCalls, hasLength(1));
    expect(certificationRepository.changeBankCardCalls, [
      (orderNo: 'ORD-1', bindId: '123'),
    ]);
    expect(await popped, 'https://h5.example.com/order/7');
    expect(find.byType(BindCardPage), findsNothing);
  });

  test('WebView 桥 changeAccount 缺参数失败，带参数时回调原生换绑链路', () async {
    final calls = <(String, String)>[];
    final coordinator = WebViewActionCoordinator(
      changeAccount: ({required productId, required orderNo}) async {
        calls.add((productId, orderNo));
      },
    );

    final missing = await coordinator.dispatch(
      const WebViewRequest(
        action: WebViewActions.changeAccount,
        callbackId: '1',
        data: {},
        rawData: '',
      ),
    );
    expect(missing.code, isNot(0));
    expect(calls, isEmpty);

    final ok = await coordinator.dispatch(
      const WebViewRequest(
        action: WebViewActions.changeAccount,
        callbackId: '2',
        data: {WebViewFields.productId: '7', WebViewFields.orderNo: 'ORD-1'},
        rawData: '',
      ),
    );
    expect(ok.code, 0);
    expect(calls, [('7', 'ORD-1')]);
  });

  test('用户账户列表解析分组 / 排版 / 维护状态与默认选中', () {
    final data = LoanConfirmData.fromJson(const {
      ApiFields.loanAccountGroups: [
        {
          ApiFields.loanAccountGroupTitle: 'Bank',
          // 文档 `cardType`：2 银行。
          ApiFields.loanAccountGroupType: 2,
          ApiFields.loanAccountItems: [
            {
              ApiFields.loanAccountBindId: 555,
              ApiFields.loanAccountName: 'BDO',
              ApiFields.loanAccountStatus: 0,
              ApiFields.loanAccountIsMain: 1,
              ApiFields.loanAccountNumber: '5490163575561234',
              ApiFields.loanAccountLogo: 'https://x/bdo.png',
            },
            {
              ApiFields.loanAccountBindId: 556,
              ApiFields.loanAccountName: 'BPI',
              ApiFields.loanAccountStatus: 1,
            },
          ],
        },
        {
          // 现金网点分节：`cardType == 3` 就按三列姓名排版，
          // 分节名不带 `cash` 也能识别；姓名挂在 `telecomm` 里。
          ApiFields.loanAccountGroupTitle: 'Convenience Store',
          ApiFields.loanAccountGroupType: 3,
          ApiFields.loanAccountItems: [
            {
              ApiFields.loanAccountBindId: 557,
              ApiFields.loanAccountName: 'M Lhuillier',
              ApiFields.loanAccountHolder: {
                ApiFields.loanAccountFirstName: 'Anna',
                ApiFields.loanAccountMiddleName: 'Oliver',
                ApiFields.loanAccountLastName: 'Mark',
              },
            },
          ],
        },
        {
          // 老接口没下发 `cardType` 时退回分节名判定。
          ApiFields.loanAccountGroupTitle: 'Cash Pickup',
          ApiFields.loanAccountItems: [
            {
              ApiFields.loanAccountBindId: 558,
              ApiFields.loanAccountName: 'Cebuana',
              ApiFields.loanAccountHolder: {
                ApiFields.loanAccountFirstName: 'Ana',
                ApiFields.loanAccountMiddleName: 'Marie',
                ApiFields.loanAccountLastName: 'Cruz',
              },
            },
          ],
        },
        // 没有任何账户的分组不渲染。
        {
          ApiFields.loanAccountGroupTitle: 'Empty',
          ApiFields.loanAccountGroupType: 1,
          ApiFields.loanAccountItems: [],
        },
      ],
    });

    expect(data.groups, hasLength(3));
    final bank = data.groups.first.accounts;
    expect(bank, hasLength(2));
    expect(bank.first.kind, LoanAccountKind.receiptAccount);
    expect(bank.first.receiptAccount, '5490163575561234');
    // `catchpenny == 0` 是维护中，但仍能选中，页面只补提示。
    expect(bank.first.available, isFalse);
    expect(bank.first.underMaintenance, isTrue);
    expect(bank[1].available, isTrue);
    expect(bank[1].underMaintenance, isFalse);
    // 默认选中后端标了 `isMain` 的那笔。
    expect(data.selectedId, '555');
    expect(data.isEmpty, isFalse);

    // `cardType == 3` 驱动排版，不依赖分节名里的 `cash`。
    final cashByType = data.groups[1].accounts.single;
    expect(cashByType.kind, LoanAccountKind.cashPickup);
    expect(cashByType.firstName, 'Anna');
    expect(cashByType.middleName, 'Oliver');
    expect(cashByType.lastName, 'Mark');

    // `cardType` 缺失时退回分节名。
    final cashByTitle = data.groups[2].accounts.single;
    expect(cashByTitle.kind, LoanAccountKind.cashPickup);
    expect(cashByTitle.firstName, 'Ana');
  });

  test('用户账户列表没有下发分组时按空处理', () {
    expect(LoanConfirmData.fromJson(const {}).isEmpty, isTrue);
    expect(
      LoanConfirmData.fromJson(const {ApiFields.loanAccountGroups: []}).isEmpty,
      isTrue,
    );
  });

  test('用户账户列表接口带产品 id 与业务混淆字段', () async {
    final client = _RecordingClient();
    await CertificationRepository(client).getUserAccounts(productId: '7');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.userAccounts);
    expect(params[ApiFields.productId], '7');
    expect(params[ApiFields.obfuscateLoanAccounts1], isNotEmpty);
    expect(params[ApiFields.obfuscateLoanAccounts2], isNotEmpty);
  });

  test('更换银行卡接口带订单号 / 绑卡 id 与混淆字段并解析跳转地址', () async {
    final client = _PayloadRecordingClient({
      ApiFields.changeBankCardRedirectUrl: 'https://h5.example.com/order/1',
    });
    final response = await CertificationRepository(client)
        .changeBankCard(orderNo: 'ORD-1', bindId: '555');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.changeBankCard);
    expect(params[ApiFields.changeBankCardOrderNo], 'ORD-1');
    expect(params[ApiFields.changeBankCardBindId], '555');
    expect(params[ApiFields.obfuscateChangeBankCard], isNotEmpty);
    expect(response.data, 'https://h5.example.com/order/1');
  });

  test('原卡重试确认订单接口只带订单号并解析订单详情地址', () async {
    final client = _PayloadRecordingClient({
      ApiFields.retryConfirmJumpUrl: 'https://h5.example.com/order/9',
    });
    final response = await CertificationRepository(client)
        .retryOrderConfirm(orderNo: 'ORD-9');

    final (path, params) = client.calls.single;
    expect(path, ApiEndpoints.orderRetryConfirm);
    expect(params[ApiFields.retryConfirmOrderNo], 'ORD-9');
    expect(response.data, 'https://h5.example.com/order/9');
  });

  // 风控埋点（`POST /outsulk/mesometral`）的 `pirate` 必须回传产品详情下发的订单号，
  // 和 App 启动流程一样，用真实的 [ReportService] 走一遍「页面 → 服务 → 仓库」。
  testWidgets('证件选择页埋点回传产品详情的订单号（pirate）', (tester) async {
    final reportClient = _RecordingClient();
    _useRecordingReportService(reportClient);
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    AppNavigator.push(
      AppRoutes.idVerification,
      arguments: const IdVerificationPageArguments(
        productId: '7',
        orderNo: 'ORDER-9',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PRC'));
    await tester.pumpAndSettle();

    final riskCall = reportClient.calls.firstWhere(
      (call) => call.$1 == ApiEndpoints.reportRisk,
    );
    expect(riskCall.$2[ApiFields.riskOrderNo], 'ORDER-9');
    expect(riskCall.$2[ApiFields.riskProductId], '7');
    expect(riskCall.$2[ApiFields.riskSceneType], '2');
  });

  testWidgets('证件信息确认页埋点回传产品详情的订单号（pirate）', (tester) async {
    final reportClient = _RecordingClient();
    _useRecordingReportService(reportClient);
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
    );
    _openIdConfirmPage(tester, orderNo: 'ORDER-9');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    final riskCall = reportClient.calls.firstWhere(
      (call) => call.$1 == ApiEndpoints.reportRisk,
    );
    expect(riskCall.$2[ApiFields.riskOrderNo], 'ORDER-9');
    expect(riskCall.$2[ApiFields.riskSceneType], '3');
  });

  testWidgets('紧急联系人页埋点回传产品详情的订单号（pirate）', (tester) async {
    final reportClient = _RecordingClient();
    _useRecordingReportService(reportClient);
    await _pumpApp(
      tester,
      repository: _StubAppRepository(),
      certificationRepository: _StubCertificationRepository(),
      productRepository: _StubProductRepository(),
    );
    _openEmergencyContactPage(tester, orderNo: 'ORDER-9');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    final riskCall = reportClient.calls.firstWhere(
      (call) => call.$1 == ApiEndpoints.reportRisk,
    );
    expect(riskCall.$2[ApiFields.riskOrderNo], 'ORDER-9');
    expect(riskCall.$2[ApiFields.riskSceneType], '7');
  });
}
