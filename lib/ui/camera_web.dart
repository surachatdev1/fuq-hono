import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../core/controller.dart';
import '../core/models.dart';
import 'scan_view.dart';
export 'scan_view.dart';

@JS('nwlFaceStart')
external JSPromise<JSString> _start(web.HTMLVideoElement video);
@JS('nwlFacePoll')
external String _poll();
@JS('nwlFaceCapture')
external String _capture();
@JS('nwlFaceStop')
external void _stop();

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
  final guide = FaceScanGuide();
  BlinkGate get gate => guide.blink;
  CaptureCountdown get countdown => guide.countdown;
  final id = 'nwl-camera-${DateTime.now().microsecondsSinceEpoch}';
  web.HTMLVideoElement? cameraElement;
  Timer? timer;
  Timer? scanTimeout;
  bool busy = false, found = false, matched = false, foreground = true;
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
      generation++;
      scanTimeout?.cancel();
      timer?.cancel();
      _stop();
      guide.reset();
      setState(
        () => error =
            'ตรวจใบหน้าไม่สำเร็จภายใน 30 วินาที กรุณาจัดใบหน้าให้อยู่ในกรอบแล้วลองใหม่',
      );
    });
    try {
      final video = cameraElement;
      if (video == null) throw StateError('Camera element not created');
      await _start(video).toDart;
      if (!mounted || ticket != generation || !foreground) return;
      setState(() => cameraReady = true);
      timer?.cancel();
      timer = Timer.periodic(
        const Duration(milliseconds: 180),
        (_) => analyze(),
      );
    } catch (_) {
      if (mounted && ticket == generation) {
        scanTimeout?.cancel();
        setState(
          () => error =
              'เปิดกล้องไม่ได้ กรุณาอนุญาตกล้องในเบราว์เซอร์ แล้วกดลองใหม่',
        );
      }
    }
  }

  void analyze() {
    if (busy || error.isNotEmpty || !foreground) return;
    try {
      final j = jsonDecode(_poll()) as Map<String, dynamic>;
      if (j.isEmpty) return;
      final ready = guide.observe(
        now: DateTime.now(),
        suitable: j['one'] == true,
        left: (j['left'] as num?)?.toDouble(),
        right: (j['right'] as num?)?.toDouble(),
        guidance: switch (j['hint']) {
          'closer' => 'ขยับใบหน้าเข้ามาใกล้อีกนิด',
          'back' => 'ขยับออกเล็กน้อย ให้เห็นใบหน้าครบ',
          'center' => 'จัดใบหน้าให้อยู่กลางกรอบ',
          'multiple' => 'ให้มีใบหน้าในกรอบเพียงคนเดียว',
          _ => 'นำใบหน้าเข้ากรอบ',
        },
      );
      setState(() => found = j['one'] == true);
      if (ready && gate.claim(foreground: foreground, fresh: true)) {
        unawaited(capture());
      }
    } catch (_) {
      setState(() => error = 'อ่านใบหน้าไม่สำเร็จ กรุณายืนยันและสแกนใหม่');
      timer?.cancel();
    }
  }

  Future<void> capture() async {
    if (busy || !foreground) return;
    scanTimeout?.cancel();
    setState(() => busy = true);
    timer?.cancel();
    Uint8List? bytes;
    final ticket = generation;
    try {
      final data = _capture();
      final captured = DateTime.now();
      bytes = base64Decode(data.split(',').last);
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
    foreground = state == AppLifecycleState.resumed;
    widget.controller.setForeground(foreground);
    if (!foreground) {
      generation++;
      scanTimeout?.cancel();
      timer?.cancel();
      _stop();
      guide.reset();
      if (mounted) {
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
                    found = false;
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
              video.style.objectFit = 'cover';
              video.style.transform = 'scaleX(-1)';
              unawaited(start());
            },
          ),
        ),
      ),
    ),
  );
}
