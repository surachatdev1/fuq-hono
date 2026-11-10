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

/// A decorative flat clock mark; attendance times are shown as text separately.
class TimeArtwork extends StatelessWidget {
  const TimeArtwork({super.key, this.size = 112});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: MotionReveal(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _FlatTimePainter()),
      ),
    ),
  );
}

class _FlatTimePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final fill = Paint()..color = const Color(0xFFE7EEFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 5, 90, 90),
        const Radius.circular(24),
      ),
      fill,
    );
    canvas.drawCircle(const Offset(50, 48), 29, Paint()..color = Colors.white);
    final stroke = Paint()
      ..color = const Color(0xFF245BDB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(50, 48), 29, stroke);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final direction = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        const Offset(50, 48) + direction * 23,
        const Offset(50, 48) + direction * 25,
        stroke..strokeWidth = 1.5,
      );
    }
    stroke.strokeWidth = 3;
    canvas.drawPath(
      Path()
        ..moveTo(50, 31)
        ..lineTo(50, 48)
        ..lineTo(62, 55),
      stroke,
    );
    canvas.drawCircle(
      const Offset(74, 75),
      13,
      Paint()..color = const Color(0xFF347568),
    );
    canvas.drawPath(
      Path()
        ..moveTo(68, 75)
        ..lineTo(72, 79)
        ..lineTo(80, 71),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FlatTimePainter oldDelegate) => false;
}
