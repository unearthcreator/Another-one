// annotation_menu.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart' show logger;

/// A helper function that returns the annotation menu (Positioned).
///
/// The calling widget (e.g., EarthMapPage) decides when to show/hide this menu
/// by passing [showAnnotationMenu], and provides the annotation details + callbacks.
Widget buildAnnotationMenu({
  required bool showAnnotationMenu,
  required bool isDragging,
  required bool isConnectMode,
  required String annotationButtonText,
  required PointAnnotation? annotation,
  required Offset annotationMenuOffset,

  /// Callback when user toggles "Move" or "Lock"
  required VoidCallback onToggleDragging,

  /// Callback when user taps "Edit"
  required Future<void> Function() onEditAnnotation,

  /// Callback when user taps "Connect"
  required VoidCallback onConnect,

  /// Callback when user taps "Cancel"
  required VoidCallback onCancel,
}) {
  // If the menu shouldn't show or there's no annotation, return an empty widget
  if (!showAnnotationMenu || annotation == null) {
    return const SizedBox.shrink();
  }

  return Positioned(
    left: annotationMenuOffset.dx,
    top: annotationMenuOffset.dy,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Move/Lock button
        ElevatedButton(
          onPressed: onToggleDragging,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: Text(annotationButtonText),
        ),
        const SizedBox(height: 8),

        // Edit button
        ElevatedButton(
          onPressed: onEditAnnotation,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Edit'),
        ),
        const SizedBox(height: 8),

        // Connect button
        ElevatedButton(
          onPressed: () {
            logger.i('Connect button clicked');
            onConnect();
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Connect'),
        ),
        const SizedBox(height: 8),

        // Cancel button
        ElevatedButton(
          onPressed: onCancel,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}