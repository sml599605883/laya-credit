import 'package:encrypt/encrypt.dart';

/// 报文字段级 AES-CBC 加解密。
///
/// 目前只有「设备信息上报」用到：接口文档 `6.data-report.html` 要求把整段设备
/// 报文加密后放进 `connectedly`，key / iv 见 [ApiEnvironment]（aesKey / aesIv）。
class ApiCrypto {
  ApiCrypto({required String key, required String iv})
    : _key = Key.fromUtf8(key),
      _iv = IV.fromUtf8(iv);

  final Key _key;
  final IV _iv;

  String encryptText(String plainText) {
    return Encrypter(AES(_key, mode: AESMode.cbc))
        .encrypt(plainText, iv: _iv)
        .base64;
  }

  String decryptText(String cipherText) {
    return Encrypter(AES(_key, mode: AESMode.cbc))
        .decrypt64(cipherText, iv: _iv);
  }
}
