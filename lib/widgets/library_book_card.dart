import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'book_cover.dart';

class LibraryBookCard extends StatelessWidget {
  final String title;
  final String author;
  final String status;
  final double width;
  final String? imageUrl;

  const LibraryBookCard({
    super.key,
    required this.title,
    required this.author,
    required this.status,
    this.width = 100,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          BookCover(
            width: width,
            imageUrl: imageUrl,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            author,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.secondary, // Halványabb szín
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}