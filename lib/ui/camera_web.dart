import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../core/controller.dart';
import '../core/models.dart';
import '../data/hono_web.dart';
import 'scan_view.dart';
export 'scan_view.dart';

@JS('nwlFaceStart')
external JSPromise<JSString> _start(web.HTMLVideoElement video);
@JS('nwlFacePoll')
external String _poll();
@JS('nwlFaceCapture')
external String _capture();
@JS('nwlFaceStop')
external JSFunction? get _stopCamera;
void _stop() => _stopCamera?.callAsFunction();

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.controller,
    required this.punch,
    required this.place,
  });
  final AppController controller;
  final Punch punch;
  final Place place;
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final guide = FaceScanGuide(
    positionHold: const Duration(milliseconds: 400),
    positionGrace: const Duration(milliseconds: 250),
    captureHold: const Duration(seconds: 1),
  );
  static const failures = {
    'camera_permission':
        'ยังไม่ได้อนุญาตกล้อง เปิดสิทธิ์กล้องของเว็บแล้วลองใหม่',
    'camera_missing': 'ไม่พบกล้องที่ใช้งานได้ ตรวจการเชื่อมต่อกล้องแล้วลองใหม่',
    'camera_busy': 'กล้องเปิดไม่ได้ ลองปิดแอปหรือแท็บอื่นที่ใช้กล้องอยู่',
    'camera_unsupported':
        'เบราว์เซอร์นี้เปิดกล้องไม่ได้ ลองเปิดเว็บผ่าน Chrome หรือ Safari โดยตรง',
    'camera_start':
        'เปิดกล้องไม่สำเร็จ ตรวจสิทธิ์และการเชื่อมต่อกล้องแล้วลองใหม่',
    'camera_no_frames': 'กล้องยังไม่ส่งภาพ ตรวจกล้องแล้วลองใหม่',
    'camera_stopped': 'กล้องหยุดส่งภาพ กรุณาเริ่มสแกนใหม่',
    'model_load': 'โหลดตัวตรวจใบหน้าไม่สำเร็จ ตรวจอินเทอร์เน็ตแล้วลองใหม่',
    'startup_timeout':
        'เตรียมกล้องและตัวตรวจใบหน้าไม่ทันใน 30 วินาที กรุณาลองใหม่',
    'position_timeout':
        'ยังจัดใบหน้าไม่เข้ากรอบใน 30 วินาที มองกล้องตรง ๆ ในที่สว่างแล้วลองใหม่',
    'blink_timeout':
        'ยังจับจังหวะกะพริบตาไม่ทันใน 30 วินาที รอให้ขั้นที่ 1 ผ่าน แล้วกะพริบตา 1 ครั้ง',
    'capture_timeout':
        'ยังถ่ายภาพไม่ทันใน 30 วินาที มองกล้องและลืมตาไว้จนถ่ายเสร็จ',
    'detector_failure': 'ตัวตรวจใบหน้าอ่านภาพไม่สำเร็จ กรุณาเริ่มสแกนใหม่',
    'capture_failure': 'ถ่ายภาพจากกล้องไม่สำเร็จ กรุณาเริ่มสแกนใหม่',
  };
  BlinkGate get gate => guide.blink;
  CaptureCountdown get countdown => guide.countdown;
  final id = 'nwl-camera-${DateTime.now().microsecondsSinceEpoch}';
  web.HTMLVideoElement? cameraElement;
  Timer? timer;
  Timer? scanTimeout;
  bool busy = false, matched = false, foreground = true;
  bool cameraReady = false;
  int generation = 0;
  String error = '', stage = 'กำลังเปิดกล้องและเตรียมตัวตรวจใบหน้า…';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> start() async {
    final ticket = ++generation;
    guide.reset();
    cameraReady = false;
    stage = 'กำลังเปิดกล้องและเตรียมตัวตรวจใบหน้า…';
    timer?.cancel();
    scanTimeout?.cancel();
    scanTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted || busy || ticket != generation) return;
      fail(
        !cameraReady
            ? 'startup_timeout'
            : !guide.positioned
            ? 'position_timeout'
            : !gate.complete
            ? 'blink_timeout'
            : 'capture_timeout',
      );
    });
    try {
      final video = cameraElement;
      if (video == null) throw StateError('Camera element not created');
      final result = (await _start(video).toDart).toDart;
      if (!mounted || ticket != generation || !foreground) return;
      if (result != 'ready') {
        fail(result);
        return;
      }
      setState(() => cameraReady = true);
      timer = Timer.periodic(
        const Duration(milliseconds: 70),
        (_) => analyze(),
      );
    } catch (_) {
      if (mounted && ticket == generation) fail('camera_start');
    }
  }

  void fail(String kind) {
    generation++;
    timer?.cancel();
    scanTimeout?.cancel();
    _stop();
    guide.reset();
    final code = failures.containsKey(kind) ? kind : 'camera_start';
    setState(() => error = failures[code]!);
    if (!widget.controller.demo) {
      unawaited(reportBrowserEvent('face-scan', code));
    }
  }

  (bool, bool, int?, String) get guideState =>
      (guide.positioned, gate.complete, countdown.remaining, guide.hint);

  void analyze() {
    if (busy || error.isNotEmpty || !foreground) return;
    try {
      final j = jsonDecode(_poll()) as Map<String, dynamic>;
      if (j.isEmpty) return;
      if (j['error'] case final String code) {
        fail(code);
        return;
      }
      final previous = guideState;
      final hint = j['hint'];
      final ready = guide.observe(
        now: DateTime.now(),
        suitable: j['one'] == true,
        left: (j['left'] as num?)?.toDouble(),
        right: (j['right'] as num?)?.toDouble(),
        oneFaceOutOfPosition:
            hint == 'closer' || hint == 'back' || hint == 'center',
        guidance: switch (hint) {
          'closer' => 'ขยับใบหน้าเข้ามาใกล้อีกนิด',
          'back' => 'ขยับออกเล็กน้อย ให้เห็นใบหน้าครบ',
          'center' => 'จัดใบหน้าให้อยู่กลางกรอบ',
          'multiple' => 'ให้มีใบหน้าในกรอบเพียงคนเดียว',
          _ => 'นำใบหน้าเข้ากรอบ',
        },
      );
      if (guideState != previous) setState(() {});
      if (ready && gate.claim(foreground: foreground, fresh: true)) {
        unawaited(capture());
      }
    } catch (_) {
      fail('detector_failure');
    }
  }

  Future<void> capture() async {
    if (busy || !foreground) return;
    scanTimeout?.cancel();
    setState(() {
      busy = true;
      stage = 'กำลังถ่ายภาพ…';
    });
    timer?.cancel();
    Uint8List? bytes;
    final ticket = generation;
    try {
      try {
        final data = _capture();
        if (!data.startsWith('data:image/jpeg;base64,')) {
          throw const FormatException('Camera did not return a JPEG');
        }
        bytes = base64Decode(data.split(',').last);
      } catch (_) {
        fail('capture_failure');
        return;
      }
      final captured = DateTime.now();
      _stop();
      if (!mounted || !foreground || ticket != generation) {
        throw const AppFailure('กรุณาสแกนใหม่');
      }
      if (widget.controller.demo) {
        setState(() => stage = 'โหมดทดลอง · ไม่ส่งรายการจริง');
        return;
      }
      await widget.controller.submitFresh(
        bytes,
        captured,
        widget.punch,
        widget.place,
        (text, identity) {
          if (mounted) {
            setState(() {
              stage = text;
              matched = identity;
            });
          }
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on UnknownOutcome {
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The permission prompt can blur the tab without hiding the document.
    if (state == AppLifecycleState.inactive && !web.document.hidden) return;
    foreground = state == AppLifecycleState.resumed;
    widget.controller.setForeground(foreground);
    if (!foreground) {
      generation++;
      scanTimeout?.cancel();
      timer?.cancel();
      _stop();
      guide.reset();
      if (mounted && !busy && error.isEmpty) {
        setState(
          () => error = 'การสแกนหยุดเมื่อสลับหน้า กรุณายืนยันและสแกนใหม่',
        );
      }
    }
  }

  @override
  void dispose() {
    generation++;
    scanTimeout?.cancel();
    timer?.cancel();
    _stop();
    cameraElement = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text('ลงเวลา${widget.punch.label}'),
        automaticallyImplyLeading: !busy,
      ),
      body: SafeArea(
        child: ScanView(
          punch: widget.punch,
          place: widget.place,
          matched: matched,
          busy: busy,
          found: guide.positioned,
          blink: gate.complete,
          error: error,
          stage: busy || error.isNotEmpty || !cameraReady ? stage : guide.hint,
          countdown: busy || error.isNotEmpty ? null : countdown.remaining,
          onRetry: foreground && !busy
              ? () {
                  setState(() {
                    error = '';
                    matched = false;
                  });
                  unawaited(start());
                }
              : null,
          onBack: busy ? null : () => Navigator.pop(context),
          preview: HtmlElementView.fromTagName(
            tagName: 'video',
            onElementCreated: (element) {
              final video = element as web.HTMLVideoElement;
              video.id = id;
              cameraElement = video;
              video.style.width = '100%';
              video.style.height = '100%';
              // Keep the entire captured frame visible on short and narrow screens.
              video.style.objectFit = 'contain';
              video.style.transform = 'scaleX(-1)';
              unawaited(start());
            },
          ),
        ),
      ),
    ),
  );
}
