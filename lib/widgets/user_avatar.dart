import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.radius = 20,
    this.imageUrl,
  });

  final String initials;
  final double radius;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String normalizedImageUrl =
        imageUrl?.trim() ?? '';

    final bool hasImage =
        normalizedImageUrl.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.sage,
      foregroundImage: hasImage
          ? NetworkImage(normalizedImageUrl)
          : null,
      onForegroundImageError: hasImage
          ? (
              Object exception,
              StackTrace? stackTrace,
            ) {
              debugPrint(
                'Unable to load profile image: '
                '$exception',
              );
            }
          : null,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: AppColors.forest,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}