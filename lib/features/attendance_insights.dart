import '../core/models.dart';
import '../data/hono.dart';

class WorkCalendar {
  WorkCalendar({
    Set<int>? weekdays,
    Set<String>? holidays,
    Set<String>? extraWorkdays,
    Map<String,bool>? serverWorkdays,
  }) : weekdays = weekdays ?? {1, 2, 3, 4, 5},
       holidays = holidays ?? {},
       extraWorkdays = extraWorkdays ?? {},
       serverWorkdays = serverWorkdays ?? {};
  final Map<String,bool> serverWorkdays;
  final Set<int> weekdays;
  final Set<String> holidays, extraWorkdays;
  bool isWorkday(DateTime date) {
    final key = HonoApi.dateKey(date);
    if (extraWorkdays.contains(key)) return true;
    if (holidays.contains(key)) return false;
    return serverWorkdays[key]??weekdays.contains(date.weekday);
  }

  WorkCalendar copy() => WorkCalendar(
    weekdays: {...weekdays},
    serverWorkdays:{...serverWorkdays},
    holidays: {...holidays},
    extraWorkdays: {...extraWorkdays},
  );
  Map<String, dynamic> toJson() => {
    'weekdays': weekdays.toList(),
    'serverWorkdays':serverWorkdays,
    'holidays': holidays.toList(),
    'extraWorkdays': extraWorkdays.toList(),
  };
  factory WorkCalendar.fromJson(Map<String, dynamic> j) => WorkCalendar(
    serverWorkdays: (j['serverWorkdays'] as Map? ?? {}).map((k,v)=>MapEntry(k.toString(),v==true)),
    weekdays: (j['weekdays'] as List? ?? [1, 2, 3, 4, 5])
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toSet(),
    holidays: (j['holidays'] as List? ?? []).whereType<String>().toSet(),
    extraWorkdays: (j['extraWorkdays'] as List? ?? [])
        .whereType<String>()
        .toSet(),
  );
}

enum DayAttendance { onTime, late, noIn, holiday, unknown, pending }

class LateDay {
  const LateDay(this.date, this.kind, {this.firstIn, this.minutes = 0});
  final DateTime date;
  final DayAttendance kind;
  final DateTime? firstIn;
  final int minutes;
}

class LateReport {
  LateReport(this.month, this.days);
  final DateTime month;
  final List<LateDay> days;
  int get minutes => days.fold(0, (n, d) => n + d.minutes);
  int get lateDays => days.where((d) => d.kind == DayAttendance.late).length;
  int get unknownDays =>
      days.where((d) => d.kind == DayAttendance.unknown).length;
  int get missingDays => days.where((d) => d.kind == DayAttendance.noIn).length;
  bool get exceedsWarning => minutes > 30;
}

// Treat an unzoned server clock as Bangkok wall time. Zoned ISO timestamps are
// converted to Bangkok before checking the queried day; never infer a date.
DateTime? punchClock(String text, DateTime day) {
  final raw = text.trim();
  // HONO legacy history text: "06-Nov-2026----  9:05am".
  final legacy = RegExp(
    r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})-+\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (legacy != null) {
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final month = months.indexOf(legacy[2]!.toLowerCase()) + 1;
    final date = int.parse(legacy[1]!), year = int.parse(legacy[3]!);
    final hour = int.parse(legacy[4]!),
        minute = int.parse(legacy[5]!),
        second = int.parse(legacy[6] ?? '0');
    if (month == 0 ||
        year != day.year ||
        month != day.month ||
        date != day.day ||
        hour < 1 ||
        hour > 12 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    return DateTime(
      year,
      month,
      date,
      hour % 12 + (legacy[7]!.toLowerCase() == 'pm' ? 12 : 0),
      minute,
      second,
    );
  }
  if (RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(raw)) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final bkk = parsed.toUtc().add(const Duration(hours: 7));
    return HonoApi.dateKey(bkk) == HonoApi.dateKey(day)
        ? DateTime(
            day.year,
            day.month,
            day.day,
            bkk.hour,
            bkk.minute,
            bkk.second,
            bkk.millisecond,
          )
        : null;
  }
  final m = RegExp(
    r'^(?:(\d{4})-(\d{2})-(\d{2})[ T])?(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(raw);
  if (m == null) return null;
  if (m[1] != null &&
      (int.parse(m[1]!) != day.year ||
          int.parse(m[2]!) != day.month ||
          int.parse(m[3]!) != day.day)) {
    return null;
  }
  final hour = int.parse(m[4]!),
      minute = int.parse(m[5]!),
      second = int.parse(m[6] ?? '0');
  if (hour > 23 || minute > 59 || second > 59) return null;
  return DateTime(day.year, day.month, day.day, hour, minute, second);
}

LateDay summarizeProcessedDay(DateTime day,ProcessedAttendanceDay? record,WorkCalendar calendar,DateTime now) {
  if(record?.holiday==true || !calendar.isWorkday(day)){return LateDay(day,DayAttendance.holiday);}
  if(record==null || record.pending){return LateDay(day,DayAttendance.unknown);}
  if(record.inTime.isEmpty){
    final pending=HonoApi.dateKey(day)==HonoApi.dateKey(now)&&now.isBefore(DateTime(day.year,day.month,day.day,9));
    return LateDay(day,pending?DayAttendance.pending:DayAttendance.noIn);
  }
  final first=punchClock(record.inTime,day);
  if(first==null){return LateDay(day,DayAttendance.unknown);}
  final delta=first.difference(DateTime(day.year,day.month,day.day,9)).inMilliseconds;
  final minutes=delta<=0?0:(delta/60000).ceil();
  return LateDay(day,minutes>0?DayAttendance.late:DayAttendance.onTime,firstIn:first,minutes:minutes);
}
