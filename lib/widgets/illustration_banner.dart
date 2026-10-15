import 'package:flutter/material.dart';
import 'safe_image.dart';

/// نوار بالای صفحه: تصویر + عنوان + توضیح کوتاه
class IllustrationBanner extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final Color tint;
  final double imageHeight;

  const IllustrationBanner({
    super.key,
    required this.image,
    required this.title,
    this.subtitle = '',
    this.tint = const Color(0xFFE1F5FE),
    this.imageHeight = 84,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          SafeAssetImage(image, height: imageHeight, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
