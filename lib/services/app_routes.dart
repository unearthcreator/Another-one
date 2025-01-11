import 'package:flutter/material.dart';
import 'package:map_mvp_project/src/starting_pages/main_menu/main_menu.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/world_selector.dart';
import 'package:map_mvp_project/src/starting_pages/main_menu/options/options.dart';
import 'package:map_mvp_project/src/starting_pages/world_selector/earth_creator/earth_creator.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const MainMenuPage(),
  '/world_selector': (context) => const WorldSelectorPage(),
  '/options': (context) => const OptionsPage(),
  '/earth_creator': (context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is int) {
      return EarthCreatorPage(carouselIndex: args);
    } else {
      return const EarthCreatorPage(carouselIndex: 0);
    }
  },
};