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

class TimeArtwork extends StatelessWidget {
  const TimeArtwork({super.key, this.size = 112});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: MotionReveal(
      child: Image.asset(
        'assets/motion/time-orbit.webp',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
