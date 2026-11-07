class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class UnknownOutcome extends AppFailure {
  const UnknownOutcome()
    : super('ไม่ทราบผลการบันทึก กรุณาตรวจประวัติก่อนเริ่มใหม่');
}

enum Punch { checkIn, checkOut }

extension PunchLabel on Punch {
  String get label => this == Punch.checkIn ? 'เข้างาน' : 'ออกงาน';
  String get wire => this == Punch.checkIn ? 'I' : 'O';
}

class Place {
  const Place(this.name, this.lat, this.lng, this.link);
  final String name;
  final double lat, lng;
  final String link;
  Map<String, Object> toJson() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'link': link,
  };
  factory Place.fromJson(Map<String, dynamic> j) => Place(
    j['name'] as String,
    (j['lat'] as num).toDouble(),
    (j['lng'] as num).toDouble(),
    j['link'] as String,
  );
}

class AttendanceEntry {
  const AttendanceEntry(this.flag, this.time, this.status);
  final String flag, time;
  final int? status;
}

class AttendanceState {
  const AttendanceState(
    this.inFlag,
    this.both,
    this.face,
    this.methods,
    this.inTime,
    this.outTime,
  );
  final int? inFlag;
  final bool both, face;
  final List<int> methods;
  final String inTime, outTime;
  bool allows(Punch p, List<AttendanceEntry> logs) {
    if (logs.any((e) => e.flag == 'I' || e.flag == 'O')) {
      return p == Punch.checkOut;
    }
    return both ||
        (p == Punch.checkIn ? inFlag == 1 : inFlag != null && inFlag != 1);
  }
}

// Fresh local challenge is only a capture prerequisite, never identity verification.
class BlinkGate {
  int _stage = 0;
  bool claimed = false;
  bool get complete => _stage == 3;
  void observe(double? left, double? right, {required bool oneFace}) {
    if (claimed) return;
    if (!oneFace || left == null || right == null) {
      _stage = 0;
      return;
    }
    final open = left > .7 && right > .7;
    final closed = left < .7 && right < .7;
    if (_stage == 0 && open) {
      _stage = 1;
    } else if (_stage == 1 && closed) {
      _stage = 2;
    } else if (_stage == 2 && open) {
      _stage = 3;
    }
  }

  bool claim({required bool foreground, required bool fresh}) {
    if (claimed || !complete || !foreground || !fresh) return false;
    claimed = true;
    return true;
  }

  void reset() {
    _stage = 0;
    claimed = false;
  }
}

class ProcessedAttendanceDay {
  const ProcessedAttendanceDay(this.date,{required this.inTime,required this.outTime,required this.status,required this.holiday,this.pending=false});
  final DateTime date;
  final String inTime,outTime,status;
  final bool holiday,pending;
}
