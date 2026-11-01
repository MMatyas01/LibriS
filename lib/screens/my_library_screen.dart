import 'package:flutter/material.dart';

class MyLibraryScreen extends StatelessWidget {
  const MyLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
      ),
      body: const Center(
        child: Text('My Library Screen - Work in Progress'),
      ),
    );
  }
}