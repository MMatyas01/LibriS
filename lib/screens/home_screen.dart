import 'package:flutter/material.dart';

import '../Services/auth_service.dart';
import '../Services/preferences_service.dart';
import 'login_screen.dart';


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
    return Scaffold(
      appBar: AppBar(
        title: const Text('LibriS'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            tooltip: 'Kijelentkezés',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Sikeres bejelentkezés!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}