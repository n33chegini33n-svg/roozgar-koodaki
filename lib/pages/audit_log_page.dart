import 'package:flutter/material.dart';

import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';
import '../widgets/illustration_banner.dart';

enum _AuditRoleFilter {
  all('همه', Icons.groups_rounded, Color(0xFF01579B)),
  teachers('مربیان', Icons.cast_for_education_rounded, Color(0xFF00897B)),
  parents('والدین', Icons.family_restroom_rounded, Color(0xFF8E24AA)),
  management('کادر مدیریت', Icons.manage_accounts_rounded, Color(0xFFEF6C00)),
  students('دانش‌آموزان', Icons.backpack_rounded, Color(0xFF3949AB));

  const _AuditRoleFilter(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _AuditEditGroup {
  const _AuditEditGroup({
    required this.key,
    required this.action,
    required this.subject,
    required this.entries,
  });

  final String key;
  final String action;
  final String subject;
  final List<AuditEntry> entries;
}

/// گزارش تغییرات مهم، با دسترسی محدود بر اساس نقش بیننده.
class AuditLogPage extends StatefulWidget {
  final AppRole viewerRole;

  /// در صورت ندادن viewerRole، نقش نشست جاری استفاده می‌شود.
  AuditLogPage({super.key, AppRole? viewerRole})
      : viewerRole = viewerRole ?? Session.role;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  static const Color _navy = Color(0xFF01579B);

  bool _loading = true;
  List<AuditEntry> _all = [];
  String _query = '';
  _AuditRoleFilter _selectedFilter = _AuditRoleFilter.all;

  AppRole get _viewerRole => widget.viewerRole;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AuditLogService.getAll();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  _AuditRoleFilter _categoryForRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'teacher' ||
        normalized.contains('مربی') ||
        normalized.contains('معلم')) {
      return _AuditRoleFilter.teachers;
    }
    if (normalized == 'parent' || normalized.contains('ولی')) {
      return _AuditRoleFilter.parents;
    }
    if (normalized == 'student' || normalized.contains('دانش‌آموز')) {
      return _AuditRoleFilter.students;
    }
    if (normalized == 'admin' ||
        normalized == 'manager' ||
        normalized == 'deputy' ||
        normalized.contains('مدیر') ||
        normalized.contains('معاون') ||
        normalized.contains('ادمین')) {
      return _AuditRoleFilter.management;
    }
    return _AuditRoleFilter.all;
  }

  bool _canViewEntry(AuditEntry entry) {
    final category = _categoryForRole(entry.role);
    switch (_viewerRole) {
      case AppRole.admin:
        return true;
      case AppRole.manager:
        return entry.role.trim().toLowerCase() != 'admin' &&
            !entry.role.contains('ادمین');
      case AppRole.teacher:
        return category == _AuditRoleFilter.parents ||
            category == _AuditRoleFilter.students;
      case AppRole.deputy:
      case AppRole.parent:
      case AppRole.student:
      case AppRole.kitchen:
        return false;
    }
  }

  List<_AuditRoleFilter> get _availableFilters {
    switch (_viewerRole) {
      case AppRole.admin:
      case AppRole.manager:
        return _AuditRoleFilter.values;
      case AppRole.teacher:
        return const [
          _AuditRoleFilter.all,
          _AuditRoleFilter.parents,
          _AuditRoleFilter.students,
        ];
      case AppRole.deputy:
      case AppRole.parent:
      case AppRole.student:
      case AppRole.kitchen:
        return const [_AuditRoleFilter.all];
    }
  }

  List<AuditEntry> get _eligibleEntries => _all
      .where(_isEditOrPostCreationChange)
      .where(_canViewEntry)
      .toList();

  bool _isEditOrPostCreationChange(AuditEntry entry) {
    final action = entry.action.toLowerCase();
    return action.contains('ویرایش') ||
        action.contains('اصلاح') ||
        action.contains('تغییر') ||
        action.contains('به‌روزرسانی') ||
        action.contains('بروزرسانی') ||
        action.contains('بازگردانی');
  }

  String _actionFamily(String action) {
    final normalized = action.toLowerCase();
    if (normalized.contains('حضور') || normalized.contains('غیاب')) {
      return 'اصلاح حضور و غیاب';
    }
    if (normalized.contains('مالی') || normalized.contains('شهریه')) {
      return 'ویرایش اطلاعات مالی';
    }
    if (normalized.contains('کاربر')) return 'ویرایش اطلاعات کاربر';
    if (normalized.contains('دسترسی')) return 'تغییر دسترسی';
    if (normalized.contains('تغذیه') || normalized.contains('غذایی')) {
      return 'ویرایش اطلاعات تغذیه';
    }
    if (normalized.contains('ثبت‌نام') || normalized.contains('ثبت نام')) {
      return 'اصلاح پرونده ثبت‌نام';
    }
    return action.trim().isEmpty ? 'تغییر ثبت‌شده' : action.trim();
  }

  String _subjectFor(AuditEntry entry, String actionFamily) {
    var details = entry.details.trim();
    final leftArrow = details.indexOf('←');
    final rightArrow = details.indexOf('→');
    final arrowIndex = leftArrow < 0
        ? rightArrow
        : rightArrow < 0
            ? leftArrow
            : (leftArrow < rightArrow ? leftArrow : rightArrow);
    if (arrowIndex >= 0) details = details.substring(0, arrowIndex).trim();

    if (details.contains(':')) {
      details = details.substring(0, details.indexOf(':')).trim();
    } else if (actionFamily == 'ویرایش اطلاعات مالی') {
      final parts = details.split('•').map((part) => part.trim()).toList();
      details = parts.take(2).where((part) => part.isNotEmpty).join(' • ');
    } else if (actionFamily == 'ویرایش اطلاعات کاربر') {
      details = details.split('•').first.trim();
    }

    if (details.isEmpty) return 'شناسهٔ رویداد ${entry.id}';
    return details;
  }

  List<_AuditEditGroup> get _editGroups {
    final grouped = <String, List<AuditEntry>>{};
    final actions = <String, String>{};
    final subjects = <String, String>{};

    for (final entry in _eligibleEntries) {
      final action = _actionFamily(entry.action);
      final subject = _subjectFor(entry, action);
      final key = '${action.toLowerCase()}::${subject.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(entry);
      actions[key] = action;
      subjects[key] = subject;
    }

    return [
      for (final item in grouped.entries)
        _AuditEditGroup(
          key: item.key,
          action: actions[item.key]!,
          subject: subjects[item.key]!,
          entries: item.value,
        ),
    ];
  }

  int _countFor(_AuditRoleFilter filter) {
    final entries = _eligibleEntries;
    if (filter == _AuditRoleFilter.all) return entries.length;
    return entries
        .where((entry) => _categoryForRole(entry.role) == filter)
        .length;
  }

  List<_AuditEditGroup> get _visibleGroups {
    final query = _query.trim().toLowerCase();
    return _editGroups.map((group) {
      final roleFilteredEntries = group.entries.where((entry) {
        return _selectedFilter == _AuditRoleFilter.all ||
            _categoryForRole(entry.role) == _selectedFilter;
      }).toList();
      if (roleFilteredEntries.isEmpty) return null;
      if (query.isEmpty) {
        return _AuditEditGroup(
          key: group.key,
          action: group.action,
          subject: group.subject,
          entries: roleFilteredEntries,
        );
      }

      final topicMatches = group.action.toLowerCase().contains(query) ||
          group.subject.toLowerCase().contains(query);
      final matchingEntries = topicMatches
          ? roleFilteredEntries
          : roleFilteredEntries.where((entry) {
              return entry.actor.toLowerCase().contains(query) ||
                  entry.role.toLowerCase().contains(query) ||
                  entry.action.toLowerCase().contains(query) ||
                  entry.details.toLowerCase().contains(query);
            }).toList();
      if (matchingEntries.isEmpty) return null;
      return _AuditEditGroup(
        key: group.key,
        action: group.action,
        subject: group.subject,
        entries: matchingEntries,
      );
    }).whereType<_AuditEditGroup>().toList();
  }

  String _formatTimestamp(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final jalaliDate = JalaliDate.fromDateTime(date).formatted;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$jalaliDate  $hour:$minute:$second';
  }

  Widget _buildRoleFilters() {
    final filters = _availableFilters;
    if (filters.length == 1) return const SizedBox(height: 8);
    return SizedBox(
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter;
          return SizedBox(
            width: 120,
            child: Material(
              color: selected ? filter.color.withValues(alpha: 0.10) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _selectedFilter = filter),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? filter.color : const Color(0xFFE1E8EF),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(filter.icon, color: filter.color, size: 21),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          filter.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? filter.color : Colors.blueGrey.shade800,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 23),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: filter.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_countFor(filter)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: filter.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineEntry(AuditEntry entry) {
    final roleColor = _categoryForRole(entry.role).color;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF6C00),
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 48, color: const Color(0xFFFFCC80)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF4),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.actor.isEmpty ? 'کاربر نامشخص' : entry.actor,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.role.isEmpty ? 'نقش نامشخص' : entry.role,
                          style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        _formatTimestamp(entry.timestamp),
                        style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    entry.details.isEmpty ? entry.action : entry.details,
                    style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF37474F)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditGroup(_AuditEditGroup group) {
    final editCount = group.entries.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFFCC80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: const Text('✏️', style: TextStyle(fontSize: 19)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(group.subject, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '$editCount بار ویرایش',
                    style: const TextStyle(color: Color(0xFFB45309), fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            for (final entry in group.entries) _buildTimelineEntry(entry),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _visibleGroups;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('گزارش تغییرات'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: IllustrationBanner(
                      image: 'ill_audit_log.png',
                      title: 'گزارش تغییرات',
                      subtitle: 'ویرایش‌ها و اصلاح‌های ثبت‌شده به تفکیک موضوع',
                      tint: Color(0xFFE0F2F1),
                      imageHeight: 70,
                    ),
                  ),
                  _buildRoleFilters(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'جستجو در موضوع، کاربر، نقش یا متن تغییر',
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: groups.isEmpty
                        ? const Center(
                            child: Text('موردی با این نقش یا عبارت پیدا نشد', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: groups.length,
                            itemBuilder: (_, index) => _buildEditGroup(groups[index]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
