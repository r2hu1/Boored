import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/relative_time.dart';
import '../folders_controller.dart';

class FolderCard extends ConsumerWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final noteCountAsync = ref.watch(folderNoteCountProvider(folder.id));

    const cardWidth = 165.0;
    const cardHeight = 180.0;
    const tabHeight = 24.0;
    const frontPocketTop = 44.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Stack(
            children: [
              // 1. Back Folder Flap with Tab Shape
              Positioned.fill(
                child: CustomPaint(
                  painter: _FolderBackPainter(
                    color: colors.primary.withValues(alpha: 0.75),
                  ),
                ),
              ),

              // 2. Paper Sheet Peeking Out from the Folder
              Positioned(
                left: 12,
                right: 12,
                top: tabHeight + 8,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Front Folder Pocket (Main Surface)
              Positioned(
                left: 0,
                right: 0,
                top: frontPocketTop,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary,
                        colors.primary.withValues(alpha: 0.92),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header Row: Title + Count & Action Menu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Count
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                noteCountAsync.when(
                                  data: (count) => Text(
                                    count == 1 ? '1 note' : '$count notes',
                                    style: TextStyle(
                                      color: colors.onPrimary.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  loading: () => Text(
                                    '···',
                                    style: TextStyle(
                                      color: colors.onPrimary.withValues(alpha: 0.85),
                                      fontSize: 13,
                                    ),
                                  ),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),

                          // Three-Dot Action Pill Button (matches the reference image)
                          if (onEdit != null || onDelete != null)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.onPrimary.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: colors.onPrimary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (val) {
                                  if (val == 'edit') onEdit?.call();
                                  if (val == 'delete') onDelete?.call();
                                },
                                itemBuilder: (ctx) => [
                                  if (onEdit != null)
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 16),
                                          SizedBox(width: 8),
                                          Text('Rename folder'),
                                        ],
                                      ),
                                    ),
                                  if (onDelete != null)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 16, color: colors.error),
                                          const SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: colors.error)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Footer: Last Added / Updated Timestamp
                      Text(
                        'Updated ${relativeTime(folder.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.72),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws the back folder tab shape with curved slope
class _FolderBackPainter extends CustomPainter {
  final Color color;

  const _FolderBackPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 18.0; // corner radius
    final tabW = w * 0.44; // tab width ~44%
    const tabH = 24.0; // shoulder height offset

    final path = Path();
    // Start at bottom-left
    path.moveTo(0, h - r);
    // Left edge straight up to tab top-left
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0); // Tab top-left curve

    // Tab top horizontal edge
    path.lineTo(tabW - 10, 0);

    // Smooth curved slope down to the right shoulder
    path.cubicTo(
      tabW + 2, 0,
      tabW + 2, tabH,
      tabW + 16, tabH,
    );

    // Right shoulder horizontal edge
    path.lineTo(w - r, tabH);
    path.quadraticBezierTo(w, tabH, w, tabH + r); // Shoulder top-right curve

    // Right edge down
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h); // Bottom-right curve

    // Bottom edge
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r); // Bottom-left curve
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FolderBackPainter oldDelegate) =>
      color != oldDelegate.color;
}
