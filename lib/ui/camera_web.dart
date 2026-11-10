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
  final gate = BlinkGate();
  final id = 'nwl-camera-${DateTime.now().microsecondsSinceEpoch}';
  web.HTMLVideoElement? cameraElement;
  Timer? timer;
  bool busy = false, found = false, matched = false, foreground = true;
  int generation = 0;
  String error = '', stage = 'กำลังเปิดกล้องและเตรียมตัวตรวจใบหน้า…';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> start() async {
    final ticket = ++generation;
    gate.reset();
    try {
      final video = cameraElement;
      if (video == null) throw StateError('Camera element not created');
      await _start(video).toDart;
      if (!mounted || ticket != generation || !foreground) return;
      setState(() => stage = 'อยู่ในที่สว่าง แล้วกะพริบตาหนึ่งครั้ง');
      timer?.cancel();
      timer = Timer.periodic(
        const Duration(milliseconds: 180),
        (_) => analyze(),
      );
    } catch (_) {
      if (mounted && ticket == generation) {
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
      gate.observe(
        (j['left'] as num?)?.toDouble(),
        (j['right'] as num?)?.toDouble(),
        oneFace: j['one'] == true,
      );
      setState(() => found = j['one'] == true);
      if (gate.claim(foreground: foreground, fresh: true)) unawaited(capture());
    } catch (_) {
      setState(() => error = 'อ่านใบหน้าไม่สำเร็จ กรุณายืนยันและสแกนใหม่');
      timer?.cancel();
    }
  }

  Future<void> capture() async {
    if (busy || !foreground) return;
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
      if (mounted) Navigator.pop(context);
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
      timer?.cancel();
      _stop();
      gate.reset();
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
          found: found,
          blink: gate.complete,
          error: error,
          stage: stage,
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
