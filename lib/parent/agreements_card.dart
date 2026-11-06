import 'package:flutter/material.dart';
import '../services/tuition_agreement_service.dart';
import '../theme/app_colors.dart';
import 'parent_sections.dart' show softCard;

/// توافق‌نامه‌های در انتظار تأیید ولی؛ فقط وقتی متنی باشد نمایش داده می‌شود
class ParentAgreementsCard extends StatefulWidget {
  const ParentAgreementsCard({super.key});

  @override
  State<ParentAgreementsCard> createState() => _ParentAgreementsCardState();
}

class _ParentAgreementsCardState extends State<ParentAgreementsCard> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  final Map<String, bool> _agreed = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await TuitionAgreementService.parentPending();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(String id) async {
    setState(() => _busy.add(id));
    try {
      await TuitionAgreementService.confirm(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تأیید شما ثبت شد'), backgroundColor: Colors.green),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${'$e'.replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final a in _items)
          softCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('توافق‌نامه: ${(a['students'] is Map ? a['students']['full_name'] : '') ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD5E3F0)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText('${a['body'] ?? ''}', style: const TextStyle(height: 1.8)),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _agreed[a['id']] ?? false,
                  onChanged: (v) => setState(() => _agreed['${a['id']}'] = v ?? false),
                  title: const Text('متن را خواندم، آگاه هستم و موافقم.', style: TextStyle(fontSize: 13)),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (_agreed['${a['id']}'] == true && !_busy.contains('${a['id']}'))
                        ? () => _confirm('${a['id']}')
                        : null,
                    icon: const Icon(Icons.verified_rounded),
                    label: Text(_busy.contains('${a['id']}') ? 'در حال ثبت...' : 'تأیید توافق‌نامه'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}
