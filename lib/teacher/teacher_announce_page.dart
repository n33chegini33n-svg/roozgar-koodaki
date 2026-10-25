import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart' show SectionScaffold, softCard;
import '../models/announcement_model.dart';
import '../models/permissions.dart';

class TeacherAnnouncePage extends StatefulWidget {
  const TeacherAnnouncePage({super.key});

  @override
  State<TeacherAnnouncePage> createState() => _TeacherAnnouncePageState();
}

class _TeacherAnnouncePageState extends State<TeacherAnnouncePage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _send() async {
    if (_sending) return;
    final perms = PermissionService.instance;
    if (!perms.allows(Session.role, Perm.sendParentAnnouncement, className: Session.className)) {
      _snack('شما اجازهٔ ارسال اطلاعیه برای این کلاس را ندارید', Colors.red);
      return;
    }
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('موضوع و متن اطلاعیه را کامل کنید', Colors.orange.shade800);
      return;
    }
    setState(() => _sending = true);
    await AnnouncementService.send(
      title: title,
      body: body,
      audience: Audience.classOnly,
      className: Session.className,
    );
    if (!mounted) return;
    _title.clear();
    _body.clear();
    setState(() => _sending = false);
    _snack('✅ اطلاعیه برای والدین ${Session.className} ارسال شد', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'اطلاعیه برای اولیا',
      image: 'ill_announcement.png',
      child: Column(
        children: [
          softCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ارسال اطلاعیه جدید', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text('مخاطب: والدین ${Session.className}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 10),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'موضوع اطلاعیه', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'متن پیام برای والدین...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'در حال ارسال...' : 'ارسال به والدین'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

