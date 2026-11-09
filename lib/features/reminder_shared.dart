import '../data/hono.dart';
import 'attendance_insights.dart';

DateTime reminderNow() {
  final b = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime(
    b.year,
    b.month,
    b.day,
    b.hour,
    b.minute,
    b.second,
    b.millisecond,
  );
}

const reminderSlots = [(8, 20), (8, 30), (8, 50), (18, 0)];

enum ReminderDecision { suppress, missing, unknown }

ReminderDecision reminderDecision({
  required bool workday,
  required bool exit,
  required bool known,
  required bool hasIn,
  required bool hasOut,
}) {
  if (!workday || (exit ? hasOut : hasIn)) {
    return ReminderDecision.suppress;
  }
  return known ? ReminderDecision.missing : ReminderDecision.unknown;
}

DateTime nextReminderInstant(DateTime utcNow, int slot) {
  final wall = utcNow.toUtc().add(const Duration(hours: 7)),
      time = reminderSlots[slot];
  var target = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    time.$1,
    time.$2,
  ).subtract(const Duration(hours: 7));
  if (!target.isAfter(utcNow.toUtc())) {
    target = target.add(const Duration(days: 1));
  }
  return target;
}

class LocalAttendance {
  const LocalAttendance({
    this.hasIn = false,
    this.hasOut = false,
    this.synced = false,
  });
  final bool hasIn, hasOut, synced;
  factory LocalAttendance.fromJson(Map<String, dynamic> j) => LocalAttendance(
    hasIn: j['in'] == true,
    hasOut: j['out'] == true,
    synced: j['sync'] != null,
  );
}

DateTime? nextLocalReminderInstant(
  DateTime utcNow,
  int slot,
  WorkCalendar calendar,
  Map<String, LocalAttendance> snapshots,
) {
  var target = nextReminderInstant(utcNow, slot);
  for (var d = 0; d < 370; d++) {
    final wall = target.add(const Duration(hours: 7));
    final snapshot =
        snapshots[HonoApi.dateKey(wall)] ?? const LocalAttendance();
    if (calendar.isWorkday(wall) &&
        !(slot == 3 ? snapshot.hasOut : snapshot.hasIn)) {
      return target;
    }
    target = target.add(const Duration(days: 1));
  }
  return null;
}

class ReminderPreferences {
  bool enabled = false, notifyUnknown = true, alarmStyle = true;
  String sound = 'system', customUri = '';
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'notifyUnknown': notifyUnknown,
    'alarmStyle': alarmStyle,
    'sound': sound,
    'customUri': customUri,
  };
  factory ReminderPreferences.fromJson(Map<String, dynamic> j) =>
      ReminderPreferences()
        ..enabled = j['enabled'] == true
        ..notifyUnknown = j['notifyUnknown'] != false
        ..alarmStyle = j['alarmStyle'] != false
        ..sound = (j['sound'] as String? ?? 'system')
        ..customUri = (j['customUri'] as String? ?? '');
  ReminderPreferences();
}

String reminderAccount(Session s) => '${s.company}:${s.employee}';
String snapshotKey(String account, DateTime date) =>
    'attendance_snapshot:$account:${HonoApi.dateKey(date)}';
