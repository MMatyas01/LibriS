import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BookCover extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double aspectRatio;
  final double borderRadius;

  const BookCover({
    super.key,
    this.imageUrl,
    this.width,
    this.aspectRatio = 2 / 3,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final cover = AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sage,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoal.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.menu_book,
                  color: AppColors.forest,
                  size: 32,
                ),
              )
            : const Icon(
                Icons.menu_book,
                color: AppColors.forest,
                size: 32,
              ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: cover);
    }
    return cover;
  }
}
