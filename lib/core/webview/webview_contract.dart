import 'dart:convert';

/// WebView JS 桥接契约。
///
/// 结构对齐 dali_cash 的 `dali_webview_contract.dart`：
/// 原生注册一个 JS handler，H5 通过 `window.<handler>.postMessage(...)` 发起
/// action，原生 dispatch 后（可选）回调 `window.<handler>.handleMessage(...)`。
///
/// 取值来自 Web 端 `WebViewBridge`（`bridge.send(action, data[, callback])`），
/// 见前端 `uploadRiskLoan` / `openUrl` / `getPublicParams` 等导出函数。
abstract final class WebViewContract {
  /// 原生注册、H5 调用的 JS handler 名。
  static const handler = 'ph_laya_credit_ios';
}

/// H5 下发的 action 名。
abstract final class WebViewActions {
  /// 风控数据上报。
  static const uploadRisk = 'laya_credit_rqHm8jp3XV4JDoI';

  /// 跳转 Google Play（iOS 忽略）。
  static const openGooglePlay = 'laya_credit_lgr5GnQLGtwyPTU';

  /// 打开链接。
  static const openUrl = 'laya_credit_LSfHZrCEnU8pobX';

  /// 关闭当前页。
  static const close = 'laya_credit_DPs6pJccZSPgIRr';

  /// 回到 App 首页。
  static const home = 'laya_credit_3hmzdF0IOBcBQCB';

  /// 请求 App Store 评分。
  static const grade = 'laya_credit_YTIqoTjNxGdF8Fz';

  /// 放款重试弹窗。
  static const retryOrder = 'laya_credit_3ooUbdYzl5XA9WD';

  /// 更换放款账户。
  static const changeAccount = 'laya_credit_5vBBE3uRdizNLo7';

  /// 取签名后的公共参数。
  static const publicParams = 'laya_credit_IoIRBP06E3v1dGA';
}

/// H5 下发的业务字段名。
abstract final class WebViewFields {
  /// 产品 id。
  static const productId = 'podostemon';

  /// 订单号。
  static const orderNo = 'pirate';
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
