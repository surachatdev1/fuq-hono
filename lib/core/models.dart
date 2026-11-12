enum LoginStage { idle, connecting, contact, connected }

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

class AttendanceChanged extends AppFailure {
  const AttendanceChanged()
    : super('สถานะลงเวลาเปลี่ยนแล้ว กลับไปตรวจประวัติก่อนส่ง');
}

enum Punch { checkIn, checkOut }

extension PunchLabel on Punch {
  String get label => this == Punch.checkIn ? 'เข้างาน' : 'ออกงาน';
  String get wire => this == Punch.checkIn ? 'I' : 'O';
}

class Place {
  const Place(
    this.name,
    this.lat,
    this.lng,
    this.link, {
    this.fromHono = false,
  });
  static const thaiCcTower = Place(
    'Thai CC Tower',
    13.71688,
    100.52173,
    'https://www.google.com/maps/search/?api=1&query=13.71688%2C100.52173',
  );

  final String name;
  final double lat, lng;
  final String link;
  final bool fromHono;
  bool get isDefaultOffice =>
      name == thaiCcTower.name &&
      lat == thaiCcTower.lat &&
      lng == thaiCcTower.lng &&
      link == thaiCcTower.link;

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

class WorkLocation {
  const WorkLocation(this.latitude, this.longitude, this.radiusMeters);

  final double latitude, longitude, radiusMeters;

  bool matches(Place place) => latitude == place.lat && longitude == place.lng;

  static WorkLocation? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final latitude = double.tryParse('${json['latitude']}');
    final longitude = double.tryParse('${json['longitude']}');
    final radius = double.tryParse('${json['radius']}');
    if (latitude == null ||
        !latitude.isFinite ||
        latitude.abs() > 90 ||
        longitude == null ||
        !longitude.isFinite ||
        longitude.abs() > 180 ||
        radius == null ||
        !radius.isFinite ||
        radius <= 0) {
      return null;
    }
    return WorkLocation(latitude, longitude, radius);
  }
}

class AttendanceState {
  const AttendanceState(
    this.inFlag,
    this.both,
    this.face,
    this.methods,
    this.inTime,
    this.outTime, {
    this.workLocations,
  });
  final int? inFlag;
  final bool both, face;
  final List<int> methods;
  final String inTime, outTime;
  final List<WorkLocation>? workLocations;
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
  const ProcessedAttendanceDay(
    this.date, {
    required this.inTime,
    required this.outTime,
    required this.status,
    required this.holiday,
    this.pending = false,
  });
  final DateTime date;
  final String inTime, outTime, status;
  final bool holiday, pending;
}

// Advances only with fresh face observations; a stalled camera cannot fire it.
class CaptureCountdown {
  DateTime? _started, _lastFrame;
  int? remaining;
  void reset() {
    _started = null;
    _lastFrame = null;
    remaining = null;
  }

  bool observe({
    required DateTime now,
    required bool ready,
    required bool eyesOpen,
  }) {
    if (!ready ||
        (_lastFrame != null &&
            now.difference(_lastFrame!) > const Duration(seconds: 1))) {
      reset();
    }
    if (!ready) return false;
    _lastFrame = now;
    _started ??= now;
    final elapsed = now.difference(_started!).inMilliseconds;
    remaining = ((3000 - elapsed) / 1000).ceil().clamp(0, 3);
    return elapsed >= 3000 && eyesOpen;
  }
}

// Position first, then a fresh blink, then a short visible capture countdown.
class FaceScanGuide {
  final blink = BlinkGate();
  final countdown = CaptureCountdown();
  DateTime? _positionSince, _lastFrame;
  bool positioned = false;
  String hint = 'นำใบหน้าเข้ากรอบ';
  void reset() {
    _positionSince = null;
    _lastFrame = null;
    positioned = false;
    hint = 'นำใบหน้าเข้ากรอบ';
    blink.reset();
    countdown.reset();
  }

  bool observe({
    required DateTime now,
    required bool suitable,
    double? left,
    double? right,
    String guidance = 'นำใบหน้าเข้ากรอบ',
  }) {
    if (!suitable ||
        (_lastFrame != null &&
            now.difference(_lastFrame!) > const Duration(seconds: 1))) {
      reset();
    }
    _lastFrame = now;
    if (!suitable) {
      hint = guidance;
      return false;
    }
    if (!positioned) {
      _positionSince ??= now;
      hint = 'อยู่ในกรอบแล้ว ถือให้นิ่งสักครู่';
      if (now.difference(_positionSince!) < const Duration(milliseconds: 800)) {
        return false;
      }
      positioned = true;
      blink.reset();
    }
    blink.observe(left, right, oneFace: true);
    hint = blink.complete
        ? 'ผ่านทั้งสองขั้นตอนแล้ว มองกล้องค้างไว้'
        : 'กะพริบตา 1 ครั้ง แล้วลืมตา';
    return countdown.observe(
      now: now,
      ready: blink.complete,
      eyesOpen: (left ?? 0) > .7 && (right ?? 0) > .7,
    );
  }
}
