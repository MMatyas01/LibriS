// lib/widgets/book_card_horizontal.dart
import 'package:flutter/material.dart';

class BookCardHorizontal extends StatelessWidget {
  final String title;
  final String author;
  final String? imageUrl;
  final String? progressText;
  final double? progressValue;
  final Color backgroundColor;
  final Color textColor;
  final Widget? trailingWidget;
  final Widget? topRightWidget;
  final String? description;
  final int? readCount;

  const BookCardHorizontal({
    super.key,
    required this.title,
    required this.author,
    this.imageUrl,
    this.progressText,
    this.progressValue,
    required this.backgroundColor,
    required this.textColor,
    this.trailingWidget,
    this.topRightWidget,
    this.description,
    this.readCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      // A LayoutBuilderrel dinamikusan méretezzük a borítót a rendelkezésre álló helyhez képest
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A borító a kártya szélességének ~22%-a lesz, 
          // de minimum 60, maximum 100 pixel (hogy mobilon és tableten is jól nézzen ki)
          final double calculatedWidth = (constraints.maxWidth * 0.22).clamp(60.0, 100.0);
          
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dinamikus méretű borítókép
                    SizedBox(
                      width: calculatedWidth,
                      child: AspectRatio(
                        aspectRatio: 2 / 3, // Megtartja a klasszikus könyvborító arányt (pl. 80x120)
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null && imageUrl!.isNotEmpty
                              ? Image.network(
                                  imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.book, color: Colors.grey),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.book, color: Colors.grey),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Jobb oldali szöveges rész és gombok
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: topRightWidget != null ? 32 : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              author,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            // Többszöri olvasás jelzése
                            if (readCount != null && readCount! > 1) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: textColor.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Read $readCount times',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Leírás
                            if (description != null && description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withValues(alpha: 0.8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            
                            // Olvasási folyamat szövege
                            if (progressText != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                progressText!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                            ],
                            
                            // Olvasási folyamat csík
                            if (progressValue != null) ...[
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  backgroundColor: textColor.withValues(alpha: 0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                            
                            // Pl. "Resume reading" gomb, vagy státusz badge
                            if (trailingWidget != null) ...[
                              const SizedBox(height: 12),
                              trailingWidget!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // A jobb felső sarokban lévő ikon (pl. 3 pöttyös menü)
              if (topRightWidget != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: topRightWidget!,
                ),
            ],
          );
        },
      ),
    );
  }
}