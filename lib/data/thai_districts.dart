import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Administrative labels for display only. Lookups never transmit coordinates.
class ThaiDistricts {
  ThaiDistricts.fromJson(String text)
    : _data = jsonDecode(text) as Map<String, dynamic>;

  final Map<String, dynamic> _data;
  final _addresses = <(double, double), String?>{};

  static Future<ThaiDistricts?> load() async {
    if (!kIsWeb) return null;
    try {
      final response = await http
          .get(Uri.base.resolve('/thai-districts-v1.json'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return ThaiDistricts.fromJson(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  String? address(double lat, double lng) =>
      _addresses.putIfAbsent((lat, lng), () => _findAddress(lat, lng));

  String? _findAddress(double lat, double lng) {
    final x = lng * 10000, y = lat * 10000;
    final provinces = _data['provinces'] as Map<String, dynamic>;
    for (final district in _data['districts'] as List<dynamic>) {
      final provinceCode = district[0] as String;
      final districtName = district[1] as String;
      for (final polygon in district[2] as List<dynamic>) {
        if (x < (polygon[0] as num) ||
            y < (polygon[1] as num) ||
            x > (polygon[2] as num) ||
            y > (polygon[3] as num)) {
          continue;
        }
        final rings = polygon[4] as List<dynamic>;
        if (!_contains(rings.first as List<dynamic>, x, y) ||
            rings
                .skip(1)
                .any((ring) => _contains(ring as List<dynamic>, x, y))) {
          continue;
        }
        final districtLabel =
            districtName.startsWith('เขต') || districtName.startsWith('อำเภอ')
            ? districtName
            : '${provinceCode == '10' ? 'เขต' : 'อำเภอ'}$districtName';
        final provinceName = provinces[provinceCode] as String;
        return '$districtLabel ${provinceCode == '10' ? '' : 'จังหวัด'}$provinceName';
      }
    }
    return null;
  }

  static bool _contains(List<dynamic> ring, double x, double y) {
    var inside = false;
    // The first pair is absolute. The remaining pairs are deltas, including
    // the closing segment.
    var ax = ring[0] as num, ay = ring[1] as num;
    for (var i = 2; i < ring.length; i += 2) {
      final bx = ax + (ring[i] as num), by = ay + (ring[i + 1] as num);
      if ((ay > y) != (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) {
        inside = !inside;
      }
      ax = bx;
      ay = by;
    }
    return inside;
  }
}
