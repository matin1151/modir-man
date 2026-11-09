import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class BackupCodec {
  static const iterations = 210000;
  final algorithm = AesGcm.with256bits();
  List<int> random(int length) {
    final r = Random.secure();
    return List<int>.generate(length, (_) => r.nextInt(256));
  }
  Future<SecretKey> key(String password, List<int> salt, int rounds) =>
    Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: rounds, bits: 256)
      .deriveKeyFromPassword(password: password, nonce: salt);
  Future<Uint8List> encrypt(Map<String, dynamic> data, String password) async {
    if (password.length < 12) throw const FormatException('گذرواژه باید دست‌کم ۱۲ نویسه باشد');
    final salt = random(16), nonce = random(12);
    final secret = await key(password, salt, iterations);
    final box = await algorithm.encrypt(utf8.encode(jsonEncode(data)), secretKey: secret, nonce: nonce);
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 'modir-man-backup', 'version': 1, 'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations, 'salt': base64Encode(salt), 'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText), 'mac': base64Encode(box.mac.bytes),
    })));
  }
  Future<Map<String, dynamic>> decrypt(Uint8List bytes, String password) async {
    if (bytes.length > 20 * 1024 * 1024) throw const FormatException('فایل پشتیبان بیش از اندازه بزرگ است');
    try {
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (envelope['format'] != 'modir-man-backup' || envelope['version'] != 1 ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' || envelope['iterations'] != iterations) {
        throw const FormatException('نسخه یا قالب پشتیبان پشتیبانی نمی‌شود');
      }
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      if (salt.length != 16 || nonce.length != 12 || mac.length != 16) throw const FormatException('پشتیبان نامعتبر است');
      final secret = await key(password, salt, iterations);
      final plain = await algorithm.decrypt(
        SecretBox(base64Decode(envelope['ciphertext'] as String), nonce: nonce, mac: Mac(mac)),
        secretKey: secret);
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('گذرواژه نادرست است یا فایل آسیب دیده است');
    }
  }
}
