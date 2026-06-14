import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Generates 10 plausible price points given a percentage change.
List<double> mockSparklineFromChange(double changePct) {
  final step = changePct / 10;
  var v = 100.0;
  final result = <double>[];
  for (var i = 0; i < 10; i++) {
    v += step + (i.isEven ? 1.2 : -0.7);
    result.add(v);
  }
  return result;
}

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
