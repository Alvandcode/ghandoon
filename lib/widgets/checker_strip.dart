import 'package:flutter/material.dart';
import '../theme/qand_theme.dart';

/// نوار چارخونه قرمز/سفید مثل رومیزی لوگوی قندون.
/// برای لبه هدرها و جداکننده بخش‌ها.
class CheckerStrip extends StatelessWidget {
  final double height;
  final double square;
  const CheckerStrip({super.key, this.height = 18, this.square = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _CheckerPainter(square: square)),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  final double square;
  _CheckerPainter({required this.square});

  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = QandTheme.red;
    final white = Paint()..color = Colors.white;
    final cream = Paint()..color = QandTheme.cream;
    // پس‌زمینه کرم تا لبه‌ها تمیز باشند
    canvas.drawRect(Offset.zero & size, cream);
    var row = 0;
    for (var y = 0.0; y < size.height; y += square, row++) {
      var col = row.isEven ? 0 : 1;
      for (var x = 0.0; x < size.width; x += square, col++) {
        canvas.drawRect(Rect.fromLTWH(x, y, square, square),
            col.isEven ? red : white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
