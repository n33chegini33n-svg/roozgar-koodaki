import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/announcement_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';

/// Google Meet link sharing through the existing, role-scoped announcements.
/// Server-side RLS must still enforce which announcements each account can read/write.
class VideoMeetingsPage extends StatefulWidget {
  final AppRole role;

  const VideoMeetingsPage({super.key, required this.role});

  @override
  State<VideoMeetingsPage> createState() => _VideoMeetingsPageState();
}

class _VideoMeetingsPageState extends State<VideoMeetingsPage> {
  static const _marker = 'جلسه تصویری | ';
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  List<Announcement> _meetings = [];

  bool get _canCreate =>
      Session.role == widget.role &&
      (widget.role == AppRole.admin ||
          widget.role == AppRole.manager ||
          widget.role == AppRole.deputy ||
          widget.role == AppRole.teacher);

  bool get _isStaffMeeting =>
      widget.role == AppRole.admin ||
      widget.role == AppRole.manager ||
      widget.role == AppRole.deputy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final visible = await AnnouncementService.visibleTo(
        widget.role,
        className: Session.className,
      );
      if (!mounted) return;
      setState(() {
        _meetings = visible
            .where((item) => item.title.startsWith(_marker))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(
        'دریافت فهرست جلسه‌ها ممکن نشد. اتصال و دسترسی حساب را بررسی کنید.',
        error: true,
      );
    }
  }

  Uri? _meetUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'meet.google.com') {
      return null;
    }
    return uri;
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _createMeet() async {
    final uri = Uri.parse('https://meet.google.com/new');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('بازکردن Google Meet ممکن نشد.', error: true);
    }
  }

  Future<void> _publish() async {
    if (!_canCreate ||
        (_isStaffMeeting
            ? widget.role == AppRole.teacher
            : Session.className.trim().isEmpty)) {
      _message('برای این حساب امکان ایجاد این جلسه وجود ندارد.', error: true);
      return;
    }
    final title = _title.text.trim();
    final link = _meetUri(_link.text);
    if (title.isEmpty || link == null) {
      _message(
        'عنوان را بنویسید و لینک معتبر Google Meet را وارد کنید.',
        error: true,
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final description = _description.text.trim();
      await AnnouncementService.send(
        title: '$_marker$title',
        body:
            '${description.isEmpty ? '' : '$description\n'}${link.toString()}',
        audience: _isStaffMeeting ? Audience.staff : Audience.classOnly,
        className: _isStaffMeeting ? '' : Session.className,
      );
      _title.clear();
      _description.clear();
      _link.clear();
      await _load();
      _message(
        _isStaffMeeting
            ? 'پیوند برای کادر مدرسه فرستاده شد.'
            : 'پیوند برای کلاس ${Session.className} فرستاده شد.',
      );
    } catch (_) {
      _message(
        'ارسال پیوند انجام نشد. دسترسی حساب یا اتصال را بررسی کنید.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _join(Announcement meeting) async {
    final uri = _meetUri(meeting.body.split('\n').last);
    if (uri == null) {
      _message('پیوند این جلسه معتبر نیست.', error: true);
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('بازکردن Google Meet ممکن نشد.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audience = !_canCreate
        ? 'کلاس ${Session.className}'
        : (_isStaffMeeting
              ? 'کادر مدرسه'
              : 'والدین و نوآموزان کلاس ${Session.className}');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('کلاس و جلسهٔ تصویری'),
          backgroundColor: const Color(0xFF01579B),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _canCreate
                          ? 'ایجاد جلسه برای $audience'
                          : 'جلسه‌های دعوت‌شده برای $audience',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تماس در Google Meet انجام می‌شود. ابتدا جلسه را باز کنید، سپس پیوند آن را اینجا وارد و برای مخاطبان بفرستید.',
                    ),
                    if (_canCreate) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _createMeet,
                        icon: const Icon(Icons.video_call),
                        label: const Text('ساخت جلسه در Google Meet'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'عنوان جلسه',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _description,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'توضیح یا زمان جلسه (اختیاری)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _link,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'پیوند Google Meet',
                          hintText: 'https://meet.google.com/...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _sending ? null : _publish,
                        icon: const Icon(Icons.send),
                        label: Text(
                          _sending
                              ? 'در حال ارسال...'
                              : 'فرستادن پیوند برای $audience',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _canCreate
                  ? 'جلسه‌های قابل مشاهده برای شما'
                  : 'برای پیوستن، روی جلسهٔ دعوت‌شده بزنید.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_meetings.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('جلسه‌ای برای این حساب پیدا نشد.'),
                ),
              )
            else
              for (final meeting in _meetings)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.video_camera_front),
                    ),
                    title: Text(meeting.title.substring(_marker.length)),
                    subtitle: Text(
                      '${meeting.body.split('\n').take(meeting.body.split('\n').length - 1).join('\n')}\n${JalaliDate.fromDateTime(DateTime.fromMillisecondsSinceEpoch(meeting.createdAt)).formatted}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'پیوستن به جلسه',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _join(meeting),
                    ),
                    onTap: () => _join(meeting),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
