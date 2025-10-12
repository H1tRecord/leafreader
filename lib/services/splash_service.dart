import 'package:flutter/material.dart';
import '../utils/prefs_helper.dart';
import 'android_intent_service.dart';

class SplashService with ChangeNotifier {
  Future<void> checkFirstTimeUser(BuildContext context) async {
    if (AndroidIntentService.consumeSplashNavigationGuard()) {
      return;
    }

    // Check if user has completed onboarding
    bool onboardingCompleted = await PrefsHelper.isOnboardingCompleted();

    // Guard against using BuildContext after widget is disposed
    if (!context.mounted) return;

    if (!onboardingCompleted) {
      // Navigate to onboarding
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      // Navigate directly to home
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
