
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ContourPainter extends CustomPainter {
  final List<Offset> contour;
  final List<Offset> corners;
  final Size previewSize;
  final int? sensorOrientation;

  ContourPainter({
    required this.contour,
    required this.corners,
    required this.previewSize,
    required this.sensorOrientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint("Painting contour on camera area only");
    if (contour.isEmpty) {
      debugPrint("Contour is empty, nothing to draw");
      return;
    }

    final contourPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool firstPoint = true;
    for (final point in contour) {
      // لا نحتاج offset هنا لأن الـ Positioned خلاص حط الـ widget في المكان الصح
      final x = point.dx;
      final y = point.dy;
      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, contourPaint);

    final pointPaint = Paint()..color = Colors.green;
    for (final point in contour) {
      final x = point.dx;
      final y = point.dy;
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    final cornerPaint = Paint()..color = Colors.red;
    for (final corner in corners) {
      final x = corner.dx;
      final y = corner.dy;
      canvas.drawCircle(Offset(x, y), 6, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ContourPainter oldDelegate) {
    return oldDelegate.contour != contour ||
        oldDelegate.corners != corners ||
        oldDelegate.sensorOrientation != sensorOrientation;
  }
}

class LinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  LinePainter({
    required this.start,
    required this.end,
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}