import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/services/error_handler.dart' show logger;
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_form_dialog.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/gestures/map_gesture_handler.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';

/// A single function that handles both the UI (Positioned menu) and the logic
/// (edit annotation, toggling dragging, connect, cancel) for your annotation menu.
/// 
/// You pass in:
/// 1) The current states (showAnnotationMenu, annotation, offsets, etc.)
/// 2) The references needed to manipulate data (gestureHandler, localRepo, etc.)
/// 3) An [onStateChange] callback so we can mimic `setState` calls in EarthMapPage.
Widget buildAnnotationMenuWithLogic({
  required bool showAnnotationMenu,
  required PointAnnotation? annotation,
  required Offset annotationMenuOffset,
  required bool isDragging,
  required bool isConnectMode,
  required String annotationButtonText,

  // For performing logic
  required MapGestureHandler gestureHandler,
  required LocalAnnotationsRepository localRepo,
  required MapAnnotationsManager annotationsManager,

  // We need BuildContext for showAnnotationFormDialog
  required BuildContext context,

  // Because we can't call `setState` from here, we mimic it:
  required void Function(void Function()) onStateChange,
}) {
  // If not showing or no annotation to act on, render nothing
  if (!showAnnotationMenu || annotation == null) {
    return const SizedBox.shrink();
  }

  /// Toggle dragging / move-lock logic
  void toggleDragging() {
    onStateChange(() {
      if (isDragging) {
        gestureHandler.hideTrashCanAndStopDragging();
      } else {
        gestureHandler.startDraggingSelectedAnnotation();
      }
    });
  }

  /// The entire "edit annotation" logic, now embedded here
  Future<void> editAnnotation() async {
    // If annotation is somehow null, just return
    if (annotation == null) return;

    // 1) Find the Hive ID for this annotation
    final hiveId = gestureHandler.getHiveIdForAnnotation(annotation);
    if (hiveId == null) {
      logger.w('No hive ID found for this annotation.');
      return;
    }

    // 2) Retrieve annotation from Hive
    final allHiveAnnotations = await localRepo.getAnnotations();
    final ann = allHiveAnnotations.firstWhere(
      (a) => a.id == hiveId,
      orElse: () => Annotation(id: 'notFound'),
    );

    if (ann.id == 'notFound') {
      logger.w('Annotation not found in Hive.');
      return;
    }

    // 3) Prepare existing fields for the form
    final title = ann.title ?? '';
    final startDate = ann.startDate ?? '';
    final note = ann.note ?? '';
    final iconName = ann.iconName ?? 'cross';
    IconData chosenIcon = Icons.star;

    // 4) Show the annotation form dialog
    final result = await showAnnotationFormDialog(
      context,
      title: title,
      chosenIcon: chosenIcon,
      date: startDate,
      note: note,
    );

    // 5) If user cancelled or no result, just log & return
    if (result == null) {
      logger.i('User cancelled edit.');
      return;
    }

    // 6) Extract the updated data from the form
    final updatedNote = result['note'] ?? '';
    final updatedImagePath = result['imagePath'];
    final updatedFilePath = result['filePath'];
    logger.i('User edited note: $updatedNote, imagePath: $updatedImagePath, filePath: $updatedFilePath');

    // 7) Build the updated annotation object
    final updatedAnnotation = Annotation(
      id: ann.id,
      title: title.isNotEmpty ? title : null,
      iconName: iconName.isNotEmpty ? iconName : null,
      startDate: startDate.isNotEmpty ? startDate : null,
      endDate: ann.endDate,
      note: updatedNote.isNotEmpty ? updatedNote : null,
      latitude: ann.latitude ?? 0.0,
      longitude: ann.longitude ?? 0.0,
      imagePath: (updatedImagePath != null && updatedImagePath.isNotEmpty)
          ? updatedImagePath
          : ann.imagePath,
    );

    // 8) Update in Hive
    await localRepo.updateAnnotation(updatedAnnotation);
    logger.i('Annotation updated in Hive with id: ${ann.id}');

    // 9) Remove the old annotation visually
    await annotationsManager.removeAnnotation(annotation);

    // 10) Load new icon
    final iconBytes = await rootBundle.load('assets/icons/${updatedAnnotation.iconName ?? 'cross'}.png');
    final imageData = iconBytes.buffer.asUint8List();

    // 11) Add updated annotation visually
    final mapAnnotation = await annotationsManager.addAnnotation(
      Point(coordinates: Position(
        updatedAnnotation.longitude ?? 0.0,
        updatedAnnotation.latitude ?? 0.0,
      )),
      image: imageData,
      title: updatedAnnotation.title ?? '',
      date: updatedAnnotation.startDate ?? '',
    );

    // 12) Re-link new annotation ID
    gestureHandler.registerAnnotationId(mapAnnotation.id, updatedAnnotation.id);

    // 13) Finally update EarthMapPage's reference to the new annotation
    onStateChange(() {
      // e.g. `_annotationMenuAnnotation = mapAnnotation;`
    });

    logger.i('Annotation visually updated on map.');
  }

  /// Connect mode logic
  void connectAnnotation() {
    logger.i('Connect button clicked');
    onStateChange(() {
      // e.g. `_showAnnotationMenu = false;`
      // if (isDragging) { gestureHandler.hideTrashCanAndStopDragging(); ... }
      // `_isConnectMode = true;`
    });
    gestureHandler.enableConnectMode(annotation);
  }

  /// Cancel the menu
  void cancelMenu() {
    onStateChange(() {
      // e.g. `_showAnnotationMenu = false;`
      // `_annotationMenuAnnotation = null;`
      // if (isDragging) { gestureHandler.hideTrashCanAndStopDragging(); }
    });
  }

  // Now build the UI with all these logic calls
  return Positioned(
    left: annotationMenuOffset.dx,
    top: annotationMenuOffset.dy,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Move/Lock
        ElevatedButton(
          onPressed: toggleDragging,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: Text(annotationButtonText),
        ),
        const SizedBox(height: 8),

        // Edit
        ElevatedButton(
          onPressed: () => editAnnotation(),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Edit'),
        ),
        const SizedBox(height: 8),

        // Connect
        ElevatedButton(
          onPressed: connectAnnotation,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('Connect'),
        ),
        const SizedBox(height: 8),

        // Cancel
        ElevatedButton(
          onPressed: cancelMenu,
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