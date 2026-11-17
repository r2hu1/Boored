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
  /// 1. Lecturer removal & de-occlusion on all keyframes (if removeLecturer is true).
  /// 2. Deduplication of near-identical consecutive frames.
  /// 3. OCR text extraction on each retained keyframe.
  /// 4. Timeline JSON generation.
  /// 5. Document PDF generation.
  /// 6. Mark note status as 'ready'.
  Future<String> finalizeNote(String noteId, {bool removeLecturer = true}) async {
    await notesDao.updateNote(noteId, status: 'processing');

    final rawKeyframes = await keyframesDao.getKeyframesForNote(noteId);
    if (rawKeyframes.isEmpty) {
      await notesDao.updateNote(noteId, status: 'ready');
      return '';
    }

    // Step 1: Lecturer Removal on the sequence (optional & optimized)
    final keyframeImagePaths = rawKeyframes.map((k) => k.imagePath).toList();
    final deoccludedPaths = removeLecturer
        ? await lecturerRemovalProcessor.processKeyframeSequence(keyframeImagePaths)
        : keyframeImagePaths;

    // Step 2 & 3: OCR text extraction
    final timelineEvents = <Map<String, dynamic>>[];

    for (int i = 0; i < rawKeyframes.length && i < deoccludedPaths.length; i++) {
      final kf = rawKeyframes[i];
      final finalPath = deoccludedPaths[i];

      final text = await recognitionEngine.extractText(finalPath);
      await keyframesDao.updateKeyframeImageAndText(kf.id, finalPath, text);

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
    final pdf = pw.Document();

    for (int i = 0; i < timelineEvents.length; i++) {
      final event = timelineEvents[i];
      final imgPath = event['imagePath'] as String;

      if (File(imgPath).existsSync()) {
        final imageBytes = await File(imgPath).readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              );
            },
          ),
        );
      }
    }

    final pdfPath = p.join(noteDir.path, 'document.pdf');
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    // Step 5b: Digital OCR PDF document generation (if OCR text extracted)
    await generateDigitalPdf(noteId);

    // Step 6: Mark note as ready
    await notesDao.updateNote(noteId, status: 'ready');

    return pdfPath;
  }

  /// Generates a clean digital document PDF from extracted OCR text across all keyframes.
  Future<String?> generateDigitalPdf(String noteId) async {
    final note = await notesDao.getNoteById(noteId);
    final keyframes = await keyframesDao.getKeyframesForNote(noteId);
    if (keyframes.isEmpty) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final noteDir = Directory(p.join(appDir.path, 'captures', noteId));
    if (!noteDir.existsSync()) {
      noteDir.createSync(recursive: true);
    }

    final digitalPdf = pw.Document();
    final title = note?.title ?? 'Digital Notes';

    // Filter frames that have non-empty text, or use unique frames
    final framesWithContent = keyframes.where((k) => (k.extractedText ?? '').trim().isNotEmpty).toList();
    final pagesToRender = framesWithContent.isNotEmpty ? framesWithContent : keyframes;

    for (int i = 0; i < pagesToRender.length; i++) {
      final kf = pagesToRender[i];
      final textContent = (kf.extractedText ?? '').trim();

      digitalPdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          header: (pw.Context ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Section ${i + 1} of ${pagesToRender.length}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          ),
          footer: (pw.Context ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Boored Digital Copy',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ),
          build: (pw.Context ctx) {
            return [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 16),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 4,
                      height: 18,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue700,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'Page ${i + 1}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                  ],
                ),
              ),
              if (textContent.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey200, width: 0.8),
                  ),
                  child: pw.Paragraph(
                    text: textContent,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      lineSpacing: 3.5,
                      color: PdfColors.black,
                    ),
                  ),
                )
              else
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Text(
                    '[No text detected on this board]',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey500,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
            ];
          },
        ),
      );
    }

    final digitalPdfPath = p.join(noteDir.path, 'digital.pdf');
    final digitalPdfFile = File(digitalPdfPath);
    await digitalPdfFile.writeAsBytes(await digitalPdf.save());
    return digitalPdfPath;
  }
}
