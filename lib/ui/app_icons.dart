import 'dart:math' as math;
import 'package:flutter/material.dart';

// One rounded 1.65-unit stroke vocabulary for the attendance workflow.
class NwlIcon extends StatelessWidget {
  const NwlIcon(this.icon, {super.key, this.color, this.size});
  final IconData icon;
  final Color? color;
  final double? size;
  String? get glyph {
    if ([Icons.grid_view_outlined, Icons.grid_view_rounded].contains(icon)) {
      return 'grid';
    }
    if ([
      Icons.location_on,
      Icons.location_on_outlined,
      Icons.add_location_alt_outlined,
    ].contains(icon)) {
      return 'pin';
    }
    if ([
      Icons.history_rounded,
      Icons.schedule,
      Icons.schedule_rounded,
      Icons.alarm_rounded,
    ].contains(icon)) {
      return 'clock';
    }
    if ([
      Icons.today_outlined,
      Icons.calendar_month_outlined,
      Icons.event_available_outlined,
      Icons.event_busy_outlined,
    ].contains(icon)) {
      return 'calendar';
    }
    if ([
      Icons.face_retouching_natural,
      Icons.camera_front_rounded,
    ].contains(icon)) {
      return 'face';
    }
    if ([Icons.notifications_active_outlined].contains(icon)) return 'bell';
    if ([Icons.login_rounded, Icons.logout_rounded].contains(icon)) {
      return icon == Icons.login_rounded ? 'in' : 'out';
    }
    if ([Icons.refresh_rounded].contains(icon)) return 'refresh';
    if ([
      Icons.check_circle_outline_rounded,
      Icons.check_circle_rounded,
    ].contains(icon)) {
      return 'check';
    }
    if ([Icons.info_outline_rounded].contains(icon)) return 'info';
    if ([Icons.shield_outlined, Icons.security_rounded].contains(icon)) {
      return 'shield';
    }
    if ([Icons.arrow_forward_rounded].contains(icon)) return 'arrow';
    if ([Icons.link_rounded].contains(icon)) return 'link';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 22;
    final tint = (color ?? theme.color ?? Colors.white).withValues(
      alpha: theme.opacity ?? 1,
    );
    final shape = glyph;
    if (shape == null) return Icon(icon, size: dimension, color: tint);
    return ExcludeSemantics(
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension: dimension,
          child: CustomPaint(painter: _GlyphPainter(shape, tint)),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.shape, this.color);
  final String shape;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), p);
    void path(Path path) => canvas.drawPath(path, p);
    if (shape == 'grid') {
      for (final x in [4.0, 14.0]) {
        for (final y in [4.0, 14.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 6, 6),
              const Radius.circular(1.7),
            ),
            p,
          );
        }
      }
    } else if (shape == 'pin') {
      path(
        Path()
          ..moveTo(12, 21)
          ..cubicTo(9, 17, 5, 13, 5, 9)
          ..arcToPoint(const Offset(19, 9), radius: const Radius.circular(7))
          ..cubicTo(19, 13, 15, 17, 12, 21),
      );
      canvas.drawCircle(const Offset(12, 9), 2.2, p);
    } else if (shape == 'clock') {
      canvas.drawCircle(const Offset(12, 12), 8.4, p);
      line(12, 7.5, 12, 12);
      line(12, 12, 15.5, 14);
      canvas.drawCircle(const Offset(12, 12), .8, Paint()..color = color);
    } else if (shape == 'calendar') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 5.5, 16, 15),
          const Radius.circular(3),
        ),
        p,
      );
      line(8, 3.5, 8, 7.5);
      line(16, 3.5, 16, 7.5);
      line(4, 10, 20, 10);
      for (final x in [8.0, 12.0, 16.0]) {
        canvas.drawCircle(Offset(x, 14.2), .8, Paint()..color = color);
      }
      line(8, 17.5, 12, 17.5);
    } else if (shape == 'face') {
      path(
        Path()
          ..moveTo(8, 3.5)
          ..lineTo(5.5, 3.5)
          ..quadraticBezierTo(3.5, 3.5, 3.5, 5.5)
          ..lineTo(3.5, 8),
      );
      path(
        Path()
          ..moveTo(16, 3.5)
          ..lineTo(18.5, 3.5)
          ..quadraticBezierTo(20.5, 3.5, 20.5, 5.5)
          ..lineTo(20.5, 8),
      );
      path(
        Path()
          ..moveTo(3.5, 16)
          ..lineTo(3.5, 18.5)
          ..quadraticBezierTo(3.5, 20.5, 5.5, 20.5)
          ..lineTo(8, 20.5),
      );
      path(
        Path()
          ..moveTo(16, 20.5)
          ..lineTo(18.5, 20.5)
          ..quadraticBezierTo(20.5, 20.5, 20.5, 18.5)
          ..lineTo(20.5, 16),
      );
      line(8, 9, 8, 10);
      line(16, 9, 16, 10);
      path(
        Path()
          ..moveTo(8, 15)
          ..quadraticBezierTo(12, 18, 16, 15),
      );
    } else if (shape == 'bell') {
      path(
        Path()
          ..moveTo(5, 17)
          ..lineTo(6.5, 14.5)
          ..lineTo(6.5, 10)
          ..arcToPoint(
            const Offset(17.5, 10),
            radius: const Radius.circular(5.5),
          )
          ..lineTo(17.5, 14.5)
          ..lineTo(19, 17)
          ..close(),
      );
      path(
        Path()
          ..moveTo(9.5, 20)
          ..quadraticBezierTo(12, 22, 14.5, 20),
      );
      line(12, 2.5, 12, 4);
    } else if (shape == 'in' || shape == 'out') {
      final entrance = shape == 'in';
      path(
        Path()
          ..moveTo(entrance ? 14 : 10, 4)
          ..lineTo(entrance ? 20 : 4, 4)
          ..lineTo(entrance ? 20 : 4, 20)
          ..lineTo(entrance ? 14 : 10, 20),
      );
      line(entrance ? 3 : 10, 12, entrance ? 14 : 21, 12);
      path(
        Path()
          ..moveTo(entrance ? 10 : 17, 8)
          ..lineTo(entrance ? 14 : 21, 12)
          ..lineTo(entrance ? 10 : 17, 16),
      );
    } else if (shape == 'refresh') {
      canvas.drawArc(
        const Rect.fromLTWH(4, 4, 16, 16),
        -.5,
        math.pi * 1.6,
        false,
        p,
      );
      path(
        Path()
          ..moveTo(19.5, 3.5)
          ..lineTo(19.5, 8.5)
          ..lineTo(14.5, 8.5),
      );
    } else if (shape == 'check' || shape == 'info') {
      canvas.drawCircle(const Offset(12, 12), 8.4, p);
      if (shape == 'check') {
        path(
          Path()
            ..moveTo(7.5, 12)
            ..lineTo(10.5, 15)
            ..lineTo(16.5, 9),
        );
      } else {
        line(12, 11, 12, 16);
        canvas.drawCircle(const Offset(12, 7.5), .85, Paint()..color = color);
      }
    } else if (shape == 'shield') {
      path(
        Path()
          ..moveTo(12, 3)
          ..lineTo(20, 6)
          ..lineTo(19, 13)
          ..quadraticBezierTo(18, 18, 12, 21)
          ..quadraticBezierTo(6, 18, 5, 13)
          ..lineTo(4, 6)
          ..close(),
      );
      path(
        Path()
          ..moveTo(8.5, 11.5)
          ..lineTo(11, 14)
          ..lineTo(15.5, 9.5),
      );
    } else if (shape == 'arrow') {
      line(4, 12, 20, 12);
      path(
        Path()
          ..moveTo(14, 6)
          ..lineTo(20, 12)
          ..lineTo(14, 18),
      );
    } else if (shape == 'link') {
      path(
        Path()
          ..moveTo(9, 15)
          ..lineTo(7, 17)
          ..cubicTo(3, 21, 0, 15, 4, 12)
          ..lineTo(7, 9)
          ..quadraticBezierTo(10, 6, 13, 9),
      );
      path(
        Path()
          ..moveTo(15, 9)
          ..lineTo(17, 7)
          ..cubicTo(21, 3, 24, 9, 20, 12)
          ..lineTo(17, 15)
          ..quadraticBezierTo(14, 18, 11, 15),
      );
      line(8.5, 15.5, 15.5, 8.5);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      color != old.color || shape != old.shape;
}
