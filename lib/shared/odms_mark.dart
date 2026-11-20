import 'package:material_ui/material_ui.dart';

/// Vector mark follows the existing ODMS website's four-rotor symbol.
class OdmsMark extends StatelessWidget {
  const OdmsMark({super.key, this.size = 32});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ODMS',
    child: CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(Theme.of(context).colorScheme.primary),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final arm in [
      (const Offset(9, 9), const Offset(15, 14)),
      (const Offset(23, 9), const Offset(17, 14)),
      (const Offset(9, 23), const Offset(15, 18)),
      (const Offset(23, 23), const Offset(17, 18)),
    ]) {
      canvas.drawLine(arm.$1, arm.$2, paint);
    }
    for (final point in [
      const Offset(7, 7),
      const Offset(25, 7),
      const Offset(7, 25),
      const Offset(25, 25),
    ]) {
      canvas.drawCircle(point, 2.5, paint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 12, 6, 8),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
