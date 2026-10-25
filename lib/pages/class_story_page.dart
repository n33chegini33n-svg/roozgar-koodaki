import 'package:flutter/material.dart';

import '../models/permissions.dart'; // Session, AppRole

class ClassStoryPage extends StatefulWidget {
  final String userRole;
  const ClassStoryPage({super.key, required this.userRole});

  @override
  State<ClassStoryPage> createState() => _ClassStoryPageState();
}

class _ClassStoryPageState extends State<ClassStoryPage> {
  final List<Map<String, dynamic>> posts = [
    {
      'id': '1',
      'author': Session.role == AppRole.teacher ? Session.userName : 'مربی کلاس ${Session.className}',
      'time': '۱ ساعت پیش',
      'content': 'امروز نوآموزان گلمون در زنگ سفال‌گری کارهای بسیار خلاقانه‌ای درست کردند! همه عالی بودند. 🎨✨',
      'likes': 12,
      'isLiked': false,
      'comments': ['خدا قوت به مربی مهربان', 'آرتین خیلی از این زنگ تعریف می‌کرد!'],
      'imageColor': 0xFFB3E5FC,
      'type': 'کلاس آفتاب'
    },
    {
      'id': '2',
      'author': 'مدیریت روزگار کودکی',
      'time': 'دیروز',
      'content': 'اولیاء محترم، اردوی علمی/تفریحی هفته آینده روز سه‌شنبه برگزار می‌شود. لطفا رضایت‌‌نامه‌ها را تا یکشنبه تحویل دهید.',
      'likes': 28,
      'isLiked': true,
      'comments': ['ممنون از برنامه‌ریزی عالیتون'],
      'imageColor': 0xFFFFF9C4,
      'type': 'اطلاعیه عمومی'
    },
  ];

  final TextEditingController _postTextController = TextEditingController();

  void _addNewPost() {
    if (_postTextController.text.trim().isEmpty) return;

    setState(() {
      posts.insert(0, {
        'id': DateTime.now().toString(),
        'author': widget.userRole == 'teacher' ? Session.userName : 'مدیریت روزگار کودکی',
        'time': 'همین الان',
        'content': _postTextController.text,
        'likes': 0,
        'isLiked': false,
        'comments': [],
        'imageColor': 0xFFE1BEE7,
        'type': widget.userRole == 'teacher' ? 'کلاس آفتاب' : 'اطلاعیه عمومی'
      });
      _postTextController.clear();
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 پست جدید با موفقیت در داستان کلاس منتشر شد!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📸 انتشار داستان جدید در کلاس/مدرسه',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _postTextController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'توضیحات فعالیت امروز، عکس یا اطلاعیه خود را بنویسید...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('افزودن عکس به‌زودی فعال می‌شود')),
                    ),
                    icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF0288D1)),
                    label: const Text('افزودن عکس'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('پیام صوتی به‌زودی فعال می‌شود')),
                    ),
                    icon: const Icon(Icons.mic_rounded, color: Colors.purple),
                    label: const Text('صوت/پیام صوتی'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _addNewPost,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('انتشار در داستان کلاس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: (widget.userRole == 'teacher' || widget.userRole == 'manager')
          ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFB300),
        foregroundColor: Colors.black87,
        onPressed: _openCreatePostModal,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('پست جدید', style: TextStyle(fontWeight: FontWeight.bold)),
      )
          : null,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF0288D1),
                            child: Icon(Icons.school_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post['author'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Row(
                                children: [
                                  Text(post['time'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(post['type'], style: const TextStyle(fontSize: 10, color: Color(0xFF0288D1))),
                                  )
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(post['content'], style: const TextStyle(fontSize: 15, height: 1.4)),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color(post['imageColor']),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_rounded, size: 50, color: Color(0xFF0288D1)),
                            SizedBox(height: 6),
                            Text('تصویر/ویدیو فعالیت نوآموزان', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              post['isLiked'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: post['isLiked'] ? Colors.red : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                post['isLiked'] = !post['isLiked'];
                                post['likes'] += post['isLiked'] ? 1 : -1;
                              });
                            },
                          ),
                          Text('${post['likes']} پسندیدند'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openCommentsDialog(post),
                            icon: const Icon(Icons.mode_comment_outlined),
                            label: Text('${post['comments'].length} دیدگاه'),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openCommentsDialog(Map<String, dynamic> post) {
    final TextEditingController commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💬 دیدگاه‌های اولیاء و مربیان'),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: post['comments'].isEmpty
                        ? const Center(child: Text('هنوز دیدگاهی ثبت نشده است'))
                        : ListView.builder(
                      shrinkWrap: true,
                      itemCount: post['comments'].length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        title: Text(post['comments'][i], style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentCtrl,
                          decoration: const InputDecoration(
                            hintText: 'ارسال نظر...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF0288D1)),
                        onPressed: () {
                          if (commentCtrl.text.trim().isNotEmpty) {
                            setState(() {
                              post['comments'].add(commentCtrl.text);
                            });
                            setDialogState(() {});
                            commentCtrl.clear();
                          }
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
            ],
          ),
        ),
      ),
    );
  }
}
