import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../parent/parent_sections.dart';
import '../models/announcement_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';

/// فهرست اطلاعیه‌هایی که این نقش مجاز به دیدنشان است
class AnnouncementsFeed extends StatefulWidget {
  final AppRole role;
  const AnnouncementsFeed({super.key, required this.role});

  @override
  State<AnnouncementsFeed> createState() => _AnnouncementsFeedState();
}

class _AnnouncementsFeedState extends State<AnnouncementsFeed> {
  bool _loading = true;
  List<Announcement> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AnnouncementService.visibleTo(widget.role, className: Session.className);
    if (!mounted) return;
    setState(() {
      _items = list.take(50).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    }
    if (_items.isEmpty) {
      return softCard(
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: Text('هنوز اطلاعیه‌ای ثبت نشده است.', style: TextStyle(color: AppColors.textGrey))),
        ),
      );
    }
    return Column(
      children: [
        for (final a in _items)
          softCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3CD),
                  child: Icon(Icons.campaign_rounded, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                      const SizedBox(height: 4),
                      Text(a.body, style: const TextStyle(color: AppColors.textGrey, height: 1.5)),
                      const SizedBox(height: 6),
                      Text(
                        '${a.sender} • ${JalaliDate.fromDateTime(DateTime.fromMillisecondsSinceEpoch(a.createdAt)).formatted}',
                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// صفحهٔ کامل اطلاعیه‌ها (برای معلم و ولی)
class BulletinPage extends StatelessWidget {
  final AppRole role;
  const BulletinPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'اطلاعیه‌ها و بخشنامه‌ها',
      image: 'ill_circular_rules.png',
      child: AnnouncementsFeed(role: role),
    );
  }
}
