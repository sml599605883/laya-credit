import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 根 Tab 当前选中的页面。
///
/// 放在 Provider 中是为了让登录完成等导航事件能把底部 Tab 明确切回 Home，
/// 而不是只回到 RootTabPage 外壳后保留登录前的 Progress / Mine。
final rootTabIndexProvider = NotifierProvider<RootTabIndexNotifier, int>(
  RootTabIndexNotifier.new,
);

class RootTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    if (state != index) state = index;
  }

  void selectHome() => select(0);
}
