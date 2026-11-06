import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/backend.dart';

/// بانک مدارک ارسال‌شده: هر فایلی که والد ارسال می‌کند یک ردیف اینجا می‌ماند
class RegistrationDocs {
  static const String table = 'registration_documents';
  static const String bucket = 'registration-docs';

  static Future<void> archive({
    required String recordId,
    required String parentId,
    required String path,
    required String fileName,
  }) async {
    await Backend.client.from(table).insert({
      'record_id': recordId,
      'parent_id': parentId,
      'path': path,
      'file_name': fileName,
    });
  }

  static Future<List<Map<String, dynamic>>> forRecord(String recordId) async {
    final rows = await Backend.client
        .from(table)
        .select('id, path, file_name, created_at')
        .eq('record_id', recordId)
        .order('created_at', ascending: false);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  /// دانلود فایل روی دستگاه (پنجرهٔ ذخیره یا اشتراک‌گذاری همان سیستم عامل)
  static Future<void> saveToDevice(String path, String fileName) async {
    final url = await Backend.client.storage.from(bucket).createSignedUrl(path, 300);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('دانلود فایل انجام نشد (${res.statusCode})');
    final Uint8List bytes = res.bodyBytes;
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static Future<String> signedUrl(String path) =>
      Backend.client.storage.from(bucket).createSignedUrl(path, 3600);

  /// ارسال مجدد یک مدرک از بانک: به‌عنوان مدرک فعلی پرونده ثبت می‌شود (بدون ردیف تکراری در بانک)
  static Future<void> reattach({
    required String recordId,
    required String path,
    required Map<String, String> values,
  }) async {
    await Backend.client.from('registration_records').update({
      'attachment_url': path,
      'data': {...values, 'لینک/پیوست شناسنامه': path},
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', recordId);
  }

  static Future<Uint8List> fetchBytes(String path) async {
    final url = await signedUrl(path);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('دریافت فایل انجام نشد (${res.statusCode})');
    return res.bodyBytes;
  }

  /// چاپ مدارک: هر عکس یک صفحه A4 (پنجرهٔ چاپ سیستم باز می‌شود)
  static Future<void> printDocs(List<String> paths) async {
    final doc = pw.Document();
    for (final p in paths) {
      final img = pw.MemoryImage(await fetchBytes(p));
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'مدارک نوآموز');
  }
}
