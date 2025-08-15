import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LeafReader'),
        actions: [
          // Filter icon
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filter functionality
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Filter tapped')));
            },
          ),
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings screen
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome to LeafReader', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
