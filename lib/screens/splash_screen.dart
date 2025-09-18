import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/splash_service.dart';
import '../utils/splash_utils.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SplashService(),
      child: Consumer<SplashService>(
        builder: (context, service, child) {
          // Use a FutureBuilder to call the navigation logic after the first frame
          return FutureBuilder(
            future: Future.delayed(
              const Duration(seconds: 3),
              () => service.checkFirstTimeUser(context),
            ),
            builder: (context, snapshot) {
              // The splash screen UI is built by buildSplashScreen
              return buildSplashScreen(context);
            },
          );
        },
      ),
    );
  }
}
