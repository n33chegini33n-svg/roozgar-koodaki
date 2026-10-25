import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../widgets/announcements_feed.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) => const BulletinPage(role: AppRole.parent);
}

