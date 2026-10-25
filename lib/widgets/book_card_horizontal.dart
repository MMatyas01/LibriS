import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'book_cover.dart';

class BookCardHorizontal extends StatelessWidget {
  final String title;
  final String author;
  final String? progressText;
  final double? progressValue;
  final String? imageUrl;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? trailingWidget;

  const BookCardHorizontal({
    super.key,
    required this.title,
    required this.author,
    this.progressText,
    this.progressValue,
    this.imageUrl,
    this.backgroundColor,
    this.textColor,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg = backgroundColor ?? AppColors.white;
    final effectiveText = textColor ?? AppColors.charcoal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(
            imageUrl: imageUrl,
            width: 70,
            borderRadius: 8,
          ),
          const SizedBox(width: 16),
          // Adatok
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: effectiveText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: effectiveText.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progressText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    progressText!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: effectiveText.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progressValue ?? 0,
                    backgroundColor: effectiveText.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary, // A forest szín
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                if (trailingWidget != null) ...[
                  const SizedBox(height: 12),
                  trailingWidget!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}