import 'package:flutter/material.dart';
import '../utils/prefs_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Add initialization logic here
    Future.delayed(const Duration(seconds: 3), () {
      // Check if this is the first time opening the app
      _checkFirstTimeUser();
    });
  }

  Future<void> _checkFirstTimeUser() async {
    // Check if user has completed onboarding
    bool onboardingCompleted = await PrefsHelper.isOnboardingCompleted();

    // Guard against using BuildContext after widget is disposed
    if (!mounted) return;

    if (!onboardingCompleted) {
      // Navigate to onboarding
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      // Navigate directly to home
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use theme-aware surface color
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Image.asset(
              'assets/logo.png',
              height: 150,
              // If you don't have a logo yet, you can comment this out
              // and use a placeholder or just text
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.book,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            // App name
            Text(
              'LeafReader',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
