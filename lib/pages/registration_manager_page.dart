import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../parent/parent_sections.dart' show kPageBg, softCard;
import '../theme/app_colors.dart';

class RegistrationManagerPage extends StatefulWidget {
  const RegistrationManagerPage({super.key});
  @override
  State<RegistrationManagerPage> createState() => _RegistrationManagerPageState();
}

class _RegistrationManagerPageState extends State<RegistrationManagerPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Backend.client
          .from('registration_records')
          .select('parent_id,data,status,submitted_at,updated_at')
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _records = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: const Text('پرونده‌های ثبت‌نام'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('بارگذاری پرونده‌ها انجام نشد\n$_error', textAlign: TextAlign.center))
              : _records.isEmpty
                  ? const Center(child: Text('هنوز پرونده‌ای ارسال نشده است.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) => _recordCard(_records[index]),
                    ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final name = '${data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
    final status = '${record['status'] ?? 'draft'}';
    return softCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.child_care_rounded)),
        title: Text(name.isEmpty ? 'پرونده بدون نام' : name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('وضعیت: ${_statusLabel(status)}\nشماره ولی: ${record['parent_id'] ?? '—'}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => _showDetails(data, status),
      ),
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'submitted':
        return 'ارسال‌شده';
      case 'approved':
        return 'تأییدشده';
      default:
        return 'پیش‌نویس';
    }
  }

  void _showDetails(Map<String, dynamic> data, String status) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim()),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('وضعیت: ${_statusLabel(status)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                for (final entry in data.entries)
                  if ('$entry'.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${entry.key}: ${entry.value}'),
                    ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن'))],
      ),
    );
  }
}
