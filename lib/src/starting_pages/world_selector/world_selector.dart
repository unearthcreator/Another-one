import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // For direct Box usage if needed
import 'package:map_mvp_project/models/world_config.dart';
import 'package:map_mvp_project/repositories/local_worlds_repository.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/widgets/carousel.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/widgets/world_selector_buttons.dart';
import 'package:map_mvp_project/repositories/local_app_preferences.dart'; // For last-used index
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/earth_creator.dart';
import 'package:map_mvp_project/src/earth_pages/earth_map_page.dart';

class WorldSelectorPage extends StatefulWidget {
  const WorldSelectorPage({super.key});

  @override
  State<WorldSelectorPage> createState() => _WorldSelectorPageState();
}

class _WorldSelectorPageState extends State<WorldSelectorPage> {
  late LocalWorldsRepository _worldsRepo;

  /// We'll store all the fetched worlds here after loading from Hive.
  List<WorldConfig> _worldConfigs = [];

  /// Simple loading/error-handling flags
  bool _isLoading = false;
  String? _errorMessage;

  /// This will be the index we pass to the Carousel as the starting centered card.
  /// If user has zero worlds, we default to 4 ("middle" card).
  int _carouselInitialIndex = 4;

  @override
  void initState() {
    super.initState();
    logger.i('WorldSelectorPage initState -> init repo, fetch worlds, load index');
    _worldsRepo = LocalWorldsRepository();

    // 1) Fetch worlds from Hive.
    _fetchAllWorlds();

    // 2) Load "last used" index from local prefs (if any).
    _loadLastUsedIndex();
  }

  /// Asynchronously fetch the "last used" index from local app prefs,
  /// storing it in `_carouselInitialIndex` if found. If none found, remain at 4.
  Future<void> _loadLastUsedIndex() async {
    try {
      final idx = await LocalAppPreferences.getLastUsedCarouselIndex();
      logger.i('Got lastUsedCarouselIndex=$idx from prefs');
      if (mounted) {
        setState(() => _carouselInitialIndex = idx);
      }
    } catch (e) {
      logger.w('Could not read lastUsedCarouselIndex: $e. Using default=4.');
      // We leave _carouselInitialIndex at 4 by default.
    }
  }

  /// Fetch all stored WorldConfig items from Hive.
  Future<void> _fetchAllWorlds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final worlds = await _worldsRepo.getAllWorldConfigs();
      logger.i('Fetched worlds from Hive: $worlds');

      setState(() {
        _worldConfigs = worlds;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      logger.e('Error fetching worlds', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Failed to load worlds: $e';
        _isLoading = false;
      });
    }
  }

  /// Clear all worlds from Hive + reset the stored index + re-fetch to update.
  Future<void> _handleClearAllWorlds() async {
    try {
      await _worldsRepo.clearAllWorldConfigs();
      logger.i('Cleared all worlds from Hive.');
      await _fetchAllWorlds(); // re-fetch

      // Also reset the stored last-used index to 4
      await LocalAppPreferences.setLastUsedCarouselIndex(4);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All worlds cleared.')),
        );
      }
    } catch (e, stackTrace) {
      logger.e('Error clearing worlds', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clear all worlds.')),
        );
      }
    }
  }

   /// Called when the centered card is tapped in the Carousel.
  /// We'll do the navigation logic here, so we can .then(...) re-fetch on return.
void _handleCardTap(int index) {
  final world = _worldConfigs.firstWhere(
    (w) => w.carouselIndex == index,
    orElse: () => WorldConfig(
      id: 'default',
      name: '',
      mapType: 'standard',
      timeMode: 'auto',
      manualTheme: null,
      carouselIndex: index,
    ), // Use a default WorldConfig
  );

  if (world.name.isEmpty) {
    logger.i('No world exists for index=$index. Navigating to EarthCreatorPage.');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EarthCreatorPage(carouselIndex: index),
      ),
    ).then((didSave) async {
      if (didSave == true) {
        logger.i('User saved a new world -> re-fetch & realign carousel.');
        await _fetchAllWorlds();
      }
    });
  } else {
    logger.i('World exists for index=$index. Navigating to EarthMapPage.');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EarthMapPage(worldConfig: world),
      ),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    logger.i('Building WorldSelectorPage widget');

    // 1) Show spinner if loading
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2) Error handling
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    // 3) Otherwise, normal UI:
    try {
      final screenHeight = MediaQuery.of(context).size.height;
      final availableHeight = screenHeight - 56 - 40;
      logger.d('ScreenHeight=$screenHeight, availableHeight=$availableHeight');

      // If (after fetch) we truly have zero worlds, fallback to 4.
      // Otherwise, rely on what we just read from preferences.
      if (_worldConfigs.isEmpty) {
        logger.i('No worlds found => forcing carousel index=4');
        _carouselInitialIndex = 4;
      }

      return Scaffold(
        body: Column(
          children: [
            // (A) Buttons row at the top
            WorldSelectorButtons(
              onClearAll: _handleClearAllWorlds,
            ),

            // (B) The carousel
            Expanded(
              child: Center(
                child: CarouselWidget(
                  key: ValueKey(_carouselInitialIndex), // Add a unique key
                  availableHeight: availableHeight,
                  initialIndex: _carouselInitialIndex,
                  worldConfigs: _worldConfigs,
                  onCenteredCardTapped: _handleCardTap,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      logger.e('Error building WorldSelectorPage', error: e, stackTrace: stackTrace);
      return const Scaffold(
        body: Center(child: Text('Error loading World Selector')),
      );
    }
  }
}
