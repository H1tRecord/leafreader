import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LeafReader'),
      ),
      body: const Center(
        child: Text(
          'Welcome to LeafReader',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
