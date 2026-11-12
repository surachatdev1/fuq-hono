import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/hono.dart';
import 'package:nwl_secret_login/data/wire.dart';
import 'package:nwl_secret_login/features/attendance_insights.dart';
import 'package:nwl_secret_login/features/reminders.dart';
import 'package:nwl_secret_login/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeferredHistory extends HonoApi {
  DeferredHistory()
    : super(
        WireCodec({
          'protocol_version': 'hono-22.9-323',
          'key': '1234567890abcdef',
          'iv': 'abcdef1234567890',
          'bootstrap_key': 'fixture',
        }),
      );
  final requests = <String, List<Completer<List<AttendanceEntry>>>>{};
  @override
  Future<List<AttendanceEntry>> history(Session s, DateTime date) {
    final completer = Completer<List<AttendanceEntry>>();
    requests.putIfAbsent(HonoApi.dateKey(date), () => []).add(completer);
    return completer.future;
  }

  @override
  Future<AttendanceState> state(Session s) async =>
      const AttendanceState(1, true, true, [], '', '');
}

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
);

class DeferredAttendance extends DeferredHistory {
  final stateReads = <Completer<AttendanceState>>[];
  final calendarRead = Completer<List<ProcessedAttendanceDay>>();
  int calendarReads = 0;

  @override
  Future<AttendanceState> state(Session s) {
    final result = Completer<AttendanceState>();
    stateReads.add(result);
    return result.future;
  }

  @override
  Future<List<ProcessedAttendanceDay>> processedMonth(
    Session s,
    DateTime date,
  ) {
    calendarReads++;
    return calendarRead.future;
  }
}

void main() {
  testWidgets(
    'the places screen shows work areas for the active HONO account',
    (tester) async {
      final api = DeferredAttendance();
      final c = AppController(api: api)
        ..session = fixture()
        ..places = [Place.thaiCcTower];
      addTearDown(c.dispose);
      final state = HonoApi.parseAttendanceState({
        'work_location_lat_long': [
          {'latitude': '13.7', 'longitude': 100.5, 'radius': '150'},
          {'latitude': '13.8', 'longitude': 100.6, 'radius': '250'},
          {'latitude': 92, 'longitude': 100.6, 'radius': 250},
        ],
      });
      final refresh = c.refresh(includeProcessed: false);
      api.stateReads.single.complete(state);
      api.requests[HonoApi.dateKey(c.date)]!.single.complete([]);
      await refresh;
      expect(c.workLocations?.map((area) => area.radiusMeters), [150, 250]);
      expect(c.place, Place.thaiCcTower);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlacesPage(controller: c)),
        ),
      );
      expect(find.text('พื้นที่ลงเวลาจาก HONO'), findsOneWidget);
      expect(find.textContaining('รัศมี 150'), findsOneWidget);
      expect(find.textContaining('รัศมี 250'), findsOneWidget);
      await tester.tap(find.text('พื้นที่ HONO 2'));
      expect(c.place?.fromHono, true);
      expect(c.place?.lat, 13.8);
      expect(c.place?.lng, 100.6);
      expect(c.places, [Place.thaiCcTower]);

      final latest = c.refresh(includeProcessed: false);
      api.stateReads.last.complete(
        const AttendanceState(
          1,
          true,
          true,
          [],
          '',
          '',
          workLocations: [WorkLocation(13.7, 100.5, 150)],
        ),
      );
      api.requests[HonoApi.dateKey(c.date)]!.last.complete([]);
      await latest;
      expect(c.place, isNull);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => c.selectPlace(0));
      expect(c.place, Place.thaiCcTower);
      c.selectHonoPlace(0);
      await tester.runAsync(c.logout);
      expect(c.workLocations, isNull);
      expect(c.place, Place.thaiCcTower);
    },
  );

  test(
    'scan refresh reads history and state together without waiting for calendar',
    () async {
      final api = DeferredAttendance();
      final c = AppController(api: api)
        ..session = fixture()
        ..places = [Place.thaiCcTower];
      addTearDown(c.dispose);
      const ready = AttendanceState(1, true, true, [], '', '');
      final day = HonoApi.dateKey(c.date);
      final initial = c.refresh();
      expect(api.stateReads, hasLength(1));
      expect(api.requests[day], hasLength(1));
      api.stateReads.first.complete(ready);
      api.requests[day]!.first.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(c.processedLoading, true);
      expect(c.canScan, true);

      final scan = c.refresh(includeProcessed: false);
      expect(api.stateReads, hasLength(2));
      expect(api.requests[day], hasLength(2));
      expect(c.canScan, false);
      api.stateReads.last.complete(ready);
      api.requests[day]!.last.complete([]);
      await scan.timeout(const Duration(seconds: 1));
      expect(c.canScan, true);
      expect(c.processedLoading, true);
      expect(api.calendarReads, 1);

      api.calendarRead.complete([
        ProcessedAttendanceDay(
          c.date,
          inTime: '08:30',
          outTime: '',
          status: '',
          holiday: false,
        ),
      ]);
      await initial;
      expect(c.processedDay?.inTime, '08:30');
    },
  );

  final day = DateTime(2026, 11, 6), now = DateTime(2026, 11, 7, 20);
  LateDay summary(String? time, {bool pending = false}) =>
      summarizeProcessedDay(
        day,
        time == null
            ? null
            : ProcessedAttendanceDay(
                day,
                inTime: time,
                outTime: '18:00',
                status: 'Present',
                holiday: false,
                pending: pending,
              ),
        now,
      );
  test('processed 09:00 exact is on time; one second late rounds up', () {
    expect(summary('09:00:00').minutes, 0);
    expect(summary('09:00:01').minutes, 1);
  });
  test('missing and pending processed data never fall back to raw punches', () {
    expect(summary(null).kind, DayAttendance.unknown);
    expect(summary('09:45', pending: true).kind, DayAttendance.unknown);
    expect(summary('08:45').minutes, 0);
  });
  test('malformed or cross-day processed time is incomplete', () {
    expect(summary('bad').kind, DayAttendance.unknown);
    expect(summary('2026-11-05 09:12').kind, DayAttendance.unknown);
    expect(summary('').kind, DayAttendance.noIn);
  });
  test('zoned timestamp converted to Bangkok before day validation', () {
    expect(punchClock('2026-11-06T02:12:00Z', day)?.hour, 9);
    expect(punchClock('2026-11-06T20:12:00Z', day), isNull);
    expect(punchClock('24:12', day), isNull);
  });
  test(
    'HONO legacy date and AM PM clock parse with strict date validation',
    () {
      expect(punchClock('06-Nov-2026----  9:05am', day)?.minute, 5);
      expect(punchClock('06-Nov-2026---- 12:00am', day)?.hour, 0);
      expect(punchClock('06-Nov-2026---- 12:00pm', day)?.hour, 12);
      expect(punchClock('07-Nov-2026---- 9:05am', day), isNull);
      expect(punchClock('06-Nov-2026---- 13:05am', day), isNull);
    },
  );
  test('strictly over 30 minutes, not exactly 30', () {
    final report = LateReport(day, [summary('09:30')]);
    expect(report.minutes, 30);
    expect(report.exceedsWarning, false);
    report.days.add(
      LateDay(DateTime(2026, 11, 5), DayAttendance.late, minutes: 1),
    );
    expect(report.minutes, 31);
    expect(report.exceedsWarning, true);
  });
  test('manual holiday and extra workday take precedence over weekdays', () {
    final c = WorkCalendar(
      holidays: {'2026-11-06'},
      extraWorkdays: {'2026-11-07'},
    );
    expect(c.isWorkday(day), false);
    expect(c.isWorkday(DateTime(2026, 11, 7)), true);
    expect(WorkCalendar.fromJson(c.toJson()).isWorkday(day), false);
    expect(summarizeProcessedDay(day, null, now).kind, DayAttendance.unknown);
  });
  test(
    'reminders suppress confirmed punches and holidays; failures stay unknown',
    () {
      ReminderDecision decide({
        bool work = true,
        bool exit = false,
        bool known = true,
        bool hasIn = false,
        bool hasOut = false,
      }) => reminderDecision(
        workday: work,
        exit: exit,
        known: known,
        hasIn: hasIn,
        hasOut: hasOut,
      );
      expect(decide(), ReminderDecision.missing);
      expect(decide(hasIn: true), ReminderDecision.suppress);
      expect(decide(hasIn: true, exit: true), ReminderDecision.missing);
      expect(decide(exit: true, hasOut: true), ReminderDecision.suppress);
      expect(decide(work: false, known: false), ReminderDecision.suppress);
      expect(decide(known: false), ReminderDecision.unknown);
      expect(decide(known: false, hasIn: true), ReminderDecision.suppress);
    },
  );
  test(
    'Bangkok slots roll forward exactly once without host timezone dependence',
    () {
      expect(
        nextReminderInstant(DateTime.utc(2026, 11, 6, 1, 19), 0),
        DateTime.utc(2026, 11, 6, 1, 20),
      );
      expect(
        nextReminderInstant(DateTime.utc(2026, 11, 6, 1, 20), 0),
        DateTime.utc(2026, 11, 7, 1, 20),
      );
      expect(
        nextReminderInstant(DateTime.utc(2026, 11, 6, 23), 3),
        DateTime.utc(2026, 11, 7, 11),
      );
    },
  );
  test(
    'explicit no-record response is empty; permission and ambiguous rejection are errors',
    () {
      expect(
        HonoApi.parseHistory({
          'result': false,
          'message': 'No data found',
          'data': [],
        }, 'own'),
        isEmpty,
      );
      expect(
        () => HonoApi.parseHistory({
          'result': false,
          'message': 'Token expired: no data',
          'data': [],
        }, 'own'),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => HonoApi.parseHistory({'result': false, 'data': []}, 'own'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    '6 to 7 clears prior history immediately even when 7 is rejected',
    () async {
      final api = DeferredHistory();
      final controller = AppController(api: api)..session = fixture();
      final sixth = controller.changeDate(day);
      api.requests['2026-11-06']!.single.complete([
        const AttendanceEntry('I', '08:00', 1),
      ]);
      await sixth;
      expect(controller.logs.single.time, '08:00');
      final seventh = controller.changeDate(DateTime(2026, 11, 7));
      expect(controller.logs, isEmpty);
      expect(controller.loadedHistoryDate, isNull);
      api.requests['2026-11-07']!.single.completeError(
        const AppFailure('rejected'),
      );
      await seventh;
      expect(controller.logs, isEmpty);
      expect(controller.historyError, 'rejected');
      controller.dispose();
    },
  );
  test('slow earlier-day reply cannot overwrite newly selected date', () async {
    final api = DeferredHistory();
    final controller = AppController(api: api)..session = fixture();
    final first = controller.changeDate(day),
        second = controller.changeDate(DateTime(2026, 11, 7));
    api.requests['2026-11-07']!.single.complete([]);
    await second;
    api.requests['2026-11-06']!.single.complete([
      const AttendanceEntry('I', '08:00', 1),
    ]);
    await first;
    expect(controller.logs, isEmpty);
    expect(controller.loadedHistoryDate, DateTime(2026, 11, 7));
    controller.dispose();
  });
}
