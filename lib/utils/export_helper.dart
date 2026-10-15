import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExportHelper {
  // Export data as Excel-compatible CSV file with UTF-8 BOM
  static Future<void> exportToExcel({
    required BuildContext context,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String fileName,
  }) async {
    try {
      List<List<dynamic>> csvData = [
        headers,
        ...rows,
      ];

      // Robust CSV string conversion escaping quotes and joining with commas/newlines
      String csvString = csvData
          .map((row) => row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(','))
          .join('\n');
      
      // Add UTF-8 BOM (\uFEFF) so Excel correctly displays Persian/Arabic characters
      final bytes = utf8.encode('\uFEFF$csvString');

      await Printing.sharePdf(
        bytes: bytes,
        filename: '$fileName.csv',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ فایل اکسل ($fileName.csv) با موفقیت آماده و صادر شد!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطا در صدور فایل اکسل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<pw.Font> _loadFont(String asset, Future<pw.Font> Function() fallback) async {
    try {
      return pw.Font.ttf(await rootBundle.load(asset));
    } catch (_) {
      return fallback();
    }
  }

  /// چاپ جدول (پنجرهٔ پیش‌نمایش و چاپ)
  static Future<void> printTable({
    required BuildContext context,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String fileName,
  }) =>
      exportToPdf(context: context, title: title, headers: headers, rows: rows, fileName: fileName, printOnly: true);

  // Export data as PDF document with Persian font support (Vazirmatn)
  static Future<void> exportToPdf({
    required BuildContext context,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String fileName,
    bool printOnly = false,
  }) async {
    try {
      final pdf = pw.Document();

      // Load Persian Google Font for correct PDF text rendering
      // اول فونت داخل پروژه (assets/fonts)؛ اگر نبود، از اینترنت
      final font = await _loadFont('assets/fonts/Vazirmatn-Regular.ttf', PdfGoogleFonts.vazirmatnRegular);
      final boldFont = await _loadFont('assets/fonts/Vazirmatn-Bold.ttf', PdfGoogleFonts.vazirmatnBold);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
          ),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(font: boldFont, fontSize: 18, color: PdfColors.indigo900),
                    ),
                    pw.Text(
                      'مهد و دبستان روزگار کودکی',
                      style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                cellStyle: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.black),
                cellAlignment: pw.Alignment.centerRight,
                headerAlignment: pw.Alignment.centerRight,
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'سیستم جامع مدیریت روزگار کودکی - گزارش رسمی مدیریت',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'تاریخ چاپ: ${DateTime.now().toString().substring(0, 10)}',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (printOnly) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: '$fileName.pdf',
        );
      } else {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: '$fileName.pdf',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(printOnly ? '✅ آمادهٔ چاپ شد' : '✅ فایل PDF ($fileName.pdf) با موفقیت ذخیره/دانلود شد!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطا در صدور PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
