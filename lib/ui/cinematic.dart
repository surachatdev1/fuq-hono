import 'dart:async';

import 'package:flutter/material.dart';

import '../core/controller.dart';
import 'artwork_image.dart';
import 'design.dart';

class MascotArt extends StatelessWidget {
  const MascotArt(this.pose, {super.key, this.fit = BoxFit.contain});
  final String pose;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image(
      image: artworkImage('$cinematicArt/$pose.webp'),
      fit: fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    ),
  );
}

class CinematicSurface extends StatelessWidget {
  const CinematicSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: cinematicPanel,
      border: Border.all(color: cinematicLine),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class CinematicSplash extends StatelessWidget {
  const CinematicSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(color: midnight)),
        const Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: .72,
            widthFactor: 1,
            child: MascotArt('energy', fit: BoxFit.cover),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Brand(),
                const Spacer(),
                const MotionReveal(child: ConnectingTitle(centered: true)),
                const Spacer(flex: 2),
                const Text('กำลังเตรียมพื้นที่ทำงานของคุณ'),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class ConnectingTitle extends StatelessWidget {
  const ConnectingTitle({super.key, this.centered = false});
  final bool centered;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: 'Connecting people',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [_line('CONNECTING', 46), _line('PEOPLE', 75)],
    ),
  );

  Widget _line(String text, double size) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: centered ? Alignment.center : Alignment.centerLeft,
    child: Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontFamily: 'NotoSans',
        color: electricLime,
        fontSize: size,
        height: 1,
        letterSpacing: -size * .055,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class CinematicLoginLayout extends StatelessWidget {
  const CinematicLoginLayout({
    super.key,
    required this.children,
    required this.engaged,
  });

  final List<Widget> children;
  final bool engaged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) {
      final desktop = viewport.maxWidth >= 880;
      final short = viewport.maxHeight < 740;
      final inset = desktop ? 40.0 : 18.0;
      final form = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: desktop ? 426 : 440),
        child: CinematicSurface(
          padding: EdgeInsets.fromLTRB(
            desktop ? 28 : 18,
            desktop ? 22 : 14,
            desktop ? 28 : 18,
            desktop ? 18 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1260,
              minHeight: viewport.maxHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: short ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (desktop) ...[
                    const Row(
                      children: [
                        Brand(),
                        SizedBox(width: 20),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _LoginHero(height: short ? 535 : 610)),
                        const SizedBox(width: 30),
                        form,
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      height: short ? 106 : 156,
                      child: _LoginMasthead(engaged: engaged),
                    ),
                    const SizedBox(height: 10),
                    Center(child: form),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: midnight,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: cinematicLine),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.60, .58),
              radius: .90,
              colors: [Color(0xFF2C3A75), Color(0xFF191F43), midnight],
            ),
          ),
        ),
        const Positioned(
          top: -87,
          right: -81,
          width: 372,
          height: 430,
          child: Opacity(opacity: .82, child: MascotArt('ribbon')),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [midnight, Color(0x00080F25), Color(0xB0080F25)],
              stops: [0, .70, 1],
            ),
          ),
        ),
        const Positioned.fill(
          top: 132,
          right: 16,
          bottom: -52,
          child: Align(
            alignment: Alignment.bottomRight,
            child: MotionReveal(child: MascotArt('hero')),
          ),
        ),
        const Positioned(
          left: 34,
          right: 28,
          top: 33,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConnectingTitle(),
              SizedBox(height: 13),
              Text(
                'เชื่อมต่อทีมงาน\nให้ทำงานได้ทุกที่ ทุกเวลา',
                style: TextStyle(fontSize: 17, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LoginMasthead extends StatelessWidget {
  const _LoginMasthead({required this.engaged});
  final bool engaged;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: engaged ? 1 : 0),
          duration: reduceCinematicMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 230),
          builder: (context, value, child) => Transform.translate(
            offset: Offset(-5 * value, -3 * value),
            child: child,
          ),
          child: const MascotArt('login'),
        ),
      ),
      const Align(alignment: Alignment.centerLeft, child: Brand()),
    ],
  );
}

class TodayClock extends StatefulWidget {
  const TodayClock({super.key, required this.compact});
  final bool compact;

  @override
  State<TodayClock> createState() => _TodayClockState();
}

class _TodayClockState extends State<TodayClock> {
  Timer? ticker;
  DateTime now = bangkokNow();

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final updated = bangkokNow();
      if (updated.minute != now.minute || updated.hour != now.hour) {
        setState(() => now = updated);
      }
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return Text(
      '$hour:$minute',
      semanticsLabel: '$hour นาฬิกา $minute นาที เวลากรุงเทพฯ',
      style: TextStyle(
        color: paper,
        fontFamily: 'NotoSans',
        fontSize: widget.compact ? 46 : 62,
        letterSpacing: -2.5,
        height: 1.1,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class DashboardBanner extends StatelessWidget {
  const DashboardBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.clock,
  });

  final String title;
  final String subtitle;
  final Widget clock;

  @override
  Widget build(BuildContext context) => Container(
    height: 212,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      border: Border.all(color: cinematicLine),
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFF142755), Color(0xFF2D5092), Color(0xFF18172F)],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          right: -12,
          bottom: -18,
          top: 0,
          width: 365,
          child: _DashboardArt(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle, style: const TextStyle(color: paper)),
                const SizedBox(height: 10),
                clock,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DashboardArt extends StatefulWidget {
  const _DashboardArt();

  @override
  State<_DashboardArt> createState() => _DashboardArtState();
}

class _DashboardArtState extends State<_DashboardArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceCinematicMotion(context)) {
      drift.reset();
    } else if (!drift.isAnimating) {
      drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: drift,
    child: const Align(
      alignment: Alignment.bottomRight,
      child: MascotArt('dashboard'),
    ),
    builder: (_, child) => Transform.translate(
      offset: Offset(0, -4 * Curves.easeInOut.transform(drift.value)),
      child: child,
    ),
  );
}

class AttendanceCelebration extends StatelessWidget {
  const AttendanceCelebration({super.key, required this.label, this.time});
  final String label;
  final String? time;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ลงเวลาเรียบร้อย'),
    content: SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 168,
            child: MotionReveal(child: MascotArt('success')),
          ),
          const SizedBox(height: 14),
          Text(label, textAlign: TextAlign.center),
          if (time != null)
            Text(time!, style: Theme.of(context).textTheme.headlineLarge),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('กลับหน้าวันนี้'),
      ),
    ],
  );
}
