import 'package:flutter/material.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../models/private_message_model.dart';
import '../models/school_classes.dart';
import '../models/user_directory.dart';
import '../parent/parent_sections.dart' show kPageBg, softCard;
import '../theme/app_colors.dart';
import '../utils/jalali.dart';
import '../widgets/safe_image.dart';

/// فهرست گفتگوهای خصوصی
/// - معلم: نوآموزان کلاس خودش
/// - مدیر / ادمین: فقط خلاصه؛ برای دیدن متن باید دلیل بنویسند و در گزارش تغییرات ثبت می‌شود
class PrivateMessagesHub extends StatefulWidget {
  const PrivateMessagesHub({super.key});

  @override
  State<PrivateMessagesHub> createState() => _PrivateMessagesHubState();
}

class _PrivateMessagesHubState extends State<PrivateMessagesHub> {
  bool _loading = true;
  List<_Row> _rows = [];

  bool get _isReviewer => PermissionService.instance.can(Session.role, Perm.reviewPrivateMessages);
  bool get _isSender => PermissionService.instance.can(Session.role, Perm.sendPrivateMessage);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = <_Row>[];
    if (_isReviewer && !_isSender) {
      for (final s in await PrivateMessageService.summaries()) {
        rows.add(_Row(s.studentName, '${faDigits(s.count)} پیام • آخرین: ${faDigits(s.lastDate)}'));
      }
    } else if (_isSender) {
      for (final st in await UserDirectory.studentsOfClass(Session.className)) {
        final n = await PrivateMessageService.countFor(st.name);
        rows.add(_Row(st.name, n == 0 ? 'هنوز پیامی نیست' : '${faDigits(n)} پیام'));
      }
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _open(_Row r) async {
    if (_isReviewer && !_isSender) {
      final reason = await _askReason(r.name);
      if (reason == null) return;
      await AuditLogService.log(
        actor: Session.userName,
        role: Session.role.label,
        action: 'بازبینی پیام خصوصی',
        details: 'گفتگوی ${r.name} • دلیل: $reason',
      );
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatPage(studentName: r.name, readOnly: true)));
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatPage(studentName: r.name)));
    }
    _load();
  }

  Future<String?> _askReason(String student) async {
    final ctrl = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('دلیل بازبینی'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('پیام‌های $student خصوصی هستند. برای دیدن آن‌ها دلیل بنویسید. این کار در گزارش تغییرات ثبت می‌شود.',
                    style: const TextStyle(height: 1.6)),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  decoration: InputDecoration(hintText: 'مثلاً: رسیدگی به شکایت ولی', errorText: error, border: const OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              ElevatedButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  if (t.length < 6) {
                    setD(() => error = 'دلیل را کامل‌تر بنویسید (حداقل ۶ حرف)');
                    return;
                  }
                  Navigator.pop(ctx, t);
                },
                child: const Text('ثبت و مشاهده'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _isReviewer || _isSender;
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: Text(_isReviewer && !_isSender ? 'بازبینی پیام‌های خصوصی' : 'پیام خصوصی به اولیا'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !allowed
              ? const Center(child: Text('دسترسی به این بخش برای شما فعال نیست.', style: TextStyle(color: AppColors.textGrey)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 150, child: SafeAssetImage('scene_messages.png')),
                    if (_isReviewer && !_isSender)
                      softCard(
                        child: const Row(
                          children: [
                            Icon(Icons.lock_rounded, color: Color(0xFFF59E0B)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text('متن پیام‌ها بسته است. برای دیدن هر گفتگو باید دلیل ثبت کنید.',
                                  style: TextStyle(height: 1.6)),
                            ),
                          ],
                        ),
                      ),
                    if (_rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('گفتگویی وجود ندارد.', style: TextStyle(color: AppColors.textGrey))),
                      ),
                    for (final r in _rows)
                      softCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: ListTile(
                          onTap: () => _open(r),
                          leading: ChildAvatar(name: r.name, size: 46),
                          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                          subtitle: Text(r.subtitle),
                          trailing: Icon(_isReviewer && !_isSender ? Icons.lock_open_rounded : Icons.chevron_left_rounded),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _Row {
  final String name;
  final String subtitle;
  const _Row(this.name, this.subtitle);
}

/// گفتگوی خصوصی دربارهٔ یک نوآموز
class PrivateChatPage extends StatefulWidget {
  final String studentName;
  final bool readOnly;
  const PrivateChatPage({super.key, required this.studentName, this.readOnly = false});

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<PrivateMessage> _msgs = [];
  bool _loading = true;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await PrivateMessageService.thread(widget.studentName);
    final st = await UserDirectory.studentByName(widget.studentName);
    final perms = PermissionService.instance;
    // معلم فقط برای کلاس خودش؛ ولی فقط برای فرزند خودش
    bool can = !widget.readOnly && perms.can(Session.role, Perm.sendPrivateMessage);
    if (can) {
      if (Session.role == AppRole.teacher) {
        can = st != null && sameClass(st.className, Session.className);
      } else if (Session.role == AppRole.parent) {
        can = widget.studentName == Session.childName;
      }
    }
    if (!mounted) return;
    setState(() {
      _msgs = list;
      _canSend = can;
      _loading = false;
    });
    _jumpToEnd();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !_canSend) return;
    _ctrl.clear();
    await PrivateMessageService.send(
      studentName: widget.studentName,
      senderName: Session.userName,
      senderRole: Session.role == AppRole.teacher ? 'teacher' : 'parent',
      text: text,
    );
    // فقط ثبت اینکه پیام رفت؛ متن پیام در گزارش تغییرات نمی‌آید
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'ارسال پیام خصوصی',
      details: 'گفتگوی ${widget.studentName}',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: Text('گفتگو دربارهٔ ${widget.studentName}'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (widget.readOnly)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3CD),
              padding: const EdgeInsets.all(8),
              child: const Text('حالت بازبینی؛ این مشاهده در گزارش تغییرات ثبت شده است.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _msgs.isEmpty
                    ? const Center(child: Text('هنوز پیامی نیست.', style: TextStyle(color: AppColors.textGrey)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _msgs.length,
                        itemBuilder: (context, i) {
                          final m = _msgs[i];
                          final mine = !widget.readOnly &&
                              ((m.senderRole == 'teacher' && Session.role == AppRole.teacher) ||
                                  (m.senderRole == 'parent' && Session.role == AppRole.parent));
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 420),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: mine ? const Color(0xFFD8E9F9) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.senderName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy)),
                                  const SizedBox(height: 4),
                                  Text(m.text, style: const TextStyle(height: 1.5)),
                                  const SizedBox(height: 4),
                                  Text('${faDigits(m.date)} ${faDigits(m.time)}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_canSend)
            SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'پیام خصوصی...',
                          filled: true,
                          fillColor: kPageBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _send,
                      style: IconButton.styleFrom(backgroundColor: AppColors.navy),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
