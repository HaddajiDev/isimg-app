import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;

class Svc5Crypto {
  const Svc5Crypto._();

  static enc.Encrypter _encrypter(String password) {
    final digest = crypto.sha256.convert(ascii.encode(password)).bytes;
    final key = enc.Key(Uint8List.fromList(digest));
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }

  static final enc.IV _zeroIv = enc.IV(Uint8List(16));

  static String encrypt(String plain, String password) =>
      _encrypter(password).encrypt(plain, iv: _zeroIv).base64;

  static String? tryDecrypt(String cipher, String password) {
    final trimmed = cipher.trim();
    if (trimmed.isEmpty) return null;
    try {
      return _encrypter(password).decrypt(enc.Encrypted.fromBase64(trimmed), iv: _zeroIv);
    } catch (_) {
      return null;
    }
  }
}
