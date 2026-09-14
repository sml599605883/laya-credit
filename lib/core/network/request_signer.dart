import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 请求签名：按参数名排序后拼成 `key+value`，再做 HMAC-SHA256。
///
/// 算法必须与后端保持一致，改这里之前先确认后端实现。
class RequestSigner {
  const RequestSigner(this.secret);

  final String secret;

  String sign(Map<String, Object?> params) {
    final sortedKeys = params.keys.toList()..sort();
    final source = sortedKeys.map((key) => '$key${params[key] ?? ''}').join();
    return Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(source)).toString();
  }
}
