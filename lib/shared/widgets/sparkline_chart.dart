import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The price before the last reported change, derived from [current] and
/// [changePct]. Returns [current] when the change can't be undone (−100%).
double previousPrice(num current, double changePct) {
  final factor = 1 + changePct / 100;
  return factor <= 0 ? current.toDouble() : current / factor;
}

/// The two real points behind a reported change: previous price, then the
/// current one. No price history is stored yet, so charts show this actual
/// step instead of an invented multi-day series.
List<double> trendFromChange(double changePct, {num current = 100}) =>
    [previousPrice(current, changePct), current.toDouble()];

/// A mini sparkline (line chart) widget drawn with [CustomPaint].
///
/// [data] is a list of raw values that are auto-normalized to the canvas.
/// [color] is the stroke/fill color.
/// [filled] draws a translucent fill under the line when true.
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.data,
    required this.color,
    this.height = 40,
    this.width = 80,
    this.strokeWidth = 1.8,
    this.filled = true,
  });

  final List<double> data;
  final Color color;
  final double height;
  final double width;
  final double strokeWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(width: width, height: height);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: color,
          strokeWidth: strokeWidth,
          filled: filled,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });

  final List<double> data;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;

    // If all values are identical, draw a flat horizontal line at midpoint.
    final effectiveRange = range == 0 ? 1.0 : range;

    double normalize(double value) {
      // Invert Y: higher values should appear at top of canvas.
      return size.height - ((value - minVal) / effectiveRange) * size.height;
    }

    final xStep = size.width / (data.length - 1);

    Offset pointAt(int index) {
      return Offset(index * xStep, normalize(data[index]));
    }

    final path = Path();
    path.moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < data.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    if (filled) {
      final fillPath = Path()..addPath(path, Offset.zero);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return !identical(oldDelegate.data, data) || oldDelegate.color != color;
  }
}
