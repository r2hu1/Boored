import 'package:flutter/material.dart';

class BoardCorner {
  final double x;
  final double y;

  const BoardCorner(this.x, this.y);

  BoardCorner copyWith({double? x, double? y}) {
    return BoardCorner(x ?? this.x, y ?? this.y);
  }

  Offset toOffset(Size size) => Offset(x * size.width, y * size.height);
}

class BoardOverlay extends StatelessWidget {
  final List<BoardCorner> corners;
  final ValueChanged<List<BoardCorner>> onCornersChanged;
  final bool editable;

  const BoardOverlay({
    super.key,
    required this.corners,
    required this.onCornersChanged,
    this.editable = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            CustomPaint(
              size: size,
              painter: _BoardOutlinePainter(corners: corners),
            ),
            if (editable)
              for (int i = 0; i < corners.length; i++)
                _buildCornerHandle(i, size),
          ],
        );
      },
    );
  }

  Widget _buildCornerHandle(int index, Size size) {
    const handleRadius = 24.0;
    const hitAreaSize = 56.0;
    final pos = corners[index].toOffset(size);

    return Positioned(
      left: pos.dx - hitAreaSize / 2,
      top: pos.dy - hitAreaSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final newDx = (pos.dx + details.delta.dx).clamp(0.0, size.width);
          final newDy = (pos.dy + details.delta.dy).clamp(0.0, size.height);

          final updated = List<BoardCorner>.from(corners);
          updated[index] = BoardCorner(newDx / size.width, newDy / size.height);
          onCornersChanged(updated);
        },
        child: Container(
          width: hitAreaSize,
          height: hitAreaSize,
          alignment: Alignment.center,
          child: Container(
            width: handleRadius * 2,
            height: handleRadius * 2,
            decoration: BoxDecoration(
              color: Colors.amberAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardOutlinePainter extends CustomPainter {
  final List<BoardCorner> corners;

  _BoardOutlinePainter({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 4) return;

    final fillPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(corners[0].x * size.width, corners[0].y * size.height)
      ..lineTo(corners[1].x * size.width, corners[1].y * size.height)
      ..lineTo(corners[2].x * size.width, corners[2].y * size.height)
      ..lineTo(corners[3].x * size.width, corners[3].y * size.height)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BoardOutlinePainter oldDelegate) => true;
}
