import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Chat is display-only on mobile: no session backend is wired up, so this
/// always shows the desktop app's empty state with inert controls.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: AppColors.slate900.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(16),
            child: const Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Archive에서 "Chat with this article"를 눌러 대화를 시작하세요.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.slate800),
        const Expanded(
          flex: 2,
          child: Center(
            child: Text(
              '왼쪽에서 대화를 선택하세요.',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              border: Border.all(color: AppColors.slate700),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    enabled: false,
                    style: const TextStyle(color: AppColors.slate100, fontSize: 14),
                    decoration: InputDecoration.collapsed(
                      hintText: '기사에 대해 질문하세요...',
                      hintStyle: const TextStyle(color: AppColors.slate500),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.slate800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Send', style: TextStyle(color: AppColors.slate600, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
