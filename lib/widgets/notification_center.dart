import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/permissions.dart';
import '../pages/registration_page.dart';
import '../pages/registration_manager_page.dart';
import '../pages/purchase_form_page.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../utils/jalali.dart';

/// دکمهٔ زنگوله با شمارندهٔ موارد خوانده‌نشده. برای AppBar هر صفحه استفاده شود.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n = await NotificationService.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'اعلان‌ها و پیگیری',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread'),
        child: const Icon(Icons.notifications_rounded),
      ),
    );
  }
}

/// صفحهٔ اعلان‌ها و پیگیری: هر مورد را که لمس کنید خوانده می‌شود
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<AppNotice> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await NotificationService.mine();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  IconData _icon(String kind) => switch (kind) {
        'registration' => Icons.child_care_rounded,
        'attendance' => Icons.how_to_reg_rounded,
        'message' => Icons.chat_bubble_rounded,
        'purchase' => Icons.shopping_cart_rounded,
        _ => Icons.campaign_rounded,
      };

  String _when(DateTime d) => '${JalaliDate.fromDateTime(d).formatted} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// با لمس اعلان، از فهرست و از سرور حذف می‌شود و صفحهٔ مربوطه باز می‌شود
  Future<void> _tap(AppNotice n) async {
    setState(() => _items = _items.where((x) => x.id != n.id).toList());
    try {
      await Backend.client.from('notifications').delete().eq('id', n.id);
    } catch (_) {}
    Widget? page = switch (n.target) {
      'parent_registration' => const RegistrationPage(),
      'manager_registration' => RegistrationManagerPage(),
      'purchase_form' => const PurchaseFormPage(),
      'purchase_assigned' => const PurchaseBuyingPage(managerView: false),
      'purchase_manager' => const PurchaseManagerPage(),
      _ => null,
    };
    if (page == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('اعلان‌ها و پیگیری'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'به‌روزرسانی'),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : _items.isEmpty
                    ? const Center(child: Text('موردی برای پیگیری نیست', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final n = _items[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: n.isRead ? const Color(0xFFEDEDED) : const Color(0xFFE1F5FE),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              enabled: !n.isRead,
                              onTap: n.isRead ? null : () => _tap(n),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                                child: Icon(_icon(n.kind), color: AppColors.navy),
                              ),
                              title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                              subtitle: Text('${n.body}\n${_when(n.createdAt)}', style: const TextStyle(fontSize: 12)),
                              trailing: (n.target == null || n.isRead) ? null : const Icon(Icons.chevron_left_rounded),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
