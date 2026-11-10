import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/models.dart';
import 'design.dart';

/// Artwork is a single local 3D sprite atlas. No video, CDN or new runtime package.
class AbstractLoginMotionPage extends StatefulWidget {
  const AbstractLoginMotionPage({
    super.key,
    required this.stage,
    this.modal = true,
  });
  final LoginStage stage;
  final bool modal;
  @override
  State<AbstractLoginMotionPage> createState() =>
      _AbstractLoginMotionPageState();
}

class _AbstractLoginMotionPageState extends State<AbstractLoginMotionPage>
    with TickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3500),
  );
  late final AnimationController reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  late final CurvedAnimation captionOpacity = CurvedAnimation(
    parent: reveal,
    curve: const Interval(.55, 1, curve: Curves.easeInOutSine),
  );
  late final Listenable animation = Listenable.merge([motion, reveal]);
  @override
  void initState() {
    super.initState();
    if (widget.stage == LoginStage.connected) reveal.value = 1;
  }

  @override
  void didUpdateWidget(AbstractLoginMotionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage == widget.stage) return;
    if (widget.stage == LoginStage.connected) {
      motion.stop();
      reveal.duration = const Duration(milliseconds: 2300);
      if (reduced) {
        reveal.value = 1;
      } else {
        reveal.forward(from: 0);
      }
    } else if (widget.stage == LoginStage.contact) {
      reachAtContact = waitingReach;
      motion.stop();
      reveal.duration = const Duration(milliseconds: 500);
      if (reduced) {
        reveal.value = 1;
      } else {
        reveal.forward(from: 0);
      }
    } else {
      reveal.stop();
      reveal.value = 0;
      if (widget.stage == LoginStage.connecting && !reduced) {
        motion.value = 0;
        motion.repeat(reverse: true);
      } else {
        motion.stop();
      }
    }
  }

  ImageStream? stream;
  ImageStreamListener? listener;
  ImageInfo? artwork;
  ImageStream? palmStream;
  ImageStreamListener? palmListener;
  ImageInfo? palmArtwork;
  bool reduced = false;
  double reachAtContact = .82;
  double get waitingReach =>
      reduced ? .6 : .12 + .7 * Curves.easeInOutSine.transform(motion.value);
  double get handReach => widget.stage == LoginStage.connecting
      ? waitingReach
      : widget.stage == LoginStage.contact
      ? ui.lerpDouble(
          reachAtContact,
          1,
          Curves.easeInOutSine.transform(reveal.value),
        )!
      : 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduced || widget.stage != LoginStage.connecting) {
      motion.stop();
      if (reduced && widget.stage != LoginStage.connecting) reveal.value = 1;
    } else if (!motion.isAnimating) {
      motion.repeat(reverse: true);
    }
    if (palmStream == null) {
      palmStream = const AssetImage(
        'assets/motion/palm-rise.webp',
      ).resolve(createLocalImageConfiguration(context));
      palmListener = ImageStreamListener((info, synchronous) {
        if (!mounted) {
          info.dispose();
          return;
        }
        setState(() {
          palmArtwork?.dispose();
          palmArtwork = info;
        });
      }, onError: (Object error, StackTrace? stack) {});
      palmStream!.addListener(palmListener!);
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
    if (palmListener != null) palmStream?.removeListener(palmListener!);
    palmArtwork?.dispose();
    captionOpacity.dispose();
    reveal.dispose();
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.stage == LoginStage.connected;
    return BlockSemantics(
      blocking: widget.modal,
      child: Scaffold(
        backgroundColor: const Color(0xFF050C1F),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final width = math.min(constraints.maxWidth, height * .67);
            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Image.asset(
                      'assets/motion/abstract-glass.webp',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      filterQuality: FilterQuality.medium,
                    ),
                    AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        return Semantics(
                          label: connected
                              ? 'fuck u hono'
                              : 'connecting people',
                          child: CustomPaint(
                            key: const ValueKey('poster-type-layer'),
                            painter: _PosterTypePainter(
                              connected: connected,
                              reveal: connected ? reveal.value : 0,
                              drift: reduced ? 0 : motion.value,
                            ),
                          ),
                        );
                      },
                    ),
                    ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) => CustomPaint(
                          key: ValueKey(
                            connected ? 'connected-hands' : 'reaching-hands',
                          ),
                          painter: _HandsPainter(
                            image: artwork?.image,
                            palm: palmArtwork?.image,
                            reach: handReach,
                            reveal: connected ? reveal.value : 0,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 135,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0x00050C1F),
                                const Color(0xFF050C1F).withValues(alpha: .88),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      top: MediaQuery.paddingOf(context).top + 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'nwl',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 25,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE0FFB4),
                            ),
                          ),
                          Text(
                            connected ? 'CONNECTED / 01' : 'CONNECTING / 00',
                            style: const TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 8,
                              letterSpacing: 2.3,
                              color: Color(0xFFE0FFB4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: MediaQuery.paddingOf(context).bottom + 28,
                      child: Semantics(
                        liveRegion: true,
                        child: FadeTransition(
                          opacity: connected
                              ? captionOpacity
                              : const AlwaysStoppedAnimation(1),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                connected
                                    ? 'เชื่อมต่อสำเร็จ กำลังเปิดหน้าหลัก'
                                    : 'กำลังเชื่อมต่อบัญชีของคุณ',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFE0FFB4),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!connected)
                                SizedBox(
                                  width: 80,
                                  height: 2,
                                  child: LinearProgressIndicator(
                                    value: reduced ? .5 : null,
                                    color: const Color(0xFFE0FFB4),
                                    backgroundColor: const Color(0x44304E44),
                                  ),
                                ),
                              const SizedBox(height: 14),
                              const Text(
                                'EVERYDAY, CONSIDERED.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 8,
                                  letterSpacing: 2.5,
                                  color: Color(0xFFCCE8AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Native vector typography stays crisp and sits behind the separately animated hands.
class _PosterTypePainter extends CustomPainter {
  const _PosterTypePainter({
    required this.connected,
    required this.reveal,
    required this.drift,
  });
  final bool connected;
  final double reveal, drift;
  void line(
    Canvas canvas,
    Size size,
    String text,
    double x,
    double y,
    double width,
    double height,
    double alpha,
  ) {
    final type = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 100,
          height: .9,
          letterSpacing: -4,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFE0FFB4).withValues(alpha: alpha),
        ),
      ),
    );
    type.layout();
    canvas.save();
    canvas.translate(size.width * x, size.height * y);
    canvas.transform((Matrix4.identity()..setEntry(0, 1, -.13)).storage);
    canvas.rotate(-.045);
    canvas.scale(
      size.width * width / type.width,
      size.height * height / type.height,
    );
    type.paint(canvas, Offset.zero);
    canvas.restore();
    type.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final waiting = connected
        ? 1 -
              const Interval(
                0,
                .35,
                curve: Curves.easeInOutSine,
              ).transform(reveal)
        : 1.0;
    final success = connected
        ? const Interval(
            .32,
            .92,
            curve: Curves.easeInOutSine,
          ).transform(reveal)
        : 0.0;
    if (waiting > 0) {
      final d = (drift - .5) * .009;
      line(canvas, size, 'CONNECT', .025, .15 + d, 1.04, .22, waiting);
      line(canvas, size, 'ING', .02, .36 + d, .64, .22, waiting);
      line(canvas, size, 'PEOPLE', -.015, .64 - d, 1.09, .24, waiting);
    }
    if (success > 0) {
      line(canvas, size, 'FUCK', .025, .125, 1.03, .27, success);
      line(canvas, size, 'U', .015, .37, .34, .25, success);
      line(canvas, size, 'HONO', -.015, .625, 1.10, .29, success);
    }
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .92, size.height * .07)
        ..lineTo(size.width * 1.03, size.height * .063)
        ..lineTo(size.width * .95, size.height * .16)
        ..lineTo(size.width * .87, size.height * .165)
        ..close(),
      Paint()..color = const Color(0xFFFF665A),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PosterTypePainter old) =>
      connected != old.connected || reveal != old.reveal || drift != old.drift;
}

class _HandsPainter extends CustomPainter {
  const _HandsPainter({
    required this.image,
    required this.palm,
    required this.reach,
    required this.reveal,
  });
  final ui.Image? image, palm;
  final double reach, reveal;
  @override
  void paint(Canvas canvas, Size size) {
    final atlas = image;
    if (atlas == null) return;
    final halfW = atlas.width / 2, halfH = atlas.height / 2;
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final reachOpacity =
        1 -
        const Interval(0, .35, curve: Curves.easeInOutSine).transform(reveal);
    if (reachOpacity > 0) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: reachOpacity),
      );
      final edge = size.width * .62;
      final y = size.height * .49 - edge * .43;
      final gap = .06 * (1 - reach) * size.width;
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH(0, 0, halfW, halfH),
        Rect.fromLTWH(size.width * .5 - edge * .94 - gap, y, edge, edge),
        paint,
      );
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH(halfW, 0, halfW, halfH),
        Rect.fromLTWH(size.width * .5 - edge * .045 + gap, y, edge, edge),
        paint,
      );
      final glow = ((reach - .94) / .06).clamp(0.0, 1.0);
      if (glow > 0) {
        final center = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(
          center,
          10,
          Paint()
            ..color = mint.withValues(alpha: .5 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
        canvas.drawCircle(
          center,
          2,
          Paint()..color = mint.withValues(alpha: glow),
        );
      }
      canvas.restore();
    }
    final lift = const Interval(
      .28,
      1,
      curve: Curves.easeInOutCubic,
    ).transform(reveal);
    if (lift > 0) {
      final hero = palm;
      canvas.saveLayer(
        Offset.zero & size,
        Paint()
          ..color = Colors.white.withValues(alpha: math.min(1, lift * 1.45)),
      );
      // The whole hand rises in a shallow arc, rotates at the wrist and settles.
      canvas.translate(
        size.width * .055 * (1 - lift),
        size.height * .52 * (1 - lift),
      );
      final pivot = Offset(size.width * .5, size.height * .85);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(.105 * (1 - lift));
      canvas.translate(-pivot.dx, -pivot.dy);
      if (hero != null) {
        final fitted = applyBoxFit(
          BoxFit.cover,
          Size(hero.width.toDouble(), hero.height.toDouble()),
          size,
        );
        canvas.drawImageRect(
          hero,
          Alignment.center.inscribe(
            fitted.source,
            Offset.zero & Size(hero.width.toDouble(), hero.height.toDouble()),
          ),
          Alignment.center.inscribe(fitted.destination, Offset.zero & size),
          paint,
        );
      } else {
        final edge = math.min(size.height * .9, size.width * 1.6);
        canvas.drawImageRect(
          atlas,
          Rect.fromLTWH(0, halfH, halfW, halfH),
          Rect.fromLTWH(
            (size.width - edge) / 2,
            size.height - edge,
            edge,
            edge,
          ),
          paint,
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HandsPainter old) =>
      image != old.image ||
      palm != old.palm ||
      reach != old.reach ||
      reveal != old.reveal;
}
