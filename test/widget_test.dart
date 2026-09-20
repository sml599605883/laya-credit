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
import 'package:laya_credit/core/network/http_client.dart';
import 'package:laya_credit/core/network/network_config.dart';
import 'package:laya_credit/data/models/face_token_result.dart';
import 'package:laya_credit/data/models/home_data.dart';
import 'package:laya_credit/data/models/id_verification_data.dart';
import 'package:laya_credit/data/models/identity_recognition.dart';
import 'package:laya_credit/data/models/login_result.dart';
import 'package:laya_credit/data/models/personal_info_data.dart';
import 'package:laya_credit/data/models/sms_channel_options.dart';
import 'package:laya_credit/data/repositories/app_repository.dart';
import 'package:laya_credit/data/repositories/auth_repository.dart';
import 'package:laya_credit/data/repositories/certification_repository.dart';
import 'package:laya_credit/data/repositories/product_repository.dart';
import 'package:laya_credit/data/models/product_apply_result.dart';
import 'package:laya_credit/data/models/product_detail.dart';
import 'package:laya_credit/theme/app_assets.dart';
import 'package:laya_credit/main.dart';
import 'package:laya_credit/core/media/identity_photo.dart';
import 'package:laya_credit/core/navigation/navigation.dart';
import 'package:laya_credit/pages/face_verification_page.dart';
import 'package:laya_credit/pages/home_page.dart';
import 'package:laya_credit/pages/id_confirm_page.dart';
import 'package:laya_credit/pages/id_upload_page.dart';
import 'package:laya_credit/pages/id_verification_page.dart';
import 'package:laya_credit/pages/login_page.dart';
import 'package:laya_credit/pages/personal_info_page.dart';
import 'package:laya_credit/pages/work_information_page.dart';
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

  @override
  Future<ApiResponse<HomeData>> getHomePage() async {
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

/// 登录/发码仓库桩：只记录调用，不发网络。
class _StubAuthRepository extends AuthRepository {
  _StubAuthRepository({this.failure, this.delay}) : super(_placeholderClient());

  final Object? failure;

  /// 模拟慢请求，用来观察请求进行中的 UI。
  final Duration? delay;

  int sendCodeCalls = 0;
  int loginCalls = 0;

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

  /// (productId, apiRemind)
  final List<(String, int)> applyCalls = [];
  int detailCalls = 0;

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
}) {
  AppNavigator.push(
    AppRoutes.idConfirm,
    arguments: IdConfirmPageArguments(
      productId: productId,
      cardType: cardType,
      recognition: recognition,
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
void _openPersonalInfoPage(WidgetTester tester, {String productId = '7'}) {
  AppNavigator.push(
    AppRoutes.personalInfo,
    arguments: PersonalInfoPageArguments(productId: productId),
  );
}

/// 直接打开工作信息认证页（走和产品申请流程一样的路由与入参）。
void _openWorkInfoPage(WidgetTester tester, {String productId = '7'}) {
  AppNavigator.push(
    AppRoutes.workInfo,
    arguments: WorkInfoPageArguments(productId: productId),
  );
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
      if (identityPhotoService != null)
        identityPhotoServiceProvider.overrideWithValue(identityPhotoService),
      if (livenessGateway != null)
        livenessGatewayProvider.overrideWithValue(livenessGateway),
    ],
  );
  addTearDown(container.dispose);

  if (setUp != null) await setUp(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}

/// 假装弹出的键盘高度（pt）。
const _keyboard = 330.0;

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

  testWidgets('未登录时点击受保护的 Tab 会跳转登录页', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-mine')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter mobile number'), findsOneWidget);
    expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
  });

  testWidgets('未登录时统计 Tab 同样需要登录', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());

    await tester.tap(find.byKey(const Key('tab-stats')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter mobile number'), findsOneWidget);
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
    expect(params[ApiFields.applyModuleId], '1001');
    expect(params[ApiFields.applyPosition], '1000');
    expect(params[ApiFields.applySubModuleId], '1000');
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

  testWidgets('准入成功后拉产品详情并按下一步认证项提示', (tester) async {
    final productRepository = _StubProductRepository(
      detail: const ProductDetail(
        resultCode: 200,
        basicInfo: ProductBasicInfo(orderNo: 'ORDER-1'),
        nextStep: ProductNextStep(
          taskType: 'Bespattered',
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

  testWidgets('证件信息确认页按蓝湖稿 03-01 渲染证件照、三行识别结果与 Upload 按钮', (tester) async {
    await _pumpApp(tester, repository: _StubAppRepository());
    _openIdConfirmPage(tester);
    await tester.pumpAndSettle();

    // 头图 / 返回按钮 / 证件照 / 按钮底图都是设计稿切图，不要在代码里重画。
    expect(_assetImage(AppAssets.idVerifyHeaderBlank), findsOneWidget);
    expect(_assetImage(AppAssets.back), findsOneWidget);
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
}
