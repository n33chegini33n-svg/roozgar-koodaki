import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../models/permissions.dart';
import '../services/backend.dart';
import '../utils/jalali.dart';

const String kPurchaseBucket = 'purchase-attachments';
const String _formSel =
    'id, form_no, title, need_by, is_urgent, note, status, requester_role, decision_note, created_at, purchased_at, requester_id, profiles!purchase_requests_requester_id_fkey(full_name), buyer:profiles!purchase_requests_purchased_by_fkey(full_name)';

class PurchaseCategory {
  final String id;
  final String code;
  final String title;
  final String scope; // kitchen | class | shared
  const PurchaseCategory({required this.id, required this.code, required this.title, required this.scope});
}

class PurchaseForm {
  final String id;
  final String formNo;
  final String title;
  final String note;
  final String status;
  final String requesterRole;
  final String requesterName;
  final String decisionNote;
  final DateTime? needBy;
  final bool isUrgent;
  final DateTime? createdAt;
  final DateTime? purchasedAt;
  final String buyerName;

  const PurchaseForm({
    required this.id,
    required this.formNo,
    required this.title,
    required this.note,
    required this.status,
    required this.requesterRole,
    required this.requesterName,
    required this.decisionNote,
    required this.needBy,
    required this.isUrgent,
    required this.createdAt,
    this.purchasedAt,
    this.buyerName = '',
  });

  factory PurchaseForm.fromRow(Map<String, dynamic> r) {
    final p = r['profiles'];
    final b = r['buyer'];
    return PurchaseForm(
      id: '${r['id']}',
      formNo: '${r['form_no'] ?? ''}',
      title: '${r['title'] ?? ''}',
      note: '${r['note'] ?? ''}',
      status: '${r['status'] ?? 'draft'}',
      requesterRole: '${r['requester_role'] ?? ''}',
      requesterName: p is Map ? '${p['full_name'] ?? ''}' : '',
      decisionNote: '${r['decision_note'] ?? ''}',
      needBy: r['need_by'] == null ? null : DateTime.tryParse('${r['need_by']}'),
      isUrgent: r['is_urgent'] == true,
      createdAt: r['created_at'] == null ? null : DateTime.tryParse('${r['created_at']}'),
      purchasedAt: r['purchased_at'] == null ? null : DateTime.tryParse('${r['purchased_at']}'),
      buyerName: b is Map ? '${b['full_name'] ?? ''}' : '',
    );
  }
}

class PurchaseItemRow {
  final String categoryId;
  final String kind;
  final String name;
  final String unit;
  final num quantity;
  final String note;
  const PurchaseItemRow({
    required this.categoryId,
    required this.kind,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.note,
  });

  factory PurchaseItemRow.fromRow(Map<String, dynamic> r) => PurchaseItemRow(
        categoryId: '${r['category_id'] ?? ''}',
        kind: '${r['kind'] ?? 'item'}',
        name: '${r['name'] ?? ''}',
        unit: '${r['unit'] ?? ''}',
        quantity: (r['quantity'] as num?) ?? 1,
        note: '${r['note'] ?? ''}',
      );
}

class PurchaseAttachment {
  final String id;
  final String fileName;
  final String path;
  final String mime;
  final int size;
  const PurchaseAttachment({
    required this.id,
    required this.fileName,
    required this.path,
    required this.mime,
    required this.size,
  });

  bool get isImage => mime.startsWith('image/');

  factory PurchaseAttachment.fromRow(Map<String, dynamic> r) => PurchaseAttachment(
        id: '${r['id']}',
        fileName: '${r['file_name'] ?? ''}',
        path: '${r['storage_path'] ?? ''}',
        mime: '${r['mime_type'] ?? ''}',
        size: (r['size_bytes'] as num?)?.toInt() ?? 0,
      );
}

class PurchaseUploadError {
  final String fileName;
  final String errorText;
  final DateTime? createdAt;
  const PurchaseUploadError({required this.fileName, required this.errorText, required this.createdAt});

  factory PurchaseUploadError.fromRow(Map<String, dynamic> r) => PurchaseUploadError(
        fileName: '${r['file_name'] ?? ''}',
        errorText: '${r['error_text'] ?? ''}',
        createdAt: r['created_at'] == null ? null : DateTime.tryParse('${r['created_at']}'),
      );
}

/// فایل آماده برای ساخت PDF (فقط تصویر)
class PurchaseFileData {
  final String name;
  final Uint8List bytes;
  final String mime;
  const PurchaseFileData({required this.name, required this.bytes, required this.mime});
}

class PurchaseStaff {
  final String id;
  final String name;
  final String role;
  const PurchaseStaff({required this.id, required this.name, required this.role});
}

class PurchaseService {
  /// نقش کاربر به گروه فهرست اقلام: آشپزخانه یا کلاس
  static String get group {
    switch (Session.role) {
      case AppRole.kitchen:
        return 'kitchen';
      case AppRole.teacher:
        return 'class';
      default:
        return '';
    }
  }

  static Future<List<PurchaseCategory>> categories() async {
    final rows = await Backend.client
        .from('purchase_categories')
        .select('id, code, title, scope')
        .eq('is_active', true)
        .order('sort_order');
    final g = group;
    return [
      for (final r in rows)
        PurchaseCategory(id: '${r['id']}', code: '${r['code']}', title: '${r['title']}', scope: '${r['scope']}'),
    ].where((c) => c.scope == 'shared' || c.scope == g).toList();
  }

  static Future<PurchaseForm> form(String id) async {
    final r = await Backend.client.from('purchase_requests').select(_formSel).eq('id', id).single();
    return PurchaseForm.fromRow(Map<String, dynamic>.from(r));
  }

  static Future<List<PurchaseForm>> myForms() async {
    final uid = Backend.client.auth.currentUser!.id;
    final rows = await Backend.client
        .from('purchase_requests')
        .select(_formSel)
        .eq('requester_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) PurchaseForm.fromRow(Map<String, dynamic>.from(r))];
  }

  /// مدیر: همهٔ فرم‌ها، یا فقط در انتظار تأیید
  static Future<List<PurchaseForm>> allForms({required bool onlyPending}) async {
    final rows = onlyPending
        ? await Backend.client
            .from('purchase_requests')
            .select(_formSel)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(200)
        : await Backend.client
            .from('purchase_requests')
            .select(_formSel)
            .order('created_at', ascending: false)
            .limit(200);
    return [for (final r in rows) PurchaseForm.fromRow(Map<String, dynamic>.from(r))];
  }

  /// مدیر: فرم‌های تأییدشده که به خریدار ارجاع شده‌اند و هنوز خرید انجام نشده
  static Future<List<PurchaseForm>> inProgressForms() async {
    final rows = await Backend.client
        .from('purchase_requests')
        .select('$_formSel, purchase_request_recipients!inner(profile_id)')
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(200);
    final seen = <String>{};
    final out = <PurchaseForm>[];
    for (final r in rows) {
      final f = PurchaseForm.fromRow(Map<String, dynamic>.from(r));
      if (seen.add(f.id)) out.add(f);
    }
    return out;
  }

  /// مدیر: فرم‌هایی که خرید آنها انجام و ثبت شده است
  static Future<List<PurchaseForm>> purchasedForms() async {
    final rows = await Backend.client
        .from('purchase_requests')
        .select(_formSel)
        .eq('status', 'purchased')
        .order('purchased_at', ascending: false)
        .limit(200);
    return [for (final r in rows) PurchaseForm.fromRow(Map<String, dynamic>.from(r))];
  }

  /// شمارنده‌ی خریدهای در جریان (برای عدد روی کارت مدیر)
  static Future<int> inProgressCount() async {
    try {
      return (await inProgressForms()).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<PurchaseItemRow>> items(String formId) async {
    final rows = await Backend.client
        .from('purchase_request_items')
        .select('category_id, kind, name, unit, quantity, note')
        .eq('request_id', formId)
        .order('line_no');
    return [for (final r in rows) PurchaseItemRow.fromRow(Map<String, dynamic>.from(r))];
  }

  static Future<List<PurchaseAttachment>> attachments(String formId) async {
    final rows = await Backend.client
        .from('purchase_attachments')
        .select('id, file_name, storage_path, mime_type, size_bytes')
        .eq('request_id', formId)
        .order('created_at');
    return [for (final r in rows) PurchaseAttachment.fromRow(Map<String, dynamic>.from(r))];
  }

  static Future<List<PurchaseUploadError>> uploadErrors(String formId) async {
    final rows = await Backend.client
        .from('purchase_upload_errors')
        .select('file_name, error_text, created_at')
        .eq('request_id', formId)
        .order('created_at', ascending: false)
        .limit(20);
    return [for (final r in rows) PurchaseUploadError.fromRow(Map<String, dynamic>.from(r))];
  }

  /// ذخیرهٔ پیش‌نویس؛ شناسهٔ فرم را برمی‌گرداند
  static Future<String> saveDraft({
    String? id,
    required String title,
    DateTime? needBy,
    required bool urgent,
    required String note,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await Backend.client.rpc('save_purchase_draft', params: {
      'p_id': id,
      'p_title': title,
      'p_need_by': needBy == null ? null : JalaliDate.isoDay(needBy),
      'p_urgent': urgent,
      'p_note': note,
      'p_items': items,
    });
    return '$res';
  }

  static Future<void> submit(String id) async {
    await Backend.client.rpc('submit_purchase_request', params: {'p_id': id});
  }

  static Future<void> decide({required String id, required String action, required String note}) async {
    await Backend.client.rpc('decide_purchase_request', params: {
      'p_id': id,
      'p_action': action,
      'p_note': note,
    });
  }

  /// آپلود فایل در فضای ذخیره، بعد ثبت در جدول. اگر هر کدام خطا بدهد، پرتاب می‌شود.
  static Future<void> uploadAttachment({
    required String requestId,
    required String path,
    required String fileName,
    required Uint8List bytes,
    required String mime,
  }) async {
    await Backend.client.storage.from(kPurchaseBucket).uploadBinary(
          path,
          bytes,
          fileOptions: sup.FileOptions(upsert: true, contentType: mime),
        );
    await Backend.client.rpc('register_purchase_attachment', params: {
      'p_request': requestId,
      'p_name': fileName,
      'p_path': path,
      'p_mime': mime,
      'p_size': bytes.length,
    });
  }

  static Future<void> deleteAttachment(String id) async {
    await Backend.client.rpc('delete_purchase_attachment', params: {'p_id': id});
  }

  /// ثبت خطای آپلود برای مدیر
  static Future<void> reportUploadError({required String requestId, required String fileName, required String error}) async {
    final uid = Backend.client.auth.currentUser!.id;
    await Backend.client.from('purchase_upload_errors').insert({
      'request_id': requestId,
      'file_name': fileName,
      'error_text': error,
      'reported_by': uid,
    });
  }

  static Future<Uint8List> download(String path) => Backend.client.storage.from(kPurchaseBucket).download(path);

  /// تعداد فرم‌های در انتظار تأیید (برای عدد روی کارت فرم)
  static Future<int> pendingCount() async {
    try {
      final rows = await Backend.client.from('purchase_requests').select('id').eq('status', 'pending');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  /// آیا کاربر فعلی مسئول خرید این فرم است؟
  static Future<bool> isRecipient(String formId) async {
    final uid = Backend.client.auth.currentUser!.id;
    final rows = await Backend.client
        .from('purchase_request_recipients')
        .select('profile_id')
        .eq('request_id', formId)
        .eq('profile_id', uid);
    return rows.isNotEmpty;
  }

  /// آپلود فاکتور یا عکس خرید توسط مسئول خرید
  static Future<void> uploadProof({
    required String requestId,
    required String path,
    required String fileName,
    required Uint8List bytes,
    required String mime,
  }) async {
    await Backend.client.storage.from(kPurchaseBucket).uploadBinary(
          path,
          bytes,
          fileOptions: sup.FileOptions(upsert: true, contentType: mime),
        );
    await Backend.client.from('purchase_attachments').insert({
      'request_id': requestId,
      'file_name': fileName,
      'storage_path': path,
      'mime_type': mime,
      'size_bytes': bytes.length,
    });
  }

  /// مسئول خرید: خرید انجام شد؛ فرم مستقیم به «خرید انجام شده» می‌رود
  static Future<void> markPurchaseDone(String id) async {
    await Backend.client.rpc('mark_purchase_done', params: {'p_id': id});
  }

  /// عنوان همهٔ دسته‌ها (بدون فیلتر نقش)
  static Future<Map<String, String>> categoryTitles() async {
    final rows = await Backend.client.from('purchase_categories').select('id, title');
    return {for (final r in rows) '${r['id']}': '${r['title']}'};
  }

  /// مربیان، معاونین و آشپز برای انتخاب گیرنده
  static Future<List<PurchaseStaff>> staffList() async {
    final rows = await Backend.client
        .from('profiles')
        .select('id, full_name, role')
        .eq('active', true)
        .inFilter('role', ['teacher', 'deputy', 'kitchen'])
        .order('full_name');
    return [
      for (final r in rows)
        PurchaseStaff(id: '${r['id']}', name: '${r['full_name'] ?? ''}', role: '${r['role']}'),
    ];
  }

  static Future<List<String>> recipientIds(String formId) async {
    final rows = await Backend.client
        .from('purchase_request_recipients')
        .select('profile_id')
        .eq('request_id', formId);
    return [for (final r in rows) '${r['profile_id']}'];
  }

  /// جایگزینی کامل لیست گیرندگان یک فرم (فقط مدیر)
  static Future<void> setRecipients(String formId, List<String> ids) async {
    await Backend.client.from('purchase_request_recipients').delete().eq('request_id', formId);
    if (ids.isEmpty) return;
    await Backend.client.from('purchase_request_recipients').insert([
      for (final id in ids) {'request_id': formId, 'profile_id': id},
    ]);
  }

  /// فرم‌های ارجاع‌شده به کاربر فعلی (با سیاست امنیتی فقط همان‌ها دیده می‌شوند)
  static Future<List<PurchaseForm>> assignedForms() async {
    final uid = Backend.client.auth.currentUser!.id;
    final links = await Backend.client
        .from('purchase_request_recipients')
        .select('request_id')
        .eq('profile_id', uid);
    final ids = [for (final l in links) '${l['request_id']}'];
    if (ids.isEmpty) return [];
    final rows = await Backend.client
        .from('purchase_requests')
        .select(_formSel)
        .inFilter('id', ids)
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) PurchaseForm.fromRow(Map<String, dynamic>.from(r))];
  }

  /// آدرس موقت برای نمایش عکس (یک ساعت اعتبار)
  static Future<String> signedUrl(String path) =>
      Backend.client.storage.from(kPurchaseBucket).createSignedUrl(path, 3600);

  /// ساخت PDF از تصاویر: هر تصویر یک صفحه (فایل‌های غیرتصویری نادیده گرفته می‌شوند)
  static Future<Uint8List> buildPdf(List<PurchaseFileData> files) async {
    final doc = pw.Document();
    for (final f in files) {
      if (!f.mime.startsWith('image/')) continue;
      final img = pw.MemoryImage(f.bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return doc.save();
  }
}
