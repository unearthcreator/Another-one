import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
// Riverpod for state management
import 'package:map_mvp_project/src/app.dart'; 
// Your main app widget
import 'package:map_mvp_project/services/error_handler.dart'; 
// Contains logger + error-handling setup
import 'package:map_mvp_project/services/orientation_util.dart'; 
// For locking device orientation
import 'package:flutter/services.dart'; 
// For SystemChrome, etc.
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; 
// Mapbox Flutter SDK
import 'package:hive_flutter/hive_flutter.dart'; 
// Local database

import 'package:map_mvp_project/services/geocoding_service.dart'; 
// For address → coords lookups

/// The main entry point of the application.
void main() {
  // 1. Setup global error handling (Flutter framework + zoned guard).
  setupErrorHandling();

  // 2. Wrap the app initialization in runZonedGuarded to catch async errors.
  runAppWithErrorHandling(_initializeApp);

  // 3. Provide Mapbox Access Token from environment variables.
  String ACCESS_TOKEN = const String.fromEnvironment("ACCESS_TOKEN");
  MapboxOptions.setAccessToken(ACCESS_TOKEN);

  // 4. Hide system UI overlays (status bar, navigation bar).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
}

/// A function that sets up and initializes everything before running the app.
Future<void> _initializeApp() async {
  // 1. Ensure Flutter binding is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  logger.i('Initializing app, locking orientation, and initializing Hive.');

  // 2. Initialize Hive for local data storage (boxes).
  await Hive.initFlutter();

  // 3. Lock device orientation. (If it fails, log the error but continue.)
  await lockOrientation().catchError((error, stackTrace) {
    logger.e('Failed to set orientation', error: error, stackTrace: stackTrace);
  });

  // 4. (Optional) test geocoding logic — only if you actually want to see an example result at startup.
  try {
    final coords = await GeocodingService.fetchCoordinatesFromAddress(
      "1600 Amphitheatre Parkway, Mountain View, CA",
    );
    logger.i('Test geocoding result: $coords');
  } catch (e, stackTrace) {
    logger.e('Test geocoding failed', error: e, stackTrace: stackTrace);
  }

  // 5. Finally, run the Flutter app safely.
  _runAppSafely();
}

/// Actually runs the Flutter app inside a try-catch block (for safety).
void _runAppSafely() {
  try {
    // 1. Launch the Flutter app using Riverpod’s ProviderScope and your root widget (MyApp).
    runApp(const ProviderScope(child: MyApp()));
  } catch (e, stackTrace) {
    // 2. If something goes wrong while building or launching the widget tree,
    //    log it here (though this rarely happens at this point).
    logger.e('Error while running the app', error: e, stackTrace: stackTrace);
  }
}