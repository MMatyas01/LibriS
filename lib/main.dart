import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BookPage(),
    );
  }
}

class BookPage extends StatelessWidget {
  const BookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('books').limit(1).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Text('Loading...'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No books found'),
            );
          }

          final book = snapshot.data!.docs.first;

          return Center(
            child: Text(book['title']),
          );
        },
      ),
    );
  }
}
