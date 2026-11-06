import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/hono.dart';
import 'package:nwl_secret_login/data/maps.dart';
import 'package:nwl_secret_login/data/wire.dart';

void main() {
  WireCodec codec() => WireCodec(
    jsonDecode(File('assets/hono_client_protocol.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  test('blink requires fresh open closed open; cannot claim twice', () {
    final g = BlinkGate();
    g.observe(.1, .1, oneFace: true);
    g.observe(.9, .9, oneFace: true);
    expect(g.complete, false);
    g.observe(.1, .1, oneFace: true);
    g.observe(.9, .9, oneFace: true);
    expect(g.claim(foreground: false, fresh: true), false);
    expect(g.claim(foreground: true, fresh: false), false);
    expect(g.claim(foreground: true, fresh: true), true);
    expect(g.claim(foreground: true, fresh: true), false);
    g.reset();
    expect(g.claim(foreground: true, fresh: true), false);
  });
  test('missing or multiple faces resets blink', () {
    final g = BlinkGate();
    g.observe(.9, .9, oneFace: true);
    g.observe(.1, .1, oneFace: false);
    g.observe(.9, .9, oneFace: true);
    expect(g.complete, false);
  });
  test('AES matches independent Android known vector', () {
    final c = WireCodec({
      'protocol_version': 'hono-22.9-323',
      'key': '1234567890abcdef',
      'iv': 'abcdef1234567890',
      'bootstrap_key': 'fixture',
    });
    expect(c.hex('hello'), 'e93e744afa6fe669a932370bb5f7649d');
  });
  test('PHP1 payload preserves URL and URI component encoding', () {
    final c = codec(),
        url = WireCodec.query('https://psd.hono.ai/a', {
          'pass': 'a &+ก',
          'user': '30000',
        });
    final encoded = c.encode(url, '1');
    expect(
      utf8.decode(base64Decode(encoded.substring(3, encoded.length - 3))),
      url,
    );
    expect(url, contains('a%20%26%2B%E0%B8%81'));
    expect(c.hex('abc').length, 32);
  });
  test('tenant bootstrap → dynamic keys → authenticated session', () async {
    var count = 0;
    final api = HonoApi(
      codec(),
      client: MockClient((r) async {
        count++;
        if (count == 1) {
          return http.Response(
            jsonEncode({
              'result': true,
              'companycode': 'psd',
              'mobileTheme': 1,
              'domain_name': 'hono.ai/sapi/',
              'loginfunction': 'UserAuthenticate_ml_v3',
              'phpversion': '1',
              'sso': 0,
              'honoapp_facial': 0,
            }),
            200,
          );
        }
        if (count == 2) {
          return http.Response(
            jsonEncode({
              'result': true,
              'api_keys': {
                'LOGIN': 'login',
                'MARKIN_MARKOUT': 'mark',
                'FACIAL_RECOG': 'face',
              },
            }),
            200,
          );
        }
        final body = jsonDecode(r.body) as Map;
        expect(body['type'], 'android');
        final encoded = body['encryption_key'] as String;
        final inner = utf8.decode(
          base64Decode(encoded.substring(3, encoded.length - 3)),
        );
        expect(Uri.parse(inner).queryParameters['pass'], 'test & pass');
        return http.Response(
          jsonEncode({
            'result': true,
            'tokenID': 'test-session',
            'Usercode': '30000',
            'Username': 'Test',
            'rolecheck': 0,
          }),
          200,
        );
      }),
    );
    final s = await api.login('psd', '30000', 'test & pass', 'installation');
    expect(s.employee, '30000');
    expect(s.base, 'https://psd.hono.ai/sapi/Service/');
    expect(count, 3);
    api.close();
  });
  test('rejects SSO and makes no credential POST', () async {
    var calls = 0;
    final api = HonoApi(
      codec(),
      client: MockClient((r) async {
        calls++;
        return http.Response('{"result":true,"sso":1}', 200);
      }),
    );
    await expectLater(
      api.login('psd', '30000', 'test', 'id'),
      throwsA(isA<AppFailure>()),
    );
    expect(calls, 1);
    api.close();
  });
  test('rejects history for another employee', () {
    expect(
      () => HonoApi.parseHistory({
        'result': true,
        'data': [
          {'emp_code': 'other', 'punch_time': '08:00'},
        ],
      }, 'own'),
      throwsA(isA<AppFailure>()),
    );
  });
  test('history empty is valid and server time stays unchanged', () {
    expect(HonoApi.parseHistory({'result': true, 'data': []}, 'own'), isEmpty);
    expect(
      HonoApi.parseHistory({
        'result': true,
        'data': [
          {'emp_code': 'own', 'flag': 'I', 'punch_time': '2026-11-07 08:01'},
        ],
      }, 'own').single.time,
      '2026-11-07 08:01',
    );
  });
  test('after any attendance entry offer OUT only', () {
    const s = AttendanceState(1, true, true, [], '', '');
    expect(
      s.allows(Punch.checkIn, [const AttendanceEntry('O', '18:00', 1)]),
      false,
    );
    expect(
      s.allows(Punch.checkOut, [const AttendanceEntry('O', '18:00', 1)]),
      true,
    );
  });
  test('maps pin beats viewport; query share text supported', () {
    final p = Maps.parse(
      Maps.validate(
        'Office https://www.google.com/maps/place/a/@1,2,16z/data=!3d18.7883!4d98.9853',
      ),
    );
    expect(p.lat, 18.7883);
    expect(p.viewport, false);
    expect(
      Maps.parse(Maps.validate('https://maps.google.com/?q=18.7,98.9')).lng,
      98.9,
    );
    expect(
      Maps.parse(
        Maps.validate('https://www.google.com/maps/@18,99,16z'),
      ).viewport,
      true,
    );
  });
  test('maps rejects credentials, non-Google domains and bad coordinates', () {
    for (final bad in [
      'https://google.com.evil.test/maps?q=1,2',
      'https://user@google.com/maps?q=1,2',
      'http://google.com/maps?q=1,2',
    ]) {
      expect(() => Maps.validate(bad), throwsA(isA<AppFailure>()));
    }
    expect(
      () => Maps.parse(Maps.validate('https://google.com/maps?q=91,180')),
      throwsA(isA<AppFailure>()),
    );
  });
  test('canonical destination extracts only approved URL', () {
    expect(
      Maps.pageDestination(
        '<link rel="canonical" href="https://google.com/maps?q=18,99&amp;x=1">',
      ),
      'https://google.com/maps?q=18,99&x=1',
    );
    expect(
      Maps.pageDestination(
        '<meta property="og:url" content="https://evil.test/a">',
      ),
      isNull,
    );
  });
  test('provider config cannot redirect a face to arbitrary host', () {
    expect(
      () => Enrollment.parse({
        'result': true,
        'FacialEndPoint': 'https://evil.test',
        'Facialthreshold': '.65',
        'PersonID': '00000000-0000-0000-0000-000000000000',
        'spoof': '1',
      }),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'network failure during attendance POST is ambiguous and never retried',
    () async {
      var calls = 0;
      final api = HonoApi(
        codec(),
        client: MockClient((r) async {
          calls++;
          throw const SocketException('offline');
        }),
      );
      final s = Session(
        'https://psd.hono.ai/sapi/Service/',
        'psd',
        '1',
        'own',
        'name',
        'token',
        'key',
        'face',
        true,
      );
      await expectLater(
        api.submit(
          s,
          const Place('Office', 18, 99, ''),
          Punch.checkOut,
          // Header-only input is a transport contract fixture, not an actual capture.
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
        throwsA(isA<UnknownOutcome>()),
      );
      expect(calls, 1);
      api.close();
    },
  );
  test('configured spoof failure stops before Azure detect', () async {
    var calls = 0;
    final api = HonoApi(
      codec(),
      client: MockClient((r) async {
        calls++;
        expect(r.url.host, 'devgpt.honohr.com');
        return http.Response('{"status":false}', 200);
      }),
    );
    final e = Enrollment(
      Uri.parse('https://southeastasia.api.cognitive.microsoft.com'),
      'test-key',
      'group',
      '00000000-0000-0000-0000-000000000000',
      .65,
      true,
    );
    await expectLater(
      api.verify(e, Uint8List.fromList([255, 216, 255, 0])),
      throwsA(isA<AppFailure>()),
    );
    expect(calls, 1);
    api.close();
  });
  test(
    'detect is not identity; exact threshold and wrong person fail',
    () async {
      for (final candidate in [
        {'personId': '00000000-0000-0000-0000-000000000001', 'confidence': .99},
        {'personId': '00000000-0000-0000-0000-000000000000', 'confidence': .65},
      ]) {
        var calls = 0;
        final api = HonoApi(
          codec(),
          client: MockClient((r) async {
            calls++;
            return http.Response(
              jsonEncode(
                calls == 1
                    ? [
                        {'faceId': 'fresh-face'},
                      ]
                    : [
                        {
                          'faceId': 'fresh-face',
                          'candidates': [candidate],
                        },
                      ],
              ),
              200,
            );
          }),
        );
        final e = Enrollment(
          Uri.parse('https://southeastasia.api.cognitive.microsoft.com'),
          'test-key',
          'group',
          '00000000-0000-0000-0000-000000000000',
          .65,
          false,
        );
        await expectLater(
          api.verify(e, Uint8List.fromList([255, 216, 255, 0])),
          throwsA(isA<AppFailure>()),
        );
        expect(calls, 2);
        api.close();
      }
    },
  );
  test('own Azure person strictly above threshold passes', () async {
    var calls = 0;
    final api = HonoApi(
      codec(),
      client: MockClient((r) async {
        calls++;
        return http.Response(
          jsonEncode(
            calls == 1
                ? [
                    {'faceId': 'fresh-face'},
                  ]
                : [
                    {
                      'faceId': 'fresh-face',
                      'candidates': [
                        {
                          'personId': '00000000-0000-0000-0000-000000000000',
                          'confidence': .9,
                        },
                      ],
                    },
                  ],
          ),
          200,
        );
      }),
    );
    final e = Enrollment(
      Uri.parse('https://southeastasia.api.cognitive.microsoft.com'),
      'test-key',
      'group',
      '00000000-0000-0000-0000-000000000000',
      .65,
      false,
    );
    await api.verify(e, Uint8List.fromList([255, 216, 255, 0]));
    expect(calls, 2);
    api.close();
  });

  test('company percent matches Android float32 at decimal boundaries', () {
    expect(companyThresholdPercent(.58), 58);
    expect(companyThresholdPercent(.65), 65);
    expect(companyThresholdPercent(1), 100);
  });
}
