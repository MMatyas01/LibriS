import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import 'login_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/section_header.dart';
import '../widgets/book_card_horizontal.dart';
import '../widgets/library_book_card.dart';
import '../widgets/book_cover.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    await PreferencesService().clearRememberMe();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LibriS',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Good morning, Maya.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        'What will you read today?',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _logout(context),
                        tooltip: 'Kijelentkezés',
                        icon: const Icon(Icons.logout,
                            color: AppColors.secondary),
                      ),
                      const UserAvatar(
                        initials: 'MC',
                        radius: 24,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SearchBarWidget(
                hintText: 'Search books or authors',
              ),
              const SizedBox(height: 32),
              const SectionHeader(
                title: 'Continue reading',
                actionText: 'View all',
              ),
              const SizedBox(height: 16),
              BookCardHorizontal(
                title: 'The Midnight Library',
                author: 'Matt Haig',
                progressText: '128/304 pages · 42%',
                progressValue: 128 / 304,
                backgroundColor: AppColors.sage,
                textColor: AppColors.charcoal,
                trailingWidget: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Resume reading'),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const SectionHeader(
                title: 'Your library',
                actionText: 'View all',
              ),
              const SizedBox(height: 16),
              const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LibraryBookCard(
                      title: 'The Midnight Library',
                      author: 'Matt Haig',
                      status: 'Reading',
                    ),
                    SizedBox(width: 16),
                    LibraryBookCard(
                      title: 'Normal People',
                      author: 'Sally Rooney',
                      status: 'Finished',
                    ),
                    SizedBox(width: 16),
                    LibraryBookCard(
                      title: 'The Seven Husbands of Evelyn Hugo',
                      author: 'Taylor Jenkins Reid',
                      status: 'Want to read',
                    ),
                    SizedBox(width: 16),
                    LibraryBookCard(
                      title: 'The Ocean at the End of the Lane',
                      author: 'Neil Gaiman',
                      status: 'Reading',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const SectionHeader(
                title: 'Popular this week',
                actionText: 'Explore',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const BookCover(width: 80),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Circe',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Madeline Miller',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const Text('4.3', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A myth retold. A voice reclaimed.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}