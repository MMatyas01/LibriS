import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final String hintText;
  final Widget? trailingIcon;
  final ValueChanged<String>? onChanged;

  const SearchBarWidget({
    super.key,
    required this.hintText,
    this.trailingIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.secondary,
        ),
        suffixIcon: trailingIcon,
        //
      ),
    );
  }
}