import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';

class RegistrationDraft {
  final Map<String, String> values;
  final bool accepted;
  const RegistrationDraft({required this.values, required this.accepted});

  Map<String, dynamic> toJson() => {'values': values, 'accepted': accepted};

  factory RegistrationDraft.fromJson(Map<String, dynamic> json) {
    final raw = json['values'];
    return RegistrationDraft(
      values: raw is Map ? Map<String, String>.from(raw.map((k, v) => MapEntry('$k', '$v'))) : {},
      accepted: json['accepted'] == true,
    );
  }
}

class RegistrationDraftService {
  static const _key = 'registration_draft_v1';

  static Future<RegistrationDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RegistrationDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(RegistrationDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  static Future<void> submit(RegistrationDraft draft) async {
    if (!Backend.ready) {
      await save(draft);
      return;
    }
    final user = Backend.client.auth.currentUser;
    if (user == null) throw Exception('حساب کاربر پیدا نشد');
    final payload = {
      'parent_id': user.id,
      'data': draft.values,
      'status': 'submitted',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    };
    final existing = await Backend.client
        .from('registration_records')
        .select('parent_id')
        .eq('parent_id', user.id)
        .maybeSingle();
    if (existing == null) {
      await Backend.client.from('registration_records').insert(payload);
    } else {
      await Backend.client
          .from('registration_records')
          .update(payload)
          .eq('parent_id', user.id);
    }
  }
}
