import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 把 Dio 的底层连接指向抓包代理。
///
/// `findProxy` 是 `dart:io` 唯一的代理入口，全局代理设置对它无效，
/// 必须在这里显式返回 `PROXY host:port`。
class ProxyConfigurer {
  const ProxyConfigurer._();

  static void configure(
    Dio dio, {
    required String host,
    required int port,
    bool allowInsecure = false,
  }) {
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) => 'PROXY $host:$port';

        if (allowInsecure) {
          client.badCertificateCallback = (cert, host, port) => true;
        }

        return client;
      };
    }
  }
}
