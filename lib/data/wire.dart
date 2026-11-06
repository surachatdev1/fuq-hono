import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import '../core/models.dart';

class WireCodec {
  WireCodec(Map<String, dynamic> material) {
    if (material['protocol_version'] != 'hono-22.9-323') {
      throw const AppFailure('ไม่รองรับรุ่นโปรโตคอลนี้');
    }
    final key = utf8.encode(material['key'] as String);
    final iv = utf8.encode(material['iv'] as String);
    if (key.length != 16 || iv.length != 16) throw const AppFailure('โปรโตคอลไม่ครบ');
    _aes = Encrypter(AES(Key(key), mode: AESMode.cbc, padding: null));
    _iv = IV(iv);
    bootstrap = material['bootstrap_key'] as String;
  }
  late final Encrypter _aes;
  late final IV _iv;
  late final String bootstrap;
  String hex(String text) {
    // Match original Android UTF-16 character-count space padding exactly.
    final bytes = utf8.encode(text + ' ' * (16 - text.length % 16));
    if (bytes.length % 16 != 0) throw const AppFailure('ข้อความไม่รองรับโปรโตคอลเดิม');
    return _aes.encryptBytes(bytes, iv: _iv).base16.toLowerCase();
  }
  String encode(String text, String php) {
    if (php != '1') return hex(text);
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    String pad() => List.generate(3, (_) => chars[random.nextInt(chars.length)]).join();
    return '${pad()}${base64Encode(utf8.encode(text))}${pad()}';
  }
  static String query(String endpoint, Map<String, String> fields) =>
      '$endpoint?${fields.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';
}
