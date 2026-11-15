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

class BoardOverlay extends StatefulWidget {
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
  State<BoardOverlay> createState() => _BoardOverlayState();
}

class _BoardOverlayState extends State<BoardOverlay> {
  int? _activeDraggingIndex;
  Offset? _dragStartGlobalOffset;
  Offset? _dragStartCornerPixelOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              size: size,
              painter: _BoardOutlinePainter(corners: widget.corners),
            ),
            if (widget.editable)
              for (int i = 0; i < widget.corners.length; i++)
                _buildCornerHandle(i, size),
          ],
        );
      },
    );
  }

  Widget _buildCornerHandle(int index, Size size) {
    const handleVisualRadius = 24.0;
    const hitAreaSize = 72.0;
    final pos = widget.corners[index].toOffset(size);
    final isDragging = _activeDraggingIndex == index;

    return Positioned(
      left: pos.dx - hitAreaSize / 2,
      top: pos.dy - hitAreaSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          setState(() {
            _activeDraggingIndex = index;
            _dragStartGlobalOffset = details.globalPosition;
            _dragStartCornerPixelOffset = pos;
          });
        },
        onPanUpdate: (details) {
          if (_dragStartGlobalOffset == null || _dragStartCornerPixelOffset == null) {
            return;
          }
          final delta = details.globalPosition - _dragStartGlobalOffset!;
          final newDx = (_dragStartCornerPixelOffset!.dx + delta.dx).clamp(0.0, size.width);
          final newDy = (_dragStartCornerPixelOffset!.dy + delta.dy).clamp(0.0, size.height);

          final updated = List<BoardCorner>.from(widget.corners);
          updated[index] = BoardCorner(newDx / size.width, newDy / size.height);
          widget.onCornersChanged(updated);
        },
        onPanEnd: (_) {
          setState(() {
            _activeDraggingIndex = null;
            _dragStartGlobalOffset = null;
            _dragStartCornerPixelOffset = null;
          });
        },
        onPanCancel: () {
          setState(() {
            _activeDraggingIndex = null;
            _dragStartGlobalOffset = null;
            _dragStartCornerPixelOffset = null;
          });
        },
        child: Container(
          width: hitAreaSize,
          height: hitAreaSize,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: AnimatedScale(
            scale: isDragging ? 1.25 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: handleVisualRadius * 2,
              height: handleVisualRadius * 2,
              decoration: BoxDecoration(
                color: isDragging ? Colors.amber : Colors.amberAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: isDragging ? 3.0 : 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDragging ? 0.7 : 0.45),
                    blurRadius: isDragging ? 10 : 6,
                    spreadRadius: isDragging ? 3 : 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
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
