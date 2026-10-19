import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

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

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.sendPasswordResetEmail(
        email: _emailController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _emailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ha az e-mail-címhez tartozik fiók, elküldtük a '
            'jelszó-visszaállító linket.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message;

      switch (error.code) {
        case 'invalid-email':
          message = 'Az e-mail-cím formátuma nem megfelelő.';
          break;

        case 'too-many-requests':
          message =
              'Túl sok kérés érkezett. Próbáld újra később.';
          break;

        case 'network-request-failed':
          message =
              'Nem sikerült kapcsolódni a hálózathoz.';
          break;

        default:
          message =
              'Nem sikerült elküldeni a visszaállító e-mailt.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Váratlan hiba történt.'),
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
        title: const Text('Elfelejtett jelszó'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      size: 80,
                      color: Color(0xFF5C3D99),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Jelszó visszaállítása',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Add meg a regisztrációhoz használt '
                      'e-mail-címedet. Küldünk egy linket, '
                      'amellyel új jelszót állíthatsz be.',
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
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _sendResetEmail();
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'E-mail-cím',
                        hintText: 'pelda@email.com',
                        prefixIcon:
                            Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Add meg az e-mail-címedet.';
                        }

                        final emailPattern = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );

                        if (!emailPattern.hasMatch(email)) {
                          return 'Adj meg egy érvényes e-mail-címet.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          _isLoading ? null : _sendResetEmail,
                      style: FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(52),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Visszaállító link küldése',
                            ),
                    ),
                    if (_emailSent) ...[
                      const SizedBox(height: 24),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.mark_email_read_outlined,
                                color: Colors.green,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ellenőrizd a beérkező leveleket '
                                  'és a spam mappát is.',
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
                      child: const Text(
                        'Vissza a bejelentkezéshez',
                      ),
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