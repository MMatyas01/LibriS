import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';

class BookRequestScreen extends StatefulWidget {
  const BookRequestScreen({super.key});

  @override
  State<BookRequestScreen> createState() => _BookRequestScreenState();
}

class _BookRequestScreenState extends State<BookRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _yearController = TextEditingController();
  final _publisherController = TextEditingController();
  final _imageUrlController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _yearController.dispose();
    _publisherController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to submit a request.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final yearText = _yearController.text.trim();
      await FirebaseFirestore.instance.collection('book_requests').add({
        'userId': user.uid,
        'proposedTitle': _titleController.text.trim(),
        'proposedAuthor': _authorController.text.trim(),
        'isbn': _cleanOptional(_isbnController.text),
        'publicationYear':
            yearText.isEmpty ? null : int.tryParse(yearText),
        'publisher': _cleanOptional(_publisherController.text),
        'imageUrl': _cleanOptional(_imageUrlController.text),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'adminNote': '',
        'seenByUserAt': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted for review.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verticalGap = MediaQuery.sizeOf(context).height * 0.02;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Request a book', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                'Help our catalogue grow.',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: verticalGap),
              Text(
                "Share the book's details. We'll review your request before it can join the catalogue.",
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: verticalGap * 1.5),

              _fieldLabel(context, 'Book title'),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'e.g. The Atlas of Quiet Places',
                  counterText: '',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Title is required.';
                  if (v.length > 200) return 'Title is too long (max 200).';
                  return null;
                },
              ),
              SizedBox(height: verticalGap),

              _fieldLabel(context, 'Author'),
              TextFormField(
                controller: _authorController,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: "Enter the author's name",
                  counterText: '',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Author is required.';
                  if (v.length > 200) return 'Author is too long (max 200).';
                  return null;
                },
              ),
              SizedBox(height: verticalGap),

              _fieldLabel(context, 'ISBN (optional)'),
              TextFormField(
                controller: _isbnController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx\- ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  hintText: 'Enter 10- or 13-digit ISBN',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null;
                  final digits = v.replaceAll(RegExp(r'[^0-9Xx]'), '');
                  if (digits.length != 10 && digits.length != 13) {
                    return 'ISBN must be 10 or 13 digits.';
                  }
                  return null;
                },
              ),
              SizedBox(height: verticalGap),

              _fieldLabel(context, 'Publication year (optional)'),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  hintText: 'e.g. 2018',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null;
                  final year = int.tryParse(v);
                  if (year == null || year < 1000 || year > 2100) {
                    return 'Enter a valid year (1000–2100).';
                  }
                  return null;
                },
              ),
              SizedBox(height: verticalGap),

              _fieldLabel(context, 'Publisher (optional)'),
              TextFormField(
                controller: _publisherController,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Enter publisher name',
                  counterText: '',
                ),
              ),
              SizedBox(height: verticalGap),

              _fieldLabel(context, 'Cover image URL (optional)'),
              TextFormField(
                controller: _imageUrlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Paste a link to the cover image',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null;
                  final uri = Uri.tryParse(v);
                  if (uri == null ||
                      !(uri.isScheme('http') || uri.isScheme('https'))) {
                    return 'Enter a valid http(s) URL.';
                  }
                  return null;
                },
              ),
              SizedBox(height: verticalGap * 1.5),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.forest,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A request, not a catalogue addition',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "After submission, your request is pending approval. "
                            "It won't add a book to your library automatically.",
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: verticalGap * 1.5),

              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Submit request for review'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.charcoal,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}