import 'package:flutter/material.dart';

import '../models/permissions.dart'; // Session, AppRole
import '../models/audit_log_model.dart'; // AuditLogService

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _managerUnlocked = false;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool get _isManagerRole =>
      Session.role == AppRole.manager || Session.role == AppRole.deputy || Session.role == AppRole.admin;

  @override
  void dispose() {
    _reasonController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': Session.role == AppRole.teacher ? Session.userName : 'مربی کلاس ${Session.className}',
      'text': 'سلام وقتتون بخیر، آرتین امروز در زنگ کاردستی بسیار عالی و خلاقانه عمل کرد. 🎨',
      'time': '۱۰:۱۵',
      'isMe': false,
      'type': 'text',
    },
    {
      'sender': 'شما (والدین)',
      'text': 'سلام، خیلی ممنون از زحمات شما و انرژی مثبتی که به بچه‌ها می‌دید.',
      'time': '۱۰:۲۰',
      'isMe': true,
      'type': 'text',
    },
  ];

  void _sendMessage({String type = 'text', String content = ''}) {
    String textToSend = content.isEmpty ? _messageController.text.trim() : content;
    if (textToSend.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': Session.role == AppRole.teacher ? Session.userName : 'شما (والدین)',
        'text': textToSend,
        'time': 'همین الان',
        'isMe': true,
        'type': type,
      });
      if (type == 'text') {
        _messageController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isManagerRole && !_managerUnlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('گفتگوی خصوصی معلم و ولی'),
          backgroundColor: const Color(0xFF01579B),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person_rounded, size: 64, color: Color(0xFF01579B)),
                    const SizedBox(height: 16),
                    const Text(
                      'حریم خصوصی گفتگوها',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'گفتگوی مربی و ولی کاملاً محرمانه است. طبق قوانین مجموعه، ورود مدیریت به گفتگوهای خصوصی مستلزم ثبت «علت نظارت» و ثبت در گزارش تغییرات (Audit Log) می‌باشد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'دلیل ورود و علت نظارت (الزامی)',
                        hintText: 'مثلاً: بررسی شکایت ولی درباره فعالیت کلاسی',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF01579B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.verified_user_rounded, color: Colors.white),
                        label: const Text('ثبت دلیل و بازکردن گفتگو', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onPressed: () async {
                          final reason = _reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('لطفاً دلیل ورود را ثبت کنید'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          await AuditLogService.log(
                            actor: Session.userName,
                            role: Session.role.label,
                            action: 'دسترسی به پیام‌های خصوصی معلم و ولی',
                            details: 'علت نظارت: $reason',
                          );

                          if (!context.mounted) return;
                          setState(() {
                            _managerUnlocked = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('دسترسی صادر شد و در گزارش تغییرات سیستم ثبت گردید'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF0288D1),
                      child: Icon(Icons.person_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Session.role == AppRole.teacher ? Session.userName : 'مربی کلاس ${Session.className}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text('🟢 آنلاین - گفتگو امن اولیاء و مربی', style: TextStyle(fontSize: 11, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    bool isMe = msg['isMe'];
                    String type = msg['type'] ?? 'text';

                    return Align(
                      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFE1F5FE) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg['sender'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? const Color(0xFF01579B) : Colors.orange.shade800)),
                            const SizedBox(height: 6),
                            if (type == 'text')
                              Text(msg['text'], style: const TextStyle(fontSize: 14, height: 1.3))
                            else if (type == 'voice')
                              Row(
                                children: [
                                  const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF0288D1), size: 32),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(msg['text'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const Text('0:15 ثانیه - ویس صوتی', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (type == 'image')
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.lightBlue.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_rounded, size: 45, color: Color(0xFF0288D1)),
                                          SizedBox(height: 4),
                                          Text('تصویر ارسال‌شده از گالری', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(msg['text'], style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(msg['time'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, color: Color(0xFF0288D1)),
                      tooltip: 'ارسال ویس صوتی',
                      onPressed: () => _sendMessage(type: 'voice', content: '🎙️ پیام صوتی جدید'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image_rounded, color: Color(0xFF0288D1)),
                      tooltip: 'ارسال تصویر',
                      onPressed: () => _sendMessage(type: 'image', content: '📷 عکس تکالیف آرتین'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'پیام خود را به مربی بنویسید...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        onSubmitted: (_) => _sendMessage(type: 'text'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0288D1),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () => _sendMessage(type: 'text'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
