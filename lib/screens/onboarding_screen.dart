import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/onboarding_service.dart';
import '../utils/onboarding_utils.dart';
import '../utils/theme_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          OnboardingService()
            ..init(Provider.of<ThemeProvider>(context, listen: false)),
      child: Consumer<OnboardingService>(
        builder: (context, service, child) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(
                            OnboardingStep.values.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == service.currentStep.index
                                    ? Theme.of(context).colorScheme.primary
                                    : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[600]
                                          : Colors.grey[300]),
                              ),
                            ),
                          ),
                        ),
                        if (service.currentStep != OnboardingStep.tutorial)
                          TextButton(
                            onPressed: () => service.skipOnboarding(context),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: LinearProgressIndicator(
                      value:
                          (service.currentStep.index + 1) /
                          OnboardingStep.values.length,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: service.pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        buildWelcomeStep(context),
                        buildPermissionsStep(context, service),
                        buildFolderSelectionStep(context, service),
                        buildThemeSelectionStep(context, service),
                        buildTutorialStep(context),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: service.currentStep == OnboardingStep.welcome
                              ? 0.0
                              : 1.0,
                          child: SizedBox(
                            width: 120,
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  service.currentStep == OnboardingStep.welcome
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      service.previousStep();
                                    },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Previous',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              switch (service.currentStep) {
                                case OnboardingStep.welcome:
                                  service.nextStep();
                                  break;
                                case OnboardingStep.permissions:
                                  final status = await service
                                      .checkStoragePermission();
                                  if (status.isGranted) {
                                    service.nextStep();
                                  } else {
                                    showLoadingDialog(
                                      context,
                                      'Requesting storage permissions...',
                                    );
                                    await service.requestStoragePermissions(
                                      context,
                                      showDialogs: true,
                                    );
                                    if (context.mounted &&
                                        Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                    final newStatus = await service
                                        .checkStoragePermission();
                                    if (newStatus.isGranted) {
                                      service.nextStep();
                                    }
                                  }
                                  break;
                                case OnboardingStep.folderSelection:
                                  if (service.selectedFolderPath != null) {
                                    service.nextStep();
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('No Folder Selected'),
                                        content: const Text(
                                          'Please select a folder to continue.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  break;
                                case OnboardingStep.themeSelection:
                                  service.nextStep();
                                  break;
                                case OnboardingStep.tutorial:
                                  service.completeOnboarding(context);
                                  break;
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  service.getButtonText(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  service.currentStep == OnboardingStep.tutorial
                                      ? Icons.check
                                      : Icons.arrow_forward,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
