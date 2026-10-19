import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Services/auth_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.register(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message;

      switch (error.code) {
        case 'email-already-in-use':
          message =
              'Ehhez az e-mail-címhez már tartozik felhasználói fiók.';
          break;

        case 'invalid-email':
          message = 'Az e-mail-cím formátuma nem megfelelő.';
          break;

        case 'weak-password':
          message = 'A megadott jelszó túl gyenge.';
          break;

        case 'operation-not-allowed':
          message =
              'Az e-mailes regisztráció nincs engedélyezve.';
          break;

        case 'network-request-failed':
          message =
              'Nem sikerült kapcsolódni a hálózathoz.';
          break;

        case 'too-many-requests':
          message =
              'Túl sok próbálkozás történt. Próbáld újra később.';
          break;

        default:
          message =
              'Nem sikerült létrehozni a felhasználói fiókot.';
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
        title: const Text('Regisztráció'),
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
                      Icons.person_add_alt_1_rounded,
                      size: 80,
                      color: Color(0xFF5C3D99),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Fiók létrehozása',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Regisztrálj a LibriS használatához.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // E-mail-cím
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
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
                    const SizedBox(height: 16),

                    // Jelszó
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Jelszó',
                        prefixIcon:
                            const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible =
                                  !_isPasswordVisible;
                            });
                          },
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';

                        if (password.isEmpty) {
                          return 'Add meg a jelszavadat.';
                        }

                        if (password.length < 8) {
                          return 'A jelszó legalább 8 karakter legyen.';
                        }

                        if (!RegExp(r'[A-Z]')
                            .hasMatch(password)) {
                          return 'Legyen benne legalább egy nagybetű.';
                        }

                        if (!RegExp(r'[0-9]')
                            .hasMatch(password)) {
                          return 'Legyen benne legalább egy szám.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Jelszó megerősítése
                    TextFormField(
                      controller:
                          _confirmPasswordController,
                      enabled: !_isLoading,
                      obscureText:
                          !_isConfirmPasswordVisible,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _register();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Jelszó megerősítése',
                        prefixIcon:
                            const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Erősítsd meg a jelszavadat.';
                        }

                        if (value !=
                            _passwordController.text) {
                          return 'A két jelszó nem egyezik.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed:
                          _isLoading ? null : _register,
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
                          : const Text('Regisztráció'),
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text(
                        'Már van fiókod? Bejelentkezés',
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