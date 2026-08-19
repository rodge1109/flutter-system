import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomPaddleIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CustomPaddleIcon({Key? key, this.size = 24.0, this.color = Colors.black})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4, // 45 degree tilt
      child: CustomPaint(
        size: Size(size, size),
        painter: PaddlePainter(color: color),
      ),
    );
  }
}

class PaddlePainter extends CustomPainter {
  final Color color;

  PaddlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the paddle head (outlined, thinner)
    final Paint headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07 // Thinner outline
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final double headWidth = size.width * 0.55;
    final double headHeight = size.height * 0.58;
    
    // Slant: bottom part of the head is narrower than the top
    final double topRadius = size.width * 0.15;
    final double bottomRadius = size.width * 0.15; // Control point for the slant
    
    final Path headPath = Path();
    
    // Define the bounding box for the head
    final double left = (size.width - headWidth) / 2;
    final double right = left + headWidth;
    final double top = size.height * 0.02;
    final double bottom = top + headHeight;
    
    // Slanted bottom neck points (where it meets the handle)
    final double handleWidth = size.width * 0.15;
    final double neckLeft = (size.width - handleWidth) / 2 - (size.width * 0.05); // slightly wider than handle
    final double neckRight = (size.width + handleWidth) / 2 + (size.width * 0.05);
    
    headPath.moveTo(left, top + topRadius);
    // Top left curve
    headPath.quadraticBezierTo(left, top, left + topRadius, top);
    // Top right curve
    headPath.lineTo(right - topRadius, top);
    headPath.quadraticBezierTo(right, top, right, top + topRadius);
    // Right side going down
    headPath.lineTo(right, bottom - bottomRadius * 1.5);
    // Right slant going inward to the neck
    headPath.quadraticBezierTo(right, bottom, neckRight, bottom);
    // Bottom edge (neck)
    headPath.lineTo(neckLeft, bottom);
    // Left slant going outward
    headPath.quadraticBezierTo(left, bottom, left, bottom - bottomRadius * 1.5);
    headPath.close();

    canvas.drawPath(headPath, headPaint);

    // 2. Draw the handle (solid black)
    final Paint handlePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
      
    final double handleHeight = size.height * 0.38;
    final Path handlePath = Path();
    final double handleLeft = (size.width - handleWidth) / 2;
    final double handleRight = handleLeft + handleWidth;
    
    // Overlap slightly with the head to avoid gaps
    final double handleTop = bottom - (size.width * 0.03); 
    
    handlePath.moveTo(handleLeft, handleTop);
    handlePath.lineTo(handleRight, handleTop);
    handlePath.lineTo(handleRight, handleTop + handleHeight - size.width * 0.05);
    // Bottom rounded edge of handle
    handlePath.quadraticBezierTo(handleRight, handleTop + handleHeight, handleRight - size.width * 0.05, handleTop + handleHeight);
    handlePath.lineTo(handleLeft + size.width * 0.05, handleTop + handleHeight);
    handlePath.quadraticBezierTo(handleLeft, handleTop + handleHeight, handleLeft, handleTop + handleHeight - size.width * 0.05);
    handlePath.close();

    canvas.drawPath(handlePath, handlePaint);
  }

  @override
  bool shouldRepaint(covariant PaddlePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
