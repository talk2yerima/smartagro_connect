import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A farm landscape (sun, rolling hills, crop rows) drawn in code for the
/// green brand header. Vector-drawn instead of a photo: no download, no
/// extra app size, sharp on every screen, and it follows the brand colours.
class FarmlandIllustration extends StatelessWidget {
  const FarmlandIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: CustomPaint(painter: _FarmlandPainter(), size: Size.infinite),
    );
  }
}

class _FarmlandPainter extends CustomPainter {
  const _FarmlandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sun with a soft glow, top right.
    final sunCenter = Offset(w * 0.82, h * 0.30);
    final sunR = math.min(w, h) * 0.10;
    canvas.drawCircle(
      sunCenter,
      sunR * 2.2,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.golden.withValues(alpha: 0.30),
          AppColors.golden.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: sunCenter, radius: sunR * 2.2)),
    );
    canvas.drawCircle(sunCenter, sunR,
        Paint()..color = AppColors.golden.withValues(alpha: 0.85));

    // Far hill.
    final far = Path()
      ..moveTo(0, h * 0.70)
      ..cubicTo(w * 0.25, h * 0.52, w * 0.45, h * 0.60, w * 0.62, h * 0.58)
      ..cubicTo(w * 0.80, h * 0.56, w * 0.92, h * 0.50, w, h * 0.54)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = Colors.white.withValues(alpha: 0.08));

    // Middle hill.
    final mid = Path()
      ..moveTo(0, h * 0.80)
      ..cubicTo(w * 0.30, h * 0.66, w * 0.55, h * 0.78, w * 0.75, h * 0.72)
      ..cubicTo(w * 0.88, h * 0.68, w * 0.95, h * 0.70, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        mid, Paint()..color = AppColors.lightGreen.withValues(alpha: 0.22));

    // Front field with crop rows running into the distance.
    final fieldTop = h * 0.84;
    final field = Path()
      ..moveTo(0, fieldTop)
      ..quadraticBezierTo(w * 0.5, h * 0.78, w, fieldTop)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        field, Paint()..color = AppColors.deepGreen.withValues(alpha: 0.55));

    canvas.save();
    canvas.clipPath(field);
    final rows = Paint()
      ..color = AppColors.lightGreen.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final vanishing = Offset(w * 0.5, h * 0.70);
    for (var i = -6; i <= 6; i++) {
      final bottom = Offset(w * 0.5 + i * w * 0.12, h * 1.02);
      canvas.drawLine(vanishing, bottom, rows);
    }
    canvas.restore();

    // A few young plants on the middle hill: a stem and two leaves each.
    final stem = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final leaf = Paint()..color = Colors.white.withValues(alpha: 0.40);
    final unit = h * 0.035;
    for (final x in [0.10, 0.17, 0.25]) {
      final base = Offset(w * x, h * 0.80 - (x - 0.10) * h * 0.28);
      final top = base.translate(0, -unit * 2.2);
      canvas.drawLine(base, top, stem);
      for (final dir in [-1.0, 1.0]) {
        final start = base.translate(0, -unit * (dir < 0 ? 1.4 : 1.0));
        final tip = start.translate(dir * unit * 1.3, -unit * 0.9);
        canvas.drawPath(
          Path()
            ..moveTo(start.dx, start.dy)
            ..quadraticBezierTo(start.dx + dir * unit * 0.2,
                tip.dy - unit * 0.3, tip.dx, tip.dy)
            ..quadraticBezierTo(tip.dx - dir * unit * 0.2,
                start.dy + unit * 0.1, start.dx, start.dy)
            ..close(),
          leaf,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
