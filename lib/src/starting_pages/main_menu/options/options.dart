import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // for logger
import 'package:map_mvp_project/providers/locale_provider.dart'; // your Riverpod provider for locale
import 'package:map_mvp_project/l10n/app_localizations.dart'; // for strings

/// This page presents user-adjustable settings, such as language selection
/// (via a dropdown) and volume control (currently just a placeholder).
class OptionsPage extends ConsumerStatefulWidget {
  const OptionsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends ConsumerState<OptionsPage> {
  // A list of supported locales, each tied to a human-readable name.
  final List<(Locale locale, String displayName)> _availableLocales = [
    (const Locale('en'), 'English'),
    (const Locale('en', 'US'), 'English (US)'),
    (const Locale('sv'), 'Svenska'),
  ];

  // A local variable to track the user’s chosen locale (for the drop-down).
  // We'll initialize it in `initState` or from Riverpod in `build`.
  Locale? _selectedLocale;

  @override
  void initState() {
    super.initState();
    // You can read the current locale from Riverpod here.
    // We'll do so in build() to ensure we always show the latest.
  }

  @override
  Widget build(BuildContext context) {
    logger.i('Building OptionsPage.');

    // 1) Get current localized strings (so we can display text for the UI).
    final loc = AppLocalizations.of(context)!;

    // 2) Read the current locale from Riverpod. 
    final currentLocale = ref.watch(localeProvider);

    // 3) Make sure our drop-down is in sync with the app's locale.
    //    If `_selectedLocale` is null or out-of-sync, update it.
    if (_selectedLocale == null || _selectedLocale != currentLocale) {
      _selectedLocale = currentLocale;
    }

    // 4) Build a list of DropdownMenuItem widgets from `_availableLocales`.
    final dropdownItems = _availableLocales.map((tuple) {
      final locale = tuple.$1;
      final name = tuple.$2;
      return DropdownMenuItem<Locale>(
        value: locale,
        child: Text(name),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.options), // localized "Options" text if you have one
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // LANGUAGE DROPDOWN
            Row(
              children: [
                Text(
                  loc.language, 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<Locale>(
                    isExpanded: true,
                    value: _selectedLocale,
                    items: dropdownItems,
                    onChanged: (newLocale) {
                      if (newLocale != null) {
                        setState(() {
                          _selectedLocale = newLocale;
                        });
                        // Update the Riverpod locale provider:
                        ref.read(localeProvider.notifier).state = newLocale;
                        logger.i('User changed locale to $newLocale');
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // VOLUME SLIDER (placeholder example)
            Row(
              children: [
                Text(
                  loc.volume, // Suppose you have a "volume" string in localizations
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: 0.5, // Hard-coded for demonstration
                    onChanged: (newValue) {
                      // Future: setState or store volume in some settings provider
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // If you have more settings, add them below...
          ],
        ),
      ),
    );
  }
}