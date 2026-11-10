import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/models.dart';

class MapPin {
  const MapPin(this.lat, this.lng, this.viewport);
  final double lat, lng;
  final bool viewport;
}

class Maps {
  static const hosts = {
    'google.com',
    'www.google.com',
    'maps.google.com',
    'google.co.th',
    'www.google.co.th',
    'maps.google.co.th',
    'maps.app.goo.gl',
    'goo.gl',
  };
  static Uri validate(String input) {
    final links = RegExp('https://[^\\s<>"\']+').allMatches(input).toList();
    if (links.length != 1) {
      throw const AppFailure('วางลิงก์ Google Maps ครั้งละหนึ่งลิงก์');
    }
    final u = Uri.tryParse(links.first.group(0)!);
    if (u == null ||
        u.scheme != 'https' ||
        u.port != 443 ||
        u.userInfo.isNotEmpty ||
        !hosts.contains(u.host) ||
        !(u.host == 'maps.app.goo.gl' ||
            u.host.startsWith('maps.google.') ||
            u.path == '/maps' ||
            u.path.startsWith('/maps/'))) {
      throw const AppFailure('ใช้ลิงก์ HTTPS จาก Google Maps เท่านั้น');
    }
    return u;
  }

  static MapPin parse(Uri u) {
    MapPin point(String a, String b, bool viewport) {
      final lat = double.tryParse(a), lng = double.tryParse(b);
      if (lat == null ||
          lng == null ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat.abs() > 90 ||
          lng.abs() > 180) {
        throw const AppFailure('พิกัดไม่ถูกต้อง');
      }
      return MapPin(lat, lng, viewport);
    }

    final pair = RegExp(
      r'^\s*([+-]?\d+(?:\.\d+)?)\s*,\s*([+-]?\d+(?:\.\d+)?)\s*$',
    );
    for (final key in ['query', 'q', 'destination']) {
      final m = pair.firstMatch(u.queryParameters[key] ?? '');
      if (m != null) return point(m[1]!, m[2]!, false);
    }
    final text = Uri.decodeFull('${u.path}?${u.query}');
    final markers = RegExp(
      r'!3d([+-]?\d+(?:\.\d+)?)!4d([+-]?\d+(?:\.\d+)?)',
    ).allMatches(text);
    if (markers.isNotEmpty) {
      final m = markers.last;
      return point(m[1]!, m[2]!, false);
    }
    final ll = pair.firstMatch(u.queryParameters['ll'] ?? '');
    if (ll != null) return point(ll[1]!, ll[2]!, true);
    final center = RegExp(
      r'@([+-]?\d+(?:\.\d+)?),([+-]?\d+(?:\.\d+)?)(?:,|/|$)',
    ).firstMatch(text);
    if (center != null) return point(center[1]!, center[2]!, true);
    throw const AppFailure('ลิงก์ไม่มีพิกัด กรุณาแชร์หมุดแบบเต็ม');
  }

  Future<MapPin> resolve(String input) async {
    // Maps also offers "Copy coordinates" on desktop and mobile.
    if (RegExp(
      r'^\s*[+-]?\d+(?:\.\d+)?\s*,\s*[+-]?\d+(?:\.\d+)?\s*$',
    ).hasMatch(input)) {
      return parse(Uri.https('www.google.com', '/maps', {'q': input.trim()}));
    }
    var uri = validate(input);
    for (var hop = 0; hop < 6; hop++) {
      final nested =
          uri.queryParameters['link'] ?? uri.queryParameters['deep_link_id'];
      if (nested == null) break;
      uri = validate(nested);
    }
    if (kIsWeb) {
      try {
        return parse(uri);
      } on AppFailure {
        /* expand through same origin */
      }
      final reply = await http
          .post(
            Uri.base.resolve('/api/maps'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': uri.toString()}),
          )
          .timeout(const Duration(seconds: 30));
      if (reply.statusCode != 200) {
        if (reply.statusCode == 401) {
          throw const AppFailure(
            'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่แล้วอ่านลิงก์อีกครั้ง',
          );
        }
        try {
          final body = jsonDecode(reply.body);
          if (body is Map && body['message'] is String) {
            throw AppFailure(body['message'] as String);
          }
        } on FormatException {
          /* Non-JSON gateway response. */
        }
        throw const AppFailure(
          'เปิดลิงก์ Maps ไม่สำเร็จ กรุณาลองใหม่หรือคัดลอกละติจูด, ลองจิจูด',
        );
      }
      final data = jsonDecode(reply.body) as Map<String, dynamic>;
      return parse(validate(data['url'] as String));
    }
    final seen = <String>{};
    final client = http.Client();
    try {
      for (var hop = 0; hop < 6; hop++) {
        try {
          return parse(uri);
        } on AppFailure {
          /* Expand only approved URLs below. */
        }
        if (!seen.add(uri.toString())) throw const AppFailure('ลิงก์สั้นวนซ้ำ');
        final req = http.Request('GET', uri)..followRedirects = false;
        final res = await client.send(req).timeout(const Duration(seconds: 15));
        String? next;
        if (res.statusCode >= 300 && res.statusCode < 400) {
          next = res.headers['location'];
          await res.stream.drain<void>().timeout(const Duration(seconds: 15));
        } else {
          if (res.statusCode != 200) {
            throw const AppFailure('เปิด Maps ไม่สำเร็จ กรุณาใช้ลิงก์เต็ม');
          }
          final bytes = <int>[];
          await for (final part in res.stream.timeout(
            const Duration(seconds: 15),
          )) {
            bytes.addAll(part);
            if (bytes.length > 1000000) {
              throw const AppFailure('หน้า Maps ใหญ่เกินกำหนด ใช้ลิงก์เต็ม');
            }
          }
          next = pageDestination(utf8.decode(bytes, allowMalformed: true));
        }
        if (next == null) {
          throw const AppFailure('อ่านหมุดไม่ได้ กรุณาใช้ลิงก์เต็ม');
        }
        uri = validate(uri.resolve(next).toString());
      }
      throw const AppFailure('ลิงก์เปลี่ยนเส้นทางหลายครั้ง');
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('เปิดลิงก์ Maps ไม่สำเร็จ กรุณาใช้ลิงก์เต็ม');
    } finally {
      client.close();
    }
  }

  static String? pageDestination(String html) {
    for (final tag in RegExp(
      r'<(?:link|meta)\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final attrs = <String, String>{};
      for (final a in RegExp(
        '([\\w-]+)\\s*=\\s*(["\'])(.*?)\\2',
        dotAll: true,
      ).allMatches(tag[0]!)) {
        attrs[a[1]!.toLowerCase()] = a[3]!;
      }
      final candidate = attrs['rel']?.toLowerCase() == 'canonical'
          ? attrs['href']
          : attrs['property']?.toLowerCase() == 'og:url'
          ? attrs['content']
          : null;
      if (candidate == null) continue;
      final clean = candidate
          .replaceAll('&amp;', '&')
          .replaceAll('&#38;', '&')
          .replaceAll('&#x26;', '&');
      try {
        validate(clean);
        return clean;
      } on AppFailure {
        continue;
      }
    }
    return null;
  }
}
