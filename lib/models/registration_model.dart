import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';

class RegistrationDraft {
  final Map<String, String> values;
  final bool accepted;
  final String status; // 'submitted' (or 'pending'), 'approved', 'rejected'
  final String? rejectionReason;
  final String? attachmentUrl;

  const RegistrationDraft({
    required this.values,
    required this.accepted,
    this.status = 'submitted',
    this.rejectionReason,
    this.attachmentUrl,
  });

  Map<String, dynamic> toJson() => {
        'values': values,
        'accepted': accepted,
        'status': status,
        'rejection_reason': rejectionReason,
        'attachment_url': attachmentUrl,
      };

  factory RegistrationDraft.fromJson(Map<String, dynamic> json) {
    final raw = json['values'];
    return RegistrationDraft(
      values: raw is Map ? Map<String, String>.from(raw.map((k, v) => MapEntry('$k', '$v'))) : {},
      accepted: json['accepted'] == true,
      status: json['status']?.toString() ?? 'submitted',
      rejectionReason: json['rejection_reason']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
    );
  }
}

class RegistrationDraftService {
  static const _key = 'registration_draft_v1';

  static Future<RegistrationDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    RegistrationDraft? localDraft;
    if (raw != null && raw.isNotEmpty) {
      try {
        localDraft = RegistrationDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    if (!Backend.ready) return localDraft;

    final user = Backend.client.auth.currentUser;
    if (user == null) return localDraft;

    try {
      final remote = await Backend.client
          .from('registration_records')
          .select('*')
          .eq('parent_id', user.id)
          .maybeSingle();

      if (remote != null) {
        final dataRaw = remote['data'];
        final Map<String, String> values = dataRaw is Map
            ? Map<String, String>.from(dataRaw.map((k, v) => MapEntry('$k', '$v')))
            : (localDraft?.values ?? {});
        final remoteStatus = remote['status']?.toString() ?? 'submitted';
        final remoteReason = remote['rejection_reason']?.toString();
        final remoteAttachment = remote['attachment_url']?.toString();

        return RegistrationDraft(
          values: values,
          accepted: localDraft?.accepted ?? true,
          status: remoteStatus,
          rejectionReason: remoteReason,
          attachmentUrl: remoteAttachment,
        );
      }
    } catch (_) {}

    return localDraft;
  }

  static Future<void> save(RegistrationDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  static Future<void> submit(RegistrationDraft draft) async {
    await save(draft);
    if (!Backend.ready) return;

    final user = Backend.client.auth.currentUser;
    if (user == null) throw Exception('حساب کاربر پیدا نشد');

    final payload = {
      'parent_id': user.id,
      'data': draft.values,
      'status': draft.status,
      'rejection_reason': draft.rejectionReason,
      'attachment_url': draft.attachmentUrl,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    };

    final existing = await Backend.client
        .from('registration_records')
        .select('parent_id')
        .eq('parent_id', user.id)
        .maybeSingle();

    try {
      if (existing == null) {
        await Backend.client.from('registration_records').insert(payload);
      } else {
        await Backend.client
            .from('registration_records')
            .update(payload)
            .eq('parent_id', user.id);
      }
    } catch (_) {
      final fallbackPayload = {
        'parent_id': user.id,
        'data': draft.values,
        'status': draft.status,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (existing == null) {
        await Backend.client.from('registration_records').insert(fallbackPayload);
      } else {
        await Backend.client
            .from('registration_records')
            .update(fallbackPayload)
            .eq('parent_id', user.id);
      }
    }
  }

  static Future<void> updateStatus({
    required String parentId,
    required String status,
    String? rejectionReason,
  }) async {
    if (!Backend.ready) return;
    try {
      await Backend.client.from('registration_records').update({
        'status': status,
        'rejection_reason': rejectionReason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('parent_id', parentId);
    } catch (_) {
      await Backend.client.from('registration_records').update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('parent_id', parentId);
    }
  }
}
