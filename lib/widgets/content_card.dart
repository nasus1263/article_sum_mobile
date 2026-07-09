import 'package:flutter/material.dart';
import '../models/content_record.dart';
import '../services/content_repository.dart';
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
        color: AppColors.slate900,
        border: Border.all(color: AppColors.slate800),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
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
        border: Border.all(color: active ? AppColors.slate100 : AppColors.slate700),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: active ? AppColors.slate100 : AppColors.slate600,
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
        border: Border.all(color: AppColors.slate100),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate100),
      ),
    );
  }
}

class FavoriteStar extends StatefulWidget {
  final ContentRecord record;
  final VoidCallback onToggle;

  const FavoriteStar({
    super.key,
    required this.record,
    required this.onToggle,
  });

  @override
  State<FavoriteStar> createState() => _FavoriteStarState();
}

class _FavoriteStarState extends State<FavoriteStar> {
  late bool _favorited;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _favorited = widget.record.favoritedAt != null;
  }

  @override
  void didUpdateWidget(covariant FavoriteStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _favorited = widget.record.favoritedAt != null;
  }

  Future<void> _handleToggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ContentRepository();
      final nextState = !_favorited;
      await repo.setFavorite(widget.record.id, nextState);
      if (mounted) {
        setState(() => _favorited = nextState);
      }
      widget.onToggle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _favorited ? Icons.star : Icons.star_border,
        color: _favorited ? Colors.amber : AppColors.slate500,
        size: 20,
      ),
      onPressed: _handleToggle,
    );
  }
}
