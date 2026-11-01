import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();

  bool _isChecking = false;
  bool _isResending = false;
  bool _isSigningOut = false;
  String? _infoMessage;
  String? _errorMessage;

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _infoMessage = null;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Ha valamiért kijelentkezett, visszairányítjuk a loginra
        await _signOutAndGoToLogin();
        return;
      }

      // Fontos: reload() nélkül a emailVerified cache-elt értéke jönne vissza
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed != null && refreshed.emailVerified) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const MainNavigationScreen(),
          ),
          (route) => false,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Your email is not verified yet. Please check your inbox and click the link.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _infoMessage = null;
      _errorMessage = null;
    });

    try {
      await _authService.sendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _infoMessage =
            'A new verification email has been sent to ${widget.email}.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not send the verification email. Please try again later.';
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOutAndGoToLogin() async {
    if (_isSigningOut) return;
    setState(() {
      _isSigningOut = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await _authService.signOut();
    } catch (_) {
      // csendben elnyeljük, a navigáció a lényeg
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isBusy = _isChecking || _isResending || _isSigningOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'Check your inbox',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to ${widget.email}. '
                    'Click the link to activate your account, then come back here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (_infoMessage != null) ...[
                    Text(
                      _infoMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.primary),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: isBusy ? null : _checkVerification,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _isChecking
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('I have verified my email'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: isBusy ? null : _resendEmail,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _isResending
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend verification email'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isBusy ? null : _signOutAndGoToLogin,
                    child: const Text('Back to log in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}