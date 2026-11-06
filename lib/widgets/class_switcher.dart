import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../theme/app_colors.dart';

/// انتخاب کلاس برای مربی یا معاونی که چند کلاس دارد.
/// با انتخاب، Session.className عوض می‌شود تا همهٔ صفحه‌ها روی همان کلاس کار کنند.
class ClassSwitcher extends StatelessWidget {
  final VoidCallback onChanged;
  const ClassSwitcher({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final names = Session.classNames;
    if (names.length < 2) return const SizedBox.shrink();
    final current = names.contains(Session.className) ? Session.className : names.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.class_rounded, color: AppColors.navy),
          const SizedBox(width: 8),
          const Text('کلاس:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current,
                isExpanded: true,
                items: [
                  for (final n in names) DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v == null || v == Session.className) return;
                  Session.className = v;
                  onChanged();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
