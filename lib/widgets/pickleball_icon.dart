import 'package:flutter_project/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class PickleballIcon extends StatelessWidget {
  final double size;
  final Color color;
  final Color holeColor;

  const PickleballIcon({
    Key? key,
    this.size = 24,
    this.color = Colors.white,
    this.holeColor = AppColors.primaryGreen, // Default to deep forest green
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: PickleballPainter(color: color, holeColor: holeColor),
    );
  }
}

class PickleballPainter extends CustomPainter {
  final Color color;
  final Color holeColor;
  
  PickleballPainter({required this.color, required this.holeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw the main ball
    canvas.drawCircle(center, size.width / 2, paint);

    final holePaint = Paint()
      ..color = holeColor
      ..style = PaintingStyle.fill;
      
    final holeRadius = size.width * 0.07;
    
    // Center hole
    canvas.drawCircle(center, holeRadius, holePaint);
    
    // Inner ring of holes
    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3);
      final offset = Offset(
        center.dx + math.cos(angle) * (size.width * 0.22),
        center.dy + math.sin(angle) * (size.width * 0.22),
      );
      canvas.drawCircle(offset, holeRadius, holePaint);
    }
    
    // Outer ring of holes
    for (int i = 0; i < 12; i++) {
      final angle = i * (math.pi / 6) + (math.pi / 12);
      final offset = Offset(
        center.dx + math.cos(angle) * (size.width * 0.40),
        center.dy + math.sin(angle) * (size.width * 0.40),
      );
      // Make outer holes slightly smaller to fit
      canvas.drawCircle(offset, holeRadius * 0.7, holePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
