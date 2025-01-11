import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'services/error_handler.dart';
import 'services/validate_mapbox_token.dart';
import 'services/hive_util.dart';
import 'src/app.dart';

void main() {
  setupErrorHandling();
  runAppWithErrorHandling(_initializeApp);
}

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  logger.i('Initializing app');
  await initializeHive();

  validateMapboxAccessToken();

  _runAppSafely();
}

void _runAppSafely() {
  try {
    runApp(const ProviderScope(child: MyApp()));
  } catch (e, stackTrace) {
    logger.e('Error while running the app', error: e, stackTrace: stackTrace);
  }
}