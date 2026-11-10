import 'dart:math' as math;
import 'package:flutter/material.dart';

class MotionReveal extends StatelessWidget {
  const MotionReveal({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Decorative orbital mark: deliberately has no hands or actual time.
class TimeArtwork extends StatelessWidget {
  const TimeArtwork({super.key, this.size = 112});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: MotionReveal(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _OrbitPainter()),
      ),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .34;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      Offset.zero,
      radius,
      stroke..color = const Color(0xFF435854),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * .68,
      stroke..color = const Color(0xFF2C3C39),
    );
    canvas.save();
    canvas.rotate(-math.pi / 5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.8,
        height: radius * .72,
      ),
      stroke..color = const Color(0xFF8DAF9A),
    );
    canvas.restore();
    final dot = Offset(
      radius * math.cos(-math.pi / 3),
      radius * math.sin(-math.pi / 3),
    );
    canvas.drawCircle(
      dot,
      math.max(2.5, size.width * .018),
      Paint()..color = const Color(0xFFCDE6D0),
    );
    canvas.drawCircle(Offset.zero, 2, Paint()..color = const Color(0xFF8DAF9A));
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}
