import 'package:flutter/material.dart';

import '../models/content_record.dart';
import '../theme/app_colors.dart';

void showFullTextDialog(BuildContext context, ContentRecord record) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate800),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (record.data.title != null)
                          Text(
                            record.data.title!,
                            style: const TextStyle(
                              color: AppColors.slate100,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          record.url,
                          style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    record.data.original ?? '',
                    style: const TextStyle(color: AppColors.slate200, fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
