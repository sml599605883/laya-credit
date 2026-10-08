import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/navigation.dart';

/// 打开外部链接的方式，可注入以便测试。
typedef ExternalUriOpener = Future<bool> Function(Uri uri);

/// 打开弹窗里的跳转地址（升级下载链接 / 营销落地页）。
///
/// 优先交给系统浏览器，打不开再退回内置 WebView；地址非法时只记日志。
Future<void> openPopupTarget(
  String rawUrl, {
  ExternalUriOpener? externalOpener,
}) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    debugPrint('[Popup] 跳转地址非法: $rawUrl');
    return;
  }

  final opened = await _launchExternal(uri, externalOpener);
  if (opened) return;
  AppNavigator.toWebView<void>(url: uri.toString());
}

Future<bool> _launchExternal(Uri uri, ExternalUriOpener? externalOpener) async {
  if (externalOpener != null) {
    try {
      return await externalOpener(uri);
    } catch (error) {
      debugPrint('[Popup] 打开外部链接失败: $error');
      return false;
    }
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('[Popup] 打开外部链接失败: $error');
    return false;
  }
}
