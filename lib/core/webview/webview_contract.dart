import 'dart:convert';

/// WebView JS 桥接契约。
///
/// 结构对齐 dali_cash 的 `dali_webview_contract.dart`：
/// 原生注册一个 JS handler，H5 通过 `window.<handler>.postMessage(...)` 发起
/// action，原生 dispatch 后（可选）回调 `window.<handler>.handleMessage(...)`。
///
/// ⚠️ 混淆串占位：本项目接口文档尚未下发 handler / action / 字段的混淆命名，
/// 下面先用可读占位串，保证链路可跑、可测。拿到文档后**只改这些常量**即可，
/// 各 action 对应的交互语义与 dali_cash 完全一致（括号内为 dali 的取值）。
abstract final class WebViewContract {
  /// 原生注册、H5 调用的 JS handler 名（dali: `ph_dali_cash_ios`）。
  static const handler = 'ph_laya_credit_ios';
}

/// H5 下发的 action 名。
///
/// TODO(混淆串): 待接口文档下发后替换；替换时不要改动常量名与顺序。
abstract final class WebViewActions {
  /// 风控数据上报（dali: `dali_cash_RbGtlAKg2Hsx7x5`）。
  static const uploadRisk = 'laya_credit_uploadRisk';

  /// 跳转 Google Play（iOS 忽略，dali: `dali_cash_HjU4mCaWf9VcOI6`）。
  static const openGooglePlay = 'laya_credit_openGooglePlay';

  /// 打开链接（dali: `dali_cash_dudAaHWAtJmjS2T`）。
  static const openUrl = 'laya_credit_openUrl';

  /// 关闭当前页（dali: `dali_cash_jWPoDsrg054lhUC`）。
  static const close = 'laya_credit_close';

  /// 回到首页（dali: `dali_cash_Ax2ivGQo70e2KIR`）。
  static const home = 'laya_credit_home';

  /// 请求 App Store 评分（dali: `dali_cash_L9ePULguB5v2O84`）。
  static const grade = 'laya_credit_grade';

  /// 重新绑卡 / 重试订单（dali: `dali_cash_U5sqmkouwbyYVRT`）。
  static const retryOrder = 'laya_credit_retryOrder';

  /// 更换打款账户（dali: `dali_cash_dzaSV8NeJkdm0di`）。
  static const changeAccount = 'laya_credit_changeAccount';

  /// 取签名后的公共参数（dali: `dali_cash_YDtfWHIcQnY8cfk`）。
  static const publicParams = 'laya_credit_publicParams';
}

/// H5 下发的业务字段名。
///
/// TODO(混淆串): 待接口文档下发后替换（括号内为 dali 的取值）。
abstract final class WebViewFields {
  /// 产品 id（dali: `thunderstruck`）。
  static const productId = 'productId';

  /// 订单号（dali: `saggards`）。
  static const orderNo = 'orderNo';

  /// Google Play 包名（dali: `appPkg`）。
  static const appPkg = 'appPkg';

  /// 跳转链接（dali: `url`）。
  static const url = 'url';

  /// 账户列表返回体（dali: `clingiest`）。
  static const accountList = 'accountList';

  /// 重试订单返回的跳转地址（dali: `misericorde`）。
  static const retryUrl = 'retryUrl';
}

/// H5 发来的桥接请求。
class WebViewRequest {
  const WebViewRequest({
    required this.action,
    required this.callbackId,
    required this.data,
    required this.rawData,
  });

  /// 解析原生收到的 JS 参数。允许 JSON 字符串信封、Map、裸字符串，
  /// 任何格式异常都退化成「空 action」，绝不抛异常（H5 数据不可信）。
  factory WebViewRequest.decode(Object? message) {
    final source = _asMap(_tryDecode(message));
    final rawData = source['data'] ?? source['payload'] ?? source['params'];
    return WebViewRequest(
      action: _firstString(source, const ['action', 'name']),
      callbackId: _firstString(source, const ['callbackId', 'callback', 'id']),
      data: _asMap(_tryDecode(rawData)),
      rawData: rawData,
    );
  }

  final String action;
  final String callbackId;
  final Map<String, dynamic> data;
  final Object? rawData;

  /// H5 是否要求回调（给了 callbackId 才回）。
  bool get expectsCallback => callbackId.isNotEmpty;

  /// 原始数据的字符串形态：`publicParams` 这类 action 直接把裸串当入参。
  String get rawDataString {
    final value = rawData;
    if (value is String) return value.trim();
    if (value == null) return '';
    try {
      return jsonEncode(value).trim();
    } catch (_) {
      return '';
    }
  }

  static String _firstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static Object? _tryDecode(Object? value) {
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }
}

/// 桥接响应。固定 `{code, message, data}`。
class WebViewResult {
  const WebViewResult({required this.code, required this.message, this.data});

  const WebViewResult.success([Object? data])
    : this(code: 0, message: 'success', data: data);

  const WebViewResult.failure(String message, {int code = -1})
    : this(code: code, message: message);

  final int code;
  final String message;
  final Object? data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'message': message,
    'data': data ?? const <String, dynamic>{},
  };
}
