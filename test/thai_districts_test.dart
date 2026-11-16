import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/maps.dart';
import 'package:nwl_secret_login/data/thai_districts.dart';

void main() {
  test(
    'names the district and province only when the coordinate is inside',
    () {
      List<int> rectangle(int x, int y, int width, int height) => [
        x,
        y,
        width,
        0,
        0,
        height,
        -width,
        0,
        0,
        -height,
      ];
      final lookup = ThaiDistricts.fromJson(
        jsonEncode({
          'provinces': {'10': 'กรุงเทพมหานคร', '50': 'เชียงใหม่'},
          'districts': [
            [
              '10',
              'เขตสาทร',
              [
                [
                  1005100,
                  137100,
                  1005300,
                  137300,
                  [rectangle(1005100, 137100, 200, 200)],
                ],
              ],
            ],
            [
              '50',
              'ฮอด',
              [
                [
                  984000,
                  181000,
                  986000,
                  183000,
                  [
                    rectangle(984000, 181000, 2000, 2000),
                    rectangle(984500, 181500, 500, 1000),
                  ],
                ],
              ],
            ],
          ],
        }),
      );
      expect(lookup.address(13.71688, 100.52173), 'เขตสาทร กรุงเทพมหานคร');
      expect(lookup.address(18.2, 98.55), 'อำเภอฮอด จังหวัดเชียงใหม่');
      expect(lookup.address(18.2, 98.47), isNull);
      expect(lookup.address(0, 0), isNull);
    },
  );

  test('saved pin keeps its address and old records still load', () {
    const pin = Place.thaiCcTower;
    expect(Place.fromJson(pin.toJson()).address, pin.address);
    final old = pin.toJson()..remove('address');
    expect(Place.fromJson(old).isDefaultOffice, isTrue);
    expect(Place.fromJson(old).address, isNull);
  });

  test(
    'looks up missing subdistrict names without losing district details',
    () {
      const district = [
        [
          1005400,
          137600,
          1005500,
          137700,
          [
            [1005400, 137600, 100, 0, 0, 100, -100, 0, 0, -100],
          ],
        ],
      ];
      const namedSection = [
        [
          1005400,
          137600,
          1005450,
          137650,
          [
            [1005400, 137600, 50, 0, 0, 50, -50, 0, 0, -50],
          ],
        ],
      ];
      final lookup = ThaiDistricts.fromJson(
        jsonEncode({
          'provinces': {'10': 'กรุงเทพมหานคร'},
          'cells': {
            '201,27': [0, 1],
          },
          'districts': [
            ['10', 'เขตดินแดง', district, null],
            ['10', 'เขตดินแดง', namedSection, 'ดินแดง'],
          ],
        }),
      );
      expect(lookup.address(13.766, 100.546), 'เขตดินแดง กรุงเทพมหานคร');
      expect(
        lookup.address(13.762, 100.542),
        'แขวงดินแดง เขตดินแดง กรุงเทพมหานคร',
      );
      expect(lookup.address(13.78, 100.542), isNull);
    },
  );

  test('indexes subdistricts and labels Bangkok and provincial addresses', () {
    final lookup = ThaiDistricts.fromJson(
      jsonEncode({
        'provinces': {'10': 'กรุงเทพมหานคร', '50': 'เชียงใหม่'},
        'cells': {
          '201,27': [0],
          '197,36': [1],
        },
        'districts': [
          [
            '10',
            'สาทร',
            [
              [
                1005100,
                137100,
                1005300,
                137300,
                [
                  [1005100, 137100, 200, 0, 0, 200, -200, 0, 0, -200],
                ],
              ],
            ],
            'ยานนาวา',
          ],
          [
            '50',
            'ฮอด',
            [
              [
                985000,
                181000,
                986000,
                183000,
                [
                  [985000, 181000, 1000, 0, 0, 2000, -1000, 0, 0, -2000],
                ],
              ],
            ],
            'หางดง',
          ],
        ],
      }),
    );
    expect(
      lookup.address(13.71688, 100.52173),
      'แขวงยานนาวา เขตสาทร กรุงเทพมหานคร',
    );
    expect(lookup.address(18.2, 98.55), 'ตำบลหางดง อำเภอฮอด จังหวัดเชียงใหม่');
    expect(lookup.address(18.2, 98.48), isNull);
  });

  test('only uses a Thai Google Maps title when the link contains a pin', () {
    final url = Uri.https(
      'www.google.com',
      '/maps/place/ศูนย์+ทดสอบ/@18,99,15z',
    );
    expect(Maps.parse(url).name, isNull);
    expect(
      Maps.parse(url.replace(queryParameters: {'q': '18,99'})).name,
      'ศูนย์ ทดสอบ',
    );
  });
}
