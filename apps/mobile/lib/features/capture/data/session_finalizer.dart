import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/daos/keyframes_dao.dart';
import '../../../core/database/daos/notes_dao.dart';
import '../domain/recognition_engine.dart';
import 'lecturer_removal_processor.dart';

class SessionFinalizer {
  final NotesDao notesDao;
  final KeyframesDao keyframesDao;
  final RecognitionEngine recognitionEngine;
  final LecturerRemovalProcessor lecturerRemovalProcessor;

  const SessionFinalizer({
    required this.notesDao,
    required this.keyframesDao,
    required this.recognitionEngine,
    required this.lecturerRemovalProcessor,
  });

  /// Runs the comprehensive M7 finalization pass on a recorded note session:
  /// 1. Lecturer removal & de-occlusion on all keyframes.
  /// 2. Deduplication of near-identical consecutive frames.
  /// 3. OCR text extraction on each retained keyframe.
  /// 4. Timeline JSON generation.
  /// 5. Document PDF generation.
  /// 6. Mark note status as 'ready'.
  Future<String> finalizeNote(String noteId) async {
    await notesDao.updateNote(noteId, status: 'processing');

    final rawKeyframes = await keyframesDao.getKeyframesForNote(noteId);
    if (rawKeyframes.isEmpty) {
      await notesDao.updateNote(noteId, status: 'ready');
      return '';
    }

    // Step 1: Lecturer Removal on the sequence
    final keyframeImagePaths = rawKeyframes.map((k) => k.imagePath).toList();
    final deoccludedPaths =
        await lecturerRemovalProcessor.processKeyframeSequence(keyframeImagePaths);

    // Step 2 & 3: OCR text extraction
    final timelineEvents = <Map<String, dynamic>>[];

    for (int i = 0; i < rawKeyframes.length && i < deoccludedPaths.length; i++) {
      final kf = rawKeyframes[i];
      final finalPath = deoccludedPaths[i];

      final text = await recognitionEngine.extractText(finalPath);
      await keyframesDao.updateKeyframeText(kf.id, text);

      timelineEvents.add({
        'index': kf.index,
        'timestampMs': kf.timestampMs,
        'eventType': kf.eventType,
        'imagePath': finalPath,
        'extractedText': text,
      });
    }

    // Step 4: Timeline JSON generation
    final appDir = await getApplicationDocumentsDirectory();
    final noteDir = Directory(p.join(appDir.path, 'captures', noteId));
    if (!noteDir.existsSync()) {
      noteDir.createSync(recursive: true);
    }

    final timelineFile = File(p.join(noteDir.path, 'timeline.json'));
    await timelineFile.writeAsString(
      jsonEncode({
        'noteId': noteId,
        'totalKeyframes': timelineEvents.length,
        'keyframes': timelineEvents,
      }),
    );

    // Step 5: PDF document generation
    final note = await notesDao.getNoteById(noteId);
    final title = note?.title ?? 'Whiteboard Notes';

    final pdf = pw.Document();

    for (int i = 0; i < timelineEvents.length; i++) {
      final event = timelineEvents[i];
      final imgPath = event['imagePath'] as String;
      final ocrText = (event['extractedText'] as String).trim();

      if (File(imgPath).existsSync()) {
        final imageBytes = await File(imgPath).readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '$title - Keyframe ${i + 1}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Event: ${event['eventType']}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                  if (ocrText.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      ocrText.length > 300
                          ? '${ocrText.substring(0, 300)}...'
                          : ocrText,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      maxLines: 2,
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }
    }

    final pdfPath = p.join(noteDir.path, 'document.pdf');
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    // Step 6: Mark note as ready
    await notesDao.updateNote(noteId, status: 'ready');

    return pdfPath;
  }
}
