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

    return LayoutBuilder(
      builder: (context, constraints) {
        final coverWidth = constraints.maxWidth * 0.3; // 30% a borítónak

        return Container(
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Nem feszítjük ki a magasságot
            children: [
              // A borító körüli belső margó
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: coverWidth,
                  child: BookCover(
                    imageUrl: imageUrl,
                    borderRadius: 8, // Lekerekített sarkok
                  ),
                ),
              ),
              // A jobb oldali tartalom
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
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
                            theme.colorScheme.primary,
                          ),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                      if (trailingWidget != null) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.6,
                            child: trailingWidget!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}