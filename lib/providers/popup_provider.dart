import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_dialog.dart';
import 'repository_provider.dart';

/// 首页 / 个人中心弹窗场景（接口文档「弹窗」的 `creaturely`）。
abstract final class AppPopupScene {
  /// 首页。
  static const home = 1;

  /// 个人中心。
  static const mine = 2;
}

/// 首页 / 个人中心弹窗（`GET /outsulk/agatize`）。
///
/// 首页场景在首页数据刷新时请求，个人中心场景在切到个人中心 Tab 时请求。
/// 请求结果写回 state，由 UI 层（`RootTabPage`）通过 `ref.listen`
/// 消费「有新弹窗」这个事件再决定怎么展示；请求失败只记日志，不影响页面。
final appPopupProvider = NotifierProvider<AppPopupNotifier, AppDialog?>(
  AppPopupNotifier.new,
);

class AppPopupNotifier extends Notifier<AppDialog?> {
  @override
  AppDialog? build() => null;

  /// 请求指定场景的弹窗。失败只记日志，不向上抛。
  Future<void> request(int scene) async {
    try {
      final repository = await ref.read(appRepositoryProvider.future);
      final response = await repository.getDialog(scene: scene);
      if (!response.isSuccess) {
        debugPrint(
          '[Popup] scene=$scene 请求失败: ${response.code} ${response.message}',
        );
        return;
      }
      final dialog = response.data;
      debugPrint(
        '[Popup] scene=$scene type=${dialog.type} version=${dialog.version} '
        'message=${dialog.message} url=${dialog.targetUrl}',
      );
      state = dialog;
    } catch (error) {
      debugPrint('[Popup] scene=$scene 异常: $error');
    }
  }
}
