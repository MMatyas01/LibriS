import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _emailSent = true;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'If an account exists for this email address, '
              'a password reset link has been sent.',
            ),
          ),
        );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      final String message;

      switch (error.code) {
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Unable to connect to the network.';
          break;
        default:
          message = 'Unable to send the password reset email.';
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message)),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Reset your password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Enter the email address associated with your account. '
                      'We will send you a link to create a new password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _sendResetEmail();
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        hintText: 'example@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (String? value) {
                        final String email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Enter your email address.';
                        }

                        final RegExp emailPattern = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );

                        if (!emailPattern.hasMatch(email)) {
                          return 'Enter a valid email address.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _sendResetEmail,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Send reset link'),
                    ),
                    if (_emailSent) ...[
                      const SizedBox(height: 24),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.mark_email_read_outlined,
                                color: Colors.green,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Check your inbox and spam folder.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
