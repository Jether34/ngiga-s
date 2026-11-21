import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart';

/// One receipt canvas is used for both downloads so the layouts stay identical.
abstract final class ReceiptExport {
  static const width = 900;

  static int height(Map<String, String> fields) =>
      fields.containsKey('Returned') ? 1730 : 1660;

  static String borrowerQrData(Map<String, dynamic> receipt) => jsonEncode({
    'type': 'ngiga.borrower.v1',
    'receipt': '${receipt['receipt_number'] ?? ''}',
    'name': '${receipt['borrower_name'] ?? ''}',
    'student_id': '${receipt['borrower_id'] ?? ''}',
    'account_type': '${receipt['account_type'] ?? ''}',
    'email': '${receipt['email'] ?? ''}',
  });

  static Future<Uint8List> pdf(
    Map<String, String> fields,
    Map<String, dynamic> receipt,
  ) async {
    final pngBytes = await png(fields, receipt);
    final document = pw.Document();
    const pageWidth = 300.0;
    final pageHeight = pageWidth * height(fields) / width;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(
          pw.MemoryImage(pngBytes),
          width: pageWidth,
          height: pageHeight,
          fit: pw.BoxFit.fill,
        ),
      ),
    );
    return document.save();
  }

  static Future<Uint8List> png(
    Map<String, String> fields,
    Map<String, dynamic> receipt,
  ) async {
    final pageHeight = height(fields).toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    const ink = Color(0xff17151d);
    const muted = Color(0xff6f6b76);
    const accent = Color(0xff145a43);
    final rule = Paint()
      ..color = const Color(0xffd9d5df)
      ..strokeWidth = 1.5;

    double drawText(
      String value,
      double x,
      double y,
      double maxWidth, {
      double size = 25,
      Color color = ink,
      FontWeight weight = FontWeight.normal,
      TextAlign align = TextAlign.left,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: weight,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x, y));
      return painter.height;
    }

    void divider(double y) =>
        canvas.drawLine(Offset(70, y), Offset(width - 70, y), rule);

    double row(String label, String value, double y) {
      final labelHeight = drawText(
        label,
        70,
        y,
        255,
        size: 19,
        weight: FontWeight.w700,
      );
      final valueHeight = drawText(value, 335, y - 2, 495, size: 23);
      return y + math.max(61, math.max(labelHeight, valueHeight) + 17);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(320, 53, 33, 33),
        const Radius.circular(5),
      ),
      Paint()..color = accent,
    );
    drawText(
      'N',
      326,
      54,
      24,
      size: 24,
      color: Colors.white,
      weight: FontWeight.w800,
    );
    drawText('NGIGA', 364, 43, 230, size: 36, weight: FontWeight.w800);
    drawText('STOCKROOM', 372, 87, 180, size: 14, weight: FontWeight.w700);

    var y = 190.0;
    y = row('Date', fields['Borrowed'] ?? '', y);
    y = row('Borrower', fields['Borrower'] ?? '', y);
    y = row('Student / User ID', fields['User ID'] ?? '', y);
    y = row('Account type', fields['Account type'] ?? '', y);
    y = row('Receipt no.', fields['Receipt ID'] ?? '', y);
    divider(y + 5);
    y += 32;

    drawText('Description', 70, y, 530, size: 19, weight: FontWeight.w700);
    drawText('QTY', 651, y, 70, size: 19, weight: FontWeight.w700);
    drawText('Status', 735, y, 100, size: 19, weight: FontWeight.w700);
    y += 44;
    final equipmentHeight = drawText(
      fields['Equipment'] ?? '',
      70,
      y,
      550,
      size: 23,
    );
    drawText('01', 652, y, 65, size: 23);
    drawText(fields['Status'] ?? '', 735, y, 100, size: 19);
    y += math.max(76, equipmentHeight + 18);
    divider(y);
    y += 25;

    y = row('Unit serial', fields['Serial / barcode'] ?? '', y);
    y = row('Database record ID', fields['Database record ID'] ?? '', y);
    y = row('Due', fields['Due'] ?? '', y);
    if (fields.containsKey('Returned')) {
      y = row('Returned', fields['Returned']!, y);
    }
    y = row('Loan status', fields['Status'] ?? '', y);
    divider(y + 4);

    final qrData = borrowerQrData(receipt);
    final qr = QrImage(
      QrCode.fromData(data: qrData, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    final moduleSize = (278 / (qr.moduleCount + 8)).floorToDouble();
    final actualSize = moduleSize * (qr.moduleCount + 8);
    final qrLeft = (width - actualSize) / 2;
    final qrTop = pageHeight - 390;
    canvas.drawRect(
      Rect.fromLTWH(qrLeft, qrTop, actualSize, actualSize),
      Paint()..color = Colors.white,
    );
    final qrPaint = Paint()
      ..color = ink
      ..isAntiAlias = false;
    for (var rowIndex = 0; rowIndex < qr.moduleCount; rowIndex++) {
      for (var col = 0; col < qr.moduleCount; col++) {
        if (qr.isDark(rowIndex, col)) {
          canvas.drawRect(
            Rect.fromLTWH(
              qrLeft + (col + 4) * moduleSize,
              qrTop + (rowIndex + 4) * moduleSize,
              moduleSize,
              moduleSize,
            ),
            qrPaint,
          );
        }
      }
    }
    drawText(
      'Scan for borrower information',
      155,
      pageHeight - 98,
      590,
      size: 20,
      color: muted,
      align: TextAlign.center,
    );
    drawText(
      fields['Receipt ID'] ?? '',
      155,
      pageHeight - 61,
      590,
      size: 16,
      color: muted,
      align: TextAlign.center,
    );

    final image = await recorder.endRecording().toImage(
      width,
      pageHeight.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Could not create PNG receipt');
    return data.buffer.asUint8List();
  }
}
