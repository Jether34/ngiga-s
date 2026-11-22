import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngiga/receipt_export.dart';

void main() {
  testWidgets('PDF and PNG use the same complete receipt image', (
    tester,
  ) async {
    final fields = <String, String>{
      'Receipt ID': 'NGIGA-2026-0001',
      'Borrower': 'Jether Example',
      'User ID': '2026-12345',
      'Account type': 'STUDENT',
      'Equipment': 'Digital multimeter (EQ-001)',
      'Serial / barcode': 'DM-0001',
      'Database record ID': 'unit-uuid-1234',
      'Borrowed': '2026-11-20 09:30',
      'Due': '2026-11-27 09:30',
      'Status': 'ACTIVE',
    };
    final receipt = <String, dynamic>{
      'receipt_number': fields['Receipt ID'],
      'borrower_name': fields['Borrower'],
      'borrower_id': fields['User ID'],
      'account_type': fields['Account type'],
      'email': 'jether@example.com',
    };
    final result = await tester.runAsync(() async {
      if (const bool.fromEnvironment('WRITE_PREVIEW')) {
        const fontPath = String.fromEnvironment('PREVIEW_FONT_PATH');
        if (fontPath.isNotEmpty) {
          final bytes = await File(fontPath).readAsBytes();
          await (FontLoader(
            'Roboto',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      }
      final png = await ReceiptExport.png(fields, receipt);
      final pdf = await ReceiptExport.pdf(fields, receipt);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final size = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      if (const bool.fromEnvironment('WRITE_PREVIEW')) {
        await File('build/receipt-preview.png').writeAsBytes(png);
        await File('build/receipt-preview.pdf').writeAsBytes(pdf);
      }
      return (png, pdf, size);
    });
    expect(result, isNotNull);
    final (png, pdf, size) = result!;
    expect(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    expect(size, (ReceiptExport.width, ReceiptExport.height(fields)));
    final qr = jsonDecode(ReceiptExport.borrowerQrData(receipt));
    expect(qr['student_id'], fields['User ID']);
    expect(qr['email'], 'jether@example.com');
  });
}
