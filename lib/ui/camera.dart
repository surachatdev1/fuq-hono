import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';

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
  final detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final gate = BlinkGate();
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
      if (mounted && ticket == generation)
        setState(
          () => error = e is CameraException
              ? 'เปิดกล้องไม่ได้ กรุณาอนุญาตกล้องในตั้งค่าแล้วกดลองใหม่'
              : friendly(e),
        );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    widget.controller.setForeground(foreground);
    if (!foreground) {
      paused = true;
      gate.reset();
      found = false;
      final old = camera;
      camera = null;
      generation++;
      old?.dispose();
      if (mounted)
        setState(
          () => error = 'การสแกนหยุดเมื่อออกจากแอป กรุณายืนยันและสแกนใหม่',
        );
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
        frame.planes.length != 1)
      return;
    detecting = true;
    final ticket = generation;
    final received = DateTime.now();
    try {
      final format = InputImageFormatValue.fromRawValue(frame.format.raw);
      if (format != InputImageFormat.nv21 &&
          format != InputImageFormat.bgra8888)
        throw const AppFailure('รูปแบบภาพกล้องไม่รองรับ');
      // Portrait capture is locked; reject other device orientations for a fresh challenge.
      if (cam.value.deviceOrientation != DeviceOrientation.portraitUp) {
        gate.reset();
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
      gate.observe(
        face?.leftEyeOpenProbability,
        face?.rightEyeOpenProbability,
        oneFace: suitable,
      );
      setState(() => found = suitable);
      if (gate.claim(
        foreground: foreground,
        fresh: DateTime.now().difference(received) < const Duration(seconds: 1),
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
      if (!mounted || !foreground || captureTicket != generation)
        throw const AppFailure('กรุณายืนยันและสแกนใหม่');
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
          if (mounted)
            setState(() {
              stage = text;
              matched = identity;
            });
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
    gate.reset();
    found = false;
    matched = false;
    setState(() {
      error = '';
      stage = 'อยู่ในที่สว่าง แล้วกะพริบตาหนึ่งครั้ง';
    });
    if (camera == null || paused) {
      await initCamera();
    } else if (!camera!.value.isStreamingImages) {
      try {
        await camera!.startImageStream(analyze);
      } catch (_) {
        if (mounted)
          setState(
            () => error = 'เริ่มกล้องใหม่ไม่สำเร็จ กรุณากลับไปเริ่มใหม่',
          );
      }
    }
  }

  @override
  void dispose() {
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
          found: found,
          blink: gate.complete,
          error: error,
          stage: stage,
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

// Pure Flutter presentation used both by the live camera and rendered UI tests.
class ScanView extends StatelessWidget {
  const ScanView({
    super.key,
    required this.punch,
    required this.place,
    required this.preview,
    this.matched = false,
    this.busy = false,
    this.found = false,
    this.blink = false,
    this.error = '',
    this.stage = '',
    this.onRetry,
    this.onBack,
  });
  final Punch punch;
  final Place place;
  final Widget preview;
  final bool matched, busy, found, blink;
  final String error, stage;
  final VoidCallback? onRetry, onBack;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: mint,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'หมุดที่เลือก · ${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: (c.maxHeight * .51).clamp(200, 370),
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: .76,
                        heightFactor: .88,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: error.isNotEmpty ? amber : mint,
                              width: 2,
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.elliptical(180, 240),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 22,
                runSpacing: 10,
                children: [
                  _proof('พบใบหน้า', found),
                  _proof('กะพริบตา', blink),
                ],
              ),
              const SizedBox(height: 20),
              Icon(
                error.isNotEmpty
                    ? Icons.info_outline_rounded
                    : matched
                    ? Icons.check_circle_outline_rounded
                    : Icons.face_retouching_natural,
                color: error.isNotEmpty ? amber : mint,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                error.isNotEmpty
                    ? 'ยืนยันไม่สำเร็จ'
                    : matched
                    ? 'ใบหน้าตรงกัน'
                    : 'มองกล้อง แล้วกะพริบตา',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: error.isNotEmpty ? amber : paper,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                error.isNotEmpty ? error : stage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 20),
              if (busy) ...[
                const LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ไม่ต้องกดยืนยันซ้ำ',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
              if (error.isNotEmpty)
                PrimaryButton(
                  'ยืนยันและสแกนใหม่',
                  onPressed: onRetry,
                  icon: Icons.refresh_rounded,
                ),
              if (!busy)
                TextButton(
                  onPressed: onBack,
                  child: const Text('กลับหน้าหลัก'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _proof(String label, bool done) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        done
            ? Icons.check_circle_outline_rounded
            : Icons.radio_button_unchecked,
        size: 16,
        color: done ? mint : muted,
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: done ? paper : muted)),
    ],
  );
}
