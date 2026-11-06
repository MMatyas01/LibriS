import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_colors.dart';

/// Közös bottom sheet az olvasási haladás frissítéséhez.
///
/// - Frissíti a `currentPage`-et és beállítja a `lastReadAt`-et.
/// - Ha az új oldalszám eléri a `totalPages`-t, `status: 'finished'`-re vált
///   és gratuláló dialógust mutat (cím + borító).
/// - Visszaad `true`-t, ha sikeres volt a mentés.
Future<bool> showUpdateProgressSheet({
  required BuildContext context,
  required String entryId,
  required int currentPage,
  required int totalPages,
  required String bookTitle,
  required String currentStatus,
  String? coverUrl,
}) async {
  double sliderValue = currentPage.toDouble();
  final pagesReadController = TextEditingController();

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext innerContext, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24.0,
              right: 24.0,
              top: 24.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update Reading Progress',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Text(
                  'Page ${sliderValue.toInt()} of $totalPages',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.forest),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: sliderValue,
                  min: 0,
                  max: totalPages.toDouble(),
                  divisions: totalPages > 0 ? totalPages : 1,
                  label: sliderValue.round().toString(),
                  activeColor: AppColors.forest,
                  onChanged: (double value) {
                    setModalState(() {
                      sliderValue = value;
                      pagesReadController.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pagesReadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'How many pages read today?',
                    hintText: 'Adds to current page',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.menu_book),
                  ),
                  onChanged: (value) {
                    final pagesRead = int.tryParse(value);
                    if (pagesRead != null) {
                      setModalState(() {
                        final newTotal = (currentPage + pagesRead).toDouble();
                        sliderValue =
                            newTotal.clamp(0.0, totalPages.toDouble());
                      });
                    } else if (value.isEmpty) {
                      setModalState(() {
                        sliderValue = currentPage.toDouble();
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final pageToSave = sliderValue.toInt();
                      final isFinishing = pageToSave >= totalPages &&
                          currentStatus != 'finished';

                      try {
                        final updateData = <String, dynamic>{
                          'currentPage': pageToSave,
                          'lastReadAt': FieldValue.serverTimestamp(),
                        };
                        if (isFinishing) {
                          updateData['status'] = 'finished';
                        }

                        await FirebaseFirestore.instance
                            .collection('library_entries')
                            .doc(entryId)
                            .update(updateData);

                        if (innerContext.mounted) {
                          Navigator.of(innerContext).pop(true);
                        }

                        if (!context.mounted) return;

                        if (isFinishing) {
                          _showCongratulationsDialog(
                            context,
                            bookTitle,
                            coverUrl,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Progress saved successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error saving progress: $e');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Progress',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );

  return result ?? false;
}

void _showCongratulationsDialog(
  BuildContext context,
  String bookTitle,
  String? coverUrl,
) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You finished',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 150,
                        color: AppColors.sage,
                        child: const Icon(Icons.book, color: AppColors.forest),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 150,
                      color: AppColors.sage,
                      child: const Icon(Icons.book, color: AppColors.forest),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              bookTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}