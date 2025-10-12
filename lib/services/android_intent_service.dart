import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../screens/epub_reader_screen.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/txt_reader_screen.dart';

class AndroidIntentService {
  AndroidIntentService._();

  static final AndroidIntentService instance = AndroidIntentService._();
  static const MethodChannel _channel = MethodChannel(
    'com.example.leafreader/intent',
  );
  static bool _suppressSplashNavigation = false;

  bool _initialized = false;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _initialized = true; // Mark as initialized to avoid duplicate checks.
      return;
    }

    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _openPath(navigatorKey, path);
        }
      }
    });

    try {
      final initialPath = await _channel.invokeMethod<String>(
        'getInitialIntent',
      );
      if (initialPath != null && initialPath.isNotEmpty) {
        _openPath(navigatorKey, initialPath);
        unawaited(_channel.invokeMethod('consumeInitialIntent'));
      }
    } on MissingPluginException {
      // Plugin not ready (non-Android build); reset initialization state.
      _initialized = false;
    } catch (_) {
      // Ignore other channel errors.
    }
  }

  void _openPath(GlobalKey<NavigatorState> navigatorKey, String filePath) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPath(navigatorKey, filePath);
      });
      return;
    }

    final context = navigator.context;
    final currentRoute = ModalRoute.of(context);
    final isSplashRoute =
        currentRoute == null || currentRoute.settings.name == '/';
    if (isSplashRoute) {
      _suppressSplashNavigation = true;
      navigator.pushNamedAndRemoveUntil('/home', (route) => false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _presentReader(navigatorKey, filePath);
      });
      return;
    }

    _presentReader(navigatorKey, filePath);
  }

  void _presentReader(GlobalKey<NavigatorState> navigatorKey, String filePath) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _presentReader(navigatorKey, filePath);
      });
      return;
    }

    final extension = p.extension(filePath).toLowerCase();
    final fileName = p.basename(filePath);

    final destination = switch (extension) {
      '.epub' => EpubReaderScreen(filePath: filePath, fileName: fileName),
      '.pdf' => PdfReaderScreen(filePath: filePath, fileName: fileName),
      '.txt' => TxtReaderScreen(filePath: filePath, fileName: fileName),
      _ => null,
    };

    if (destination == null) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unsupported file type: $fileName')),
        );
      }
      return;
    }

    navigator.push(MaterialPageRoute(builder: (_) => destination));
  }

  static bool consumeSplashNavigationGuard() {
    if (!_suppressSplashNavigation) {
      return false;
    }
    _suppressSplashNavigation = false;
    return true;
  }
}
