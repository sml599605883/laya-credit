import 'dart:math';

/// 混淆字段生成。
///
/// 文档里带「混淆字段」注释的参数没有业务含义，仅用于干扰，
/// 每次请求随机生成一个新值即可。
abstract final class ObfuscationHelper {
  static final _random = Random();

  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// 生成一个 16 位随机串。
  static String randomParam() {
    return List.generate(
      16,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }
}
