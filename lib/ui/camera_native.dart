import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';
import 'scan_view.dart';
export 'scan_view.dart';

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
  CameraController? camera;
  Timer? scanTimeout;
  final detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final guide = FaceScanGuide();
  BlinkGate get gate => guide.blink;
  CaptureCountdown get countdown => guide.countdown;
  bool detecting = false,
      busy = false,
      foreground = true,
      matched = false,
      found = false,
      paused = false;
  String error = '', stage = 'อยู่ในที่สว่าง แล้วกะพริบตาหนึ่งครั้ง';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    final ticket = ++generation;
    scanTimeout?.cancel();
    scanTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted || busy || ticket != generation) return;
      generation++;
      final old = camera;
      camera = null;
      old?.dispose();
      guide.reset();
      setState(
        () => error =
            'ตรวจใบหน้าไม่สำเร็จภายใน 30 วินาที กรุณาจัดใบหน้าให้อยู่ในกรอบแล้วลองใหม่',
      );
    });
    try {
      final devices = await availableCameras();
      final fronts = devices.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (fronts.isEmpty) throw const AppFailure('ไม่พบกล้องหน้าในเครื่อง');
      final next = CameraController(
        fronts.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await next.initialize();
      await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || ticket != generation || !foreground) {
        await next.dispose();
        return;
      }
      camera = next;
      paused = false;
      await next.startImageStream(analyze);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(
          () => error = e is CameraException
              ? 'เปิดกล้องไม่ได้ กรุณาอนุญาตกล้องในตั้งค่าแล้วกดลองใหม่'
              : friendly(e),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    widget.controller.setForeground(foreground);
    if (!foreground) {
      scanTimeout?.cancel();
      paused = true;
      guide.reset();
      found = false;
      final old = camera;
      camera = null;
      generation++;
      old?.dispose();
      if (mounted) {
        setState(
          () => error = 'การสแกนหยุดเมื่อออกจากแอป กรุณายืนยันและสแกนใหม่',
        );
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> analyze(CameraImage frame) async {
    final cam = camera;
    if (cam == null ||
        detecting ||
        busy ||
        error.isNotEmpty ||
        !foreground ||
        gate.claimed ||
        frame.planes.length != 1) {
      return;
    }
    detecting = true;
    final ticket = generation;
    final received = DateTime.now();
    try {
      final format = InputImageFormatValue.fromRawValue(frame.format.raw);
      if (format != InputImageFormat.nv21 &&
          format != InputImageFormat.bgra8888) {
        throw const AppFailure('รูปแบบภาพกล้องไม่รองรับ');
      }
      // Portrait capture is locked; reject other device orientations for a fresh challenge.
      if (cam.value.deviceOrientation != DeviceOrientation.portraitUp) {
        guide.reset();
        return;
      }
      final rotation = InputImageRotationValue.fromRawValue(
        cam.description.sensorOrientation,
      );
      if (rotation == null) throw const AppFailure('อ่านทิศทางกล้องไม่ได้');
      final input = InputImage.fromBytes(
        bytes: frame.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: format!,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
      final faces = await detector.processImage(input);
      if (!mounted || ticket != generation || !foreground || busy) return;
      final face = faces.length == 1 ? faces.single : null;
      final suitable =
          face != null &&
          (face.headEulerAngleY ?? 90).abs() < 20 &&
          (face.headEulerAngleZ ?? 90).abs() < 20 &&
          face.boundingBox.width > frame.width * .16;
      final ready = guide.observe(
        now: DateTime.now(),
        suitable: suitable,
        left: face?.leftEyeOpenProbability,
        right: face?.rightEyeOpenProbability,
        guidance: face == null
            ? 'นำใบหน้าเข้ากรอบเพียงคนเดียว'
            : face.boundingBox.width <= frame.width * .16
            ? 'ขยับใบหน้าเข้ามาใกล้อีกนิด'
            : 'มองตรงและจัดใบหน้าให้อยู่กลางกรอบ',
      );
      setState(() => found = suitable);
      if (ready &&
          gate.claim(
            foreground: foreground,
            fresh:
                DateTime.now().difference(received) <
                const Duration(seconds: 1),
          )) {
        await capture();
      }
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = friendly(e));
    } finally {
      detecting = false;
    }
  }

  Future<void> capture() async {
    final cam = camera;
    if (cam == null || busy || !foreground) return;
    scanTimeout?.cancel();
    setState(() {
      busy = true;
      error = '';
      stage = 'เตรียมภาพสด';
    });
    final captureTicket = generation;
    File? file;
    Uint8List? bytes;
    try {
      await cam.stopImageStream();
      if (!foreground) throw const AppFailure('กรุณาสแกนใหม่หลังกลับเข้าแอป');
      final photo = await cam.takePicture();
      file = File(photo.path);
      final captured = DateTime.now();
      bytes = await file.readAsBytes();
      if (!mounted || !foreground || captureTicket != generation) {
        throw const AppFailure('กรุณายืนยันและสแกนใหม่');
      }
      if (widget.controller.demo) {
        setState(() {
          stage = 'โหมดทดลอง · ไม่ส่งรายการจริง';
          busy = false;
        });
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
      try {
        await file?.delete();
      } catch (_) {
        /* temporary image removed on OS cleanup if deletion fails */
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> retry() async {
    if (busy) return;
    guide.reset();
    found = false;
    matched = false;
    setState(() {
      error = '';
      stage = 'อยู่ในที่สว่าง แล้วกะพริบตาหนึ่งครั้ง';
    });
    final old = camera;
    camera = null;
    generation++;
    scanTimeout?.cancel();
    await old?.dispose();
    if (mounted && foreground) await initCamera();
  }

  @override
  void dispose() {
    scanTimeout?.cancel();
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    detector.close();
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
          stage: busy || error.isNotEmpty ? stage : guide.hint,
          countdown: busy || error.isNotEmpty ? null : countdown.remaining,
          onRetry: foreground ? retry : null,
          onBack: busy ? null : () => Navigator.pop(context),
          preview: camera?.value.isInitialized == true
              ? ClipRect(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: camera!.value.aspectRatio > 1
                          ? 1 / camera!.value.aspectRatio
                          : camera!.value.aspectRatio,
                      child: CameraPreview(camera!),
                    ),
                  ),
                )
              : const Center(
                  child: Icon(Icons.videocam_outlined, size: 48, color: muted),
                ),
        ),
      ),
    ),
  );
}
