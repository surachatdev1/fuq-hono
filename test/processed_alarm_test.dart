import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/hono.dart';
import 'package:nwl_secret_login/data/wire.dart';
import 'package:nwl_secret_login/features/attendance_insights.dart';
import 'package:nwl_secret_login/features/reminders.dart';

WireCodec codec() => WireCodec({
  'protocol_version': 'hono-22.9-323',
  'key': '1234567890abcdef',
  'iv': 'abcdef1234567890',
  'bootstrap_key': 'fixture',
});
Session fixture() => Session(
  'https://test.hono.ai/sapi/Service/',
  'test',
  '1',
  'own',
  'Test',
  'token',
  'mark',
  'face',
  false,
  calendarKey: 'calendar',
);
Map<String, dynamic> row(String date) => {
  'start': date,
  'startTime': '08:45',
  'endTime': '18:00',
  'status': 'Present',
  'isWeeklyOff': '',
  'isHoliday': '',
  'typeOfAwaitingApproval': '',
};

class ProcessedApi extends HonoApi {
  ProcessedApi() : super(codec());
  int rawReads = 0;
  @override
  Future<List<AttendanceEntry>> history(Session s, DateTime date) async {
    rawReads++;
    return [const AttendanceEntry('I', '09:45', 1)];
  }

  @override
  Future<List<ProcessedAttendanceDay>> processedMonth(
    Session s,
    DateTime month,
  ) async => [
    ProcessedAttendanceDay(
      DateTime(month.year, month.month, 6),
      inTime: '08:45',
      outTime: '18:00',
      status: 'Present',
      holiday: false,
    ),
  ];
}

void main() {
  final day = DateTime(2026, 11, 6),
      calendar = WorkCalendar(),
      now = DateTime.utc(2026, 11, 6, 1, 21);
  test('local IN skips remaining morning slots and keeps OUT today', () {
    final snapshots = {
      '2026-11-06': const LocalAttendance(hasIn: true, synced: true),
    };
    expect(
      nextLocalReminderInstant(now, 1, calendar, snapshots),
      DateTime.utc(2026, 11, 9, 1, 30),
    );
    expect(
      nextLocalReminderInstant(now, 2, calendar, snapshots),
      DateTime.utc(2026, 11, 9, 1, 50),
    );
    expect(
      nextLocalReminderInstant(now, 3, calendar, snapshots),
      DateTime.utc(2026, 11, 6, 11),
    );
    snapshots['2026-11-06'] = const LocalAttendance(
      hasIn: true,
      hasOut: true,
      synced: true,
    );
    expect(
      nextLocalReminderInstant(now, 3, calendar, snapshots),
      DateTime.utc(2026, 11, 9, 11),
    );
  });
  test(
    'old date cache never suppresses today; no workdays means no alarms',
    () {
      expect(
        nextLocalReminderInstant(DateTime.utc(2026, 11, 6, 1), 0, calendar, {
          '2026-11-05': const LocalAttendance(hasIn: true),
        }),
        DateTime.utc(2026, 11, 6, 1, 20),
      );
      expect(
        nextLocalReminderInstant(now, 0, WorkCalendar(weekdays: {}), {}),
        isNull,
      );
    },
  );
  test('processed calendar rejects wrong month, owner and duplicate dates', () {
    final records = HonoApi.parseProcessedCalendar(
      {
        'result': true,
        'show_calendar': jsonEncode([row('2026-11-06')]),
      },
      'own',
      day,
    );
    expect(records.single.inTime, '08:45');
    for (final rows in [
      [row('2026-10-06')],
      [row('2026-11-06'), row('2026-11-06')],
      [
        {...row('2026-11-06'), 'emp_code': 'other'},
      ],
    ]) {
      expect(
        () => HonoApi.parseProcessedCalendar(
          {'result': true, 'show_calendar': rows},
          'own',
          day,
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    final pending = HonoApi.parseProcessedCalendar(
      {
        'result': true,
        'show_calendar': [
          {...row('2026-11-06'), 'typeOfAwaitingApproval': 'AR'},
        ],
      },
      'own',
      day,
    ).single;
    expect(
      summarizeProcessedDay(day, pending, DateTime(2026, 11, 7)).kind,
      DayAttendance.unknown,
    );
  });
  test('manual alarm holidays cannot hide a processed late workday', () {
    final local = WorkCalendar(holidays: {'2026-11-06'});
    expect(local.isWorkday(day), false);
    final processed = ProcessedAttendanceDay(
      day,
      inTime: '09:31',
      outTime: '18:00',
      status: 'Present',
      holiday: false,
    );
    expect(
      summarizeProcessedDay(day, processed, DateTime(2026, 11, 7)).minutes,
      31,
    );
    final holiday = ProcessedAttendanceDay(
      day,
      inTime: '',
      outTime: '',
      status: 'Holiday',
      holiday: true,
    );
    expect(
      summarizeProcessedDay(day, holiday, DateTime(2026, 11, 7)).kind,
      DayAttendance.holiday,
    );
  });
  test(
    'server holiday is retained locally and manual extra workday overrides it',
    () {
      final c = WorkCalendar(serverWorkdays: {'2026-11-06': false});
      expect(c.isWorkday(day), false);
      final restored = WorkCalendar.fromJson(c.toJson());
      expect(restored.isWorkday(day), false);
      restored.extraWorkdays.add('2026-11-06');
      expect(restored.isWorkday(day), true);
    },
  );
  test(
    'processed request uses CALENDAR key, own employee and own logged-in user',
    () async {
      var calls = 0;
      final api = HonoApi(
        codec(),
        client: MockClient((r) async {
          calls++;
          expect(r.method, 'GET');
          expect(r.url.path, '/sapi/CalendarMaster/showCalendar_v2');
          final wrapped = r.url.queryParameters['encryption_key']!;
          final params = Uri.parse(
            utf8.decode(base64Decode(wrapped.substring(3, wrapped.length - 3))),
          ).queryParameters;
          expect(params['emp_code'], 'own');
          expect(params['loggedin_user'], 'own');
          expect(params['api_key'], 'calendar');
          expect(params['role'], 'Employee');
          expect(params['from_date'], '2026-11-01');
          expect(params['to_date'], '2026-11-30');
          return http.Response(
            jsonEncode({
              'result': true,
              'show_calendar': [row('2026-11-06')],
            }),
            200,
          );
        }),
      );
      expect((await api.processedMonth(fixture(), day)).single.inTime, '08:45');
      expect(calls, 1);
      api.close();
    },
  );
  test('monthly lateness uses processed 08:45 instead of raw 09:45', () async {
    final api = ProcessedApi();
    final c = AppController(api: api)
      ..session = fixture()
      ..date = day;
    await c.loadMonthlyReport();
    expect(c.lateReport?.minutes, 0);
    expect(api.rawReads, 0);
    c.dispose();
  });
}
