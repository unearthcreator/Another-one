import 'package:flutter/material.dart';
import 'package:map_mvp_project/services/error_handler.dart'; // For logging

/// A reusable button widget that displays an icon along with a label.
/// Used in main_menu.dart for navigation or other menu-related actions.
class MenuButton extends StatelessWidget {
  /// The icon to display on the left side of the button.
  final IconData icon;

  /// The text label to display inside the button.
  final String label;

  /// Callback that gets triggered when the button is pressed.
  final VoidCallback onPressed;

  const MenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // 1) Log a message each time this widget builds (might be frequent).
    logger.i('Rendering MenuButton: $label');

    // 2) Return a fixed-size container that holds our ElevatedButton with icon + label.
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton.icon(
        // 3) Use `ElevatedButton.styleFrom` for consistent styling.
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: Colors.blueGrey[700], // Background color of button
          foregroundColor: Colors.white,         // General text/icon color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Rounded corners
          ),
        ),
        // 4) Force the icon color to white to ensure consistency in older or custom themes.
        icon: Icon(
          icon,
          size: 24,
          color: Colors.white,
        ),
        // 5) The text label, styled in bold with a font size of 18.
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        // 6) The action that should occur on button press.
        onPressed: onPressed,
      ),
    );
  }
}