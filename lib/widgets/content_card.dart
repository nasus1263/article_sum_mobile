import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ContentCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const ContentCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.slate900.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.slate800),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const Pill({super.key, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.indigo600 : AppColors.slate800,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: active ? Colors.white : AppColors.slate400,
        ),
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }
}

class TagBadge extends StatelessWidget {
  final String tag;

  const TagBadge({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tag == 'Article' ? AppColors.indigo600 : AppColors.slate700,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
      ),
    );
  }
}
