import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_mvp_project/services/error_handler.dart'; 
import 'package:map_mvp_project/l10n/app_localizations.dart'; 
import 'package:map_mvp_project/src/starting_pages/main_menu/widgets/menu_button.dart';

/// MainMenuPage acts as the primary entry screen for your application.
/// It displays a simple black background and places navigational buttons
/// in the center of the screen, leading to various parts of the app.
class MainMenuPage extends ConsumerWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Log that the MainMenuPage build method has started, and retrieve localized strings.
    logger.i('Building MainMenuPage');
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      // Provide a solid black background.
      backgroundColor: Colors.black,

      // 2) Use a Stack (though not strictly necessary) so that later you can
      //    easily add other layers behind or in front if desired.
      body: Stack(
        children: [
          // (A) The background color is already set to black via Scaffold,
          //     so we could omit an extra container. However, this container
          //     is left here in case you need to layer additional elements in the future.
          Positioned.fill(
            child: Container(color: Colors.black),
          ),

          // (B) The menu itself, centered on top of the black background.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Only as tall as needed
              children: [
                // Button 1: World Selector
                MenuButton(
                  icon: Icons.public,
                  label: loc.goToWorlds, 
                  onPressed: () {
                    logger.i('Navigating to World Selector Page');
                    Navigator.pushNamed(context, '/world_selector');
                  },
                ),
                const SizedBox(height: 20),

                // Button 2: Options
                MenuButton(
                  icon: Icons.settings,
                  label: loc.options, 
                  onPressed: () {
                    logger.i('Options button clicked');
                    Navigator.pushNamed(context, '/options');
                  },
                ),
                const SizedBox(height: 20),

                // Button 3: Subscription
                MenuButton(
                  icon: Icons.star,
                  label: loc.subscription, 
                  onPressed: () {
                    logger.i('Subscription button clicked');
                    // Future: subscription logic
                  },
                ),
                const SizedBox(height: 20),

                // Button 4: Exit
                MenuButton(
                  icon: Icons.exit_to_app,
                  label: loc.exit, 
                  onPressed: () {
                    logger.i('Exit button clicked');
                    // Future: exit logic (e.g., confirm before closing)
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}