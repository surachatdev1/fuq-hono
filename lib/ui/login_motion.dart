import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/models.dart';
import 'design.dart';

/// Artwork is a single local 3D sprite atlas. No video, CDN or new runtime package.
class LoginMotionPage extends StatefulWidget {
  const LoginMotionPage({super.key, required this.stage});
  final LoginStage stage;
  @override
  State<LoginMotionPage> createState() => _LoginMotionPageState();
}

class _LoginMotionPageState extends State<LoginMotionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  ImageStream? stream;
  ImageStreamListener? listener;
  ImageInfo? artwork;
  bool reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduced) {
      motion.stop();
    } else if (!motion.isAnimating) {
      motion.repeat(reverse: true);
    }
    if (stream == null) {
      stream = const AssetImage(
        'assets/motion/login-hands.png',
      ).resolve(createLocalImageConfiguration(context));
      listener = ImageStreamListener(
        (info, synchronous) {
          if (!mounted) {
            info.dispose();
            return;
          }
          setState(() {
            artwork?.dispose();
            artwork = info;
          });
        },
        onError: (Object error, StackTrace? stack) {
          // Text status remains accessible even if artwork cannot be decoded.
        },
      );
      stream!.addListener(listener!);
    }
  }

  @override
  void dispose() {
    if (listener != null) stream?.removeListener(listener!);
    artwork?.dispose();
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.stage == LoginStage.connected;
    return BlockSemantics(
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.15),
              radius: 1,
              colors: [Color(0xFF20283C), ink],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 740),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'nwl',
                                style: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 25,
                                  letterSpacing: 1,
                                  color: paper,
                                ),
                              ),
                              SizedBox(height: (height * .09).clamp(20, 90)),
                              SizedBox(
                                height: (height * .46).clamp(200, 400),
                                width: double.infinity,
                                child: ExcludeSemantics(
                                  child: AnimatedBuilder(
                                    animation: motion,
                                    builder: (context, _) => CustomPaint(
                                      key: ValueKey(
                                        connected
                                            ? 'connected-hands'
                                            : 'reaching-hands',
                                      ),
                                      painter: _HandsPainter(
                                        image: artwork?.image,
                                        // Auth success resolves the reach, then cuts to a new shot.
                                        reach:
                                            widget.stage == LoginStage.contact
                                            ? 1
                                            : reduced
                                            ? .6
                                            : .12 +
                                                  .7 *
                                                      Curves.easeInOut
                                                          .transform(
                                                            motion.value,
                                                          ),
                                        connected: connected,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Column(
                                    children: [
                                      // Deliberate hard cut: no AnimatedSwitcher, fade or morph.
                                      Text(
                                        connected
                                            ? 'fuck u hono'
                                            : 'connecting people',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'NotoSans',
                                          fontSize: constraints.maxWidth < 360
                                              ? 27
                                              : 34,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        connected
                                            ? 'เชื่อมต่อสำเร็จ กำลังเปิดหน้าหลัก'
                                            : 'กำลังเชื่อมต่อบัญชีของคุณ',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: 120,
                                height: 2,
                                child: connected
                                    ? const ColoredBox(color: mint)
                                    : LinearProgressIndicator(
                                        value: reduced ? .5 : null,
                                        backgroundColor: panel,
                                      ),
                              ),
                              SizedBox(height: (height * .09).clamp(24, 70)),
                              const Text(
                                'EVERYDAY, CONSIDERED.',
                                style: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 9,
                                  color: muted,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HandsPainter extends CustomPainter {
  const _HandsPainter({
    required this.image,
    required this.reach,
    required this.connected,
  });
  final ui.Image? image;
  final double reach;
  final bool connected;
  @override
  void paint(Canvas canvas, Size size) {
    final atlas = image;
    if (atlas == null) return;
    final halfW = atlas.width / 2, halfH = atlas.height / 2;
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (connected) {
      final edge = math.min(size.height, size.width);
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH(0, halfH, halfW, halfH),
        Rect.fromLTWH(
          (size.width - edge) / 2,
          (size.height - edge) / 2,
          edge,
          edge,
        ),
        paint,
      );
    } else {
      final edge = size.width / 2;
      final y = size.height / 2 - edge * .43;
      final shift = (-.03 + .06 * reach) * size.width;
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH(0, 0, halfW, halfH),
        Rect.fromLTWH(shift, y, edge, edge),
        paint,
      );
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH(halfW, 0, halfW, halfH),
        Rect.fromLTWH(edge - shift, y, edge, edge),
        paint,
      );
      if (reach == 1) {
        final center = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(
          center,
          10,
          Paint()
            ..color = mint.withValues(alpha: .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
        canvas.drawCircle(center, 2, Paint()..color = mint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HandsPainter old) =>
      image != old.image || reach != old.reach || connected != old.connected;
}

/// A review-only route. It never creates a session or sends an attendance request.
class LoginMotionPreview extends StatefulWidget {
  const LoginMotionPreview({super.key});
  @override
  State<LoginMotionPreview> createState() => _LoginMotionPreviewState();
}

class _LoginMotionPreviewState extends State<LoginMotionPreview> {
  LoginStage stage = LoginStage.connecting;
  final timers = <Timer>[];
  @override
  void initState() {
    super.initState();
    play();
  }

  void stop() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }

  void play() {
    stop();
    stage = LoginStage.connecting;
    timers.add(
      Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => stage = LoginStage.contact);
      }),
    );
    timers.add(
      Timer(const Duration(milliseconds: 2720), () {
        if (mounted) setState(() => stage = LoginStage.connected);
      }),
    );
  }

  void select(LoginStage next) {
    stop();
    setState(() => stage = next);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Material(
            color: ink,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'ตัวอย่างเท่านั้น ไม่ได้เข้าสู่ระบบ',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(play);
                    },
                    child: const Text('เล่นอีกครั้ง'),
                  ),
                  TextButton(
                    onPressed: () => select(LoginStage.connecting),
                    child: const Text('กำลังเชื่อมต่อ'),
                  ),
                  TextButton(
                    onPressed: () => select(LoginStage.connected),
                    child: const Text('สำเร็จ'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: LoginMotionPage(stage: stage)),
        ],
      ),
    ),
  );
}
