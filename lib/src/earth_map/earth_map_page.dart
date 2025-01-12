import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// ---------------------- External & Project Imports ----------------------
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_map/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_map/gestures/map_gesture_handler.dart';
import 'package:map_mvp_project/src/earth_map/utils/map_config.dart';
import 'package:uuid/uuid.dart'; // for unique IDs
import 'package:map_mvp_project/models/annotation.dart'; // for Annotation model
import 'package:map_mvp_project/src/earth_map/dialogs/annotation_form_dialog.dart';
import 'package:map_mvp_project/src/earth_map/timeline/timeline.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_id_linker.dart';
import 'package:map_mvp_project/src/earth_map/utils/map_queries.dart';
import 'package:map_mvp_project/models/world_config.dart';
import 'package:map_mvp_project/src/earth_map/search/search_widget.dart';
import 'package:map_mvp_project/src/earth_map/misc/test_utils.dart';
import 'package:map_mvp_project/src/earth_map/annotations/annotation_menu.dart';

/// The main EarthMapPage, which sets up the map, annotations, and various UI widgets.
class EarthMapPage extends StatefulWidget {
  final WorldConfig worldConfig;

  const EarthMapPage({Key? key, required this.worldConfig}) : super(key: key);

  @override
  EarthMapPageState createState() => EarthMapPageState();
}

class EarthMapPageState extends State<EarthMapPage> {
  // ---------------------- Map-Related Variables ----------------------
  late MapboxMap _mapboxMap;
  late MapAnnotationsManager _annotationsManager;
  late MapGestureHandler _gestureHandler;
  late LocalAnnotationsRepository _localRepo;
  bool _isMapReady = false;

  // ---------------------- Timeline / Canvas UI ----------------------
  List<String> _hiveUuidsForTimeline = [];
  bool _showTimelineCanvas = false;

  // ---------------------- Annotation Menu Variables ----------------------
  bool _showAnnotationMenu = false;
  PointAnnotation? _annotationMenuAnnotation;
  Offset _annotationMenuOffset = Offset.zero;

  // ---------------------- Dragging & Connect Mode ----------------------
  bool _isDragging = false;
  bool _isConnectMode = false;
  String get _annotationButtonText => _isDragging ? 'Lock' : 'Move';

  // ---------------------- UUID Generator ----------------------
  final uuid = Uuid();

  // ---------------------------------------------------------------------
  //                   LIFECYCLE: initState & dispose
  // ---------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    logger.i('Initializing EarthMapPage');
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------
  //                       MAP CREATION / INIT
  // ---------------------------------------------------------------------
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    try {
      logger.i('Starting map initialization');
      _mapboxMap = mapboxMap;

      // Create the underlying Mapbox annotation manager
      final annotationManager = await mapboxMap.annotations
          .createPointAnnotationManager()
          .onError((error, stackTrace) {
        logger.e('Failed to create annotation manager', error: error, stackTrace: stackTrace);
        throw Exception('Failed to initialize map annotations');
      });

      // Create a single LocalAnnotationsRepository
      _localRepo = LocalAnnotationsRepository();

      // Create a *single* shared AnnotationIdLinker instance
      final annotationIdLinker = AnnotationIdLinker();

      // Create our MapAnnotationsManager, passing the single linker
      _annotationsManager = MapAnnotationsManager(
        annotationManager,
        annotationIdLinker: annotationIdLinker,
        localAnnotationsRepository: _localRepo,
      );

      // Set up the gesture handler
      _gestureHandler = MapGestureHandler(
        mapboxMap: mapboxMap,
        annotationsManager: _annotationsManager,
        context: context,
        localAnnotationsRepository: _localRepo,
        annotationIdLinker: annotationIdLinker,
        onAnnotationLongPress: _handleAnnotationLongPress,
        onAnnotationDragUpdate: _handleAnnotationDragUpdate,
        onDragEnd: _handleDragEnd,
        onAnnotationRemoved: _handleAnnotationRemoved,
        onConnectModeDisabled: () {
          setState(() {
            _isConnectMode = false;
          });
        },
      );

      logger.i('Map initialization completed successfully');

      // Once the map is ready, load saved Hive annotations
      if (mounted) {
        setState(() => _isMapReady = true);
        await _annotationsManager.loadAnnotationsFromHive();
      }
    } catch (e, stackTrace) {
      logger.e('Error during map initialization', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {});
      }
    }
  }

  // ---------------------------------------------------------------------
  //                 ANNOTATION UI & CALLBACKS
  // ---------------------------------------------------------------------
  void _handleAnnotationLongPress(PointAnnotation annotation, Point annotationPosition) async {
    final screenPos = await _mapboxMap.pixelForCoordinate(annotationPosition);
    setState(() {
      _annotationMenuAnnotation = annotation;
      _showAnnotationMenu = true;
      _annotationMenuOffset = Offset(screenPos.x + 30, screenPos.y);
    });
  }

  void _handleAnnotationDragUpdate(PointAnnotation annotation) async {
    final screenPos = await _mapboxMap.pixelForCoordinate(annotation.geometry);
    setState(() {
      _annotationMenuAnnotation = annotation;
      _annotationMenuOffset = Offset(screenPos.x + 30, screenPos.y);
    });
  }

  void _handleDragEnd() {
    // Drag ended - no special action here
  }

  void _handleAnnotationRemoved() {
    setState(() {
      _showAnnotationMenu = false;
      _annotationMenuAnnotation = null;
      _isDragging = false;
    });
  }

  // ---------------------------------------------------------------------
  //                          LONG PRESS HANDLERS
  // ---------------------------------------------------------------------
  void _handleLongPress(LongPressStartDetails details) {
    try {
      logger.i('Long press started at: ${details.localPosition}');
      final screenPoint = ScreenCoordinate(
        x: details.localPosition.dx,
        y: details.localPosition.dy,
      );
      _gestureHandler.handleLongPress(screenPoint);
    } catch (e, stackTrace) {
      logger.e('Error handling long press', error: e, stackTrace: stackTrace);
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    try {
      if (_isDragging) {
        final screenPoint = ScreenCoordinate(
          x: details.localPosition.dx,
          y: details.localPosition.dy,
        );
        _gestureHandler.handleDrag(screenPoint);
      }
    } catch (e, stackTrace) {
      logger.e('Error handling drag update', error: e, stackTrace: stackTrace);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    try {
      logger.i('Long press ended');
      if (_isDragging) {
        _gestureHandler.endDrag();
      }
    } catch (e, stackTrace) {
      logger.e('Error handling long press end', error: e, stackTrace: stackTrace);
    }
  }

  // ---------------------------------------------------------------------
  //                           EDITING ANNOTATIONS
  // ---------------------------------------------------------------------
  Future<void> _editAnnotation() async {
    if (_annotationMenuAnnotation == null) return;
    final hiveId = _gestureHandler.getHiveIdForAnnotation(_annotationMenuAnnotation!);
    if (hiveId == null) {
      logger.w('No hive ID found for this annotation.');
      return;
    }

    // Retrieve annotation from Hive
    final allHiveAnnotations = await _localRepo.getAnnotations();
    final ann = allHiveAnnotations.firstWhere((a) => a.id == hiveId, orElse: () => Annotation(id: 'notFound'));

    if (ann.id == 'notFound') {
      logger.w('Annotation not found in Hive.');
      return;
    }

    // Prepare existing fields
    final title = ann.title ?? '';
    final startDate = ann.startDate ?? '';
    final note = ann.note ?? '';
    final iconName = ann.iconName ?? 'cross';
    IconData chosenIcon = Icons.star;

    // Show the form dialog
    final result = await showAnnotationFormDialog(
      context,
      title: title,
      chosenIcon: chosenIcon,
      date: startDate,
      note: note,
    );

    // If user saved
    if (result != null) {
      final updatedNote = result['note'] ?? '';
      final updatedImagePath = result['imagePath'];
      final updatedFilePath = result['filePath'];
      logger.i('User edited note: $updatedNote, imagePath: $updatedImagePath, filePath: $updatedFilePath');

      // Build updated annotation
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

      // Update in Hive
      await _localRepo.updateAnnotation(updatedAnnotation);
      logger.i('Annotation updated in Hive with id: ${ann.id}');

      // Remove old annotation visually
      await _annotationsManager.removeAnnotation(_annotationMenuAnnotation!);

      // Load new icon
      final iconBytes = await rootBundle.load('assets/icons/${updatedAnnotation.iconName ?? 'cross'}.png');
      final imageData = iconBytes.buffer.asUint8List();

      // Add updated annotation visually
      final mapAnnotation = await _annotationsManager.addAnnotation(
        Point(coordinates: Position(updatedAnnotation.longitude ?? 0.0, updatedAnnotation.latitude ?? 0.0)),
        image: imageData,
        title: updatedAnnotation.title ?? '',
        date: updatedAnnotation.startDate ?? '',
      );

      // Re-link new annotation
      _gestureHandler.registerAnnotationId(mapAnnotation.id, updatedAnnotation.id);

      // Update the local reference
      setState(() {
        _annotationMenuAnnotation = mapAnnotation;
      });

      logger.i('Annotation visually updated on map.');
    } else {
      logger.i('User cancelled edit.');
    }
  }

  // ---------------------------------------------------------------------
  //                            UI BUILDERS
  // ---------------------------------------------------------------------
  /// The Map widget, plus gesture detection
  /// 
  Widget _buildMapWidget() {
    return GestureDetector(
      onLongPressStart: _handleLongPress,
      onLongPressMoveUpdate: _handleLongPressMoveUpdate,
      onLongPressEnd: _handleLongPressEnd,
      onLongPressCancel: () {
        logger.i('Long press cancelled');
        if (_isDragging) {
          _gestureHandler.endDrag();
        }
      },
      child: MapWidget(
        cameraOptions: MapConfig.defaultCameraOptions,
        styleUri: MapConfig.styleUriEarth,
        onMapCreated: _onMapCreated,
      ),
    );
  }

  /// Button to toggle the Timeline

  /// Banner to show while in Connect mode
  Widget _buildConnectModeBanner() {
    if (!_isConnectMode) return const SizedBox.shrink();

    return Positioned(
      top: 50,
      left: (MediaQuery.of(context).size.width - 300) / 2,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const Text(
              'Click another annotation to connect, or cancel.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isConnectMode = false;
                });
                _gestureHandler.disableConnectMode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  /// The floating annotation menu (long-press on annotation)
  Widget _buildAnnotationMenu() {
    if (!_showAnnotationMenu || _annotationMenuAnnotation == null) return const SizedBox.shrink();

    return Positioned(
      left: _annotationMenuOffset.dx,
      top: _annotationMenuOffset.dy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Move/Lock button
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (_isDragging) {
                  _gestureHandler.hideTrashCanAndStopDragging();
                  _isDragging = false;
                } else {
                  _gestureHandler.startDraggingSelectedAnnotation();
                  _isDragging = true;
                }
              });
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: Text(_annotationButtonText),
          ),
          const SizedBox(height: 8),

          // Edit button
          ElevatedButton(
            onPressed: () async {
              await _editAnnotation();
            },
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
              setState(() {
                _showAnnotationMenu = false;
                if (_isDragging) {
                  _gestureHandler.hideTrashCanAndStopDragging();
                  _isDragging = false;
                }
                _isConnectMode = true;
              });
              if (_annotationMenuAnnotation != null) {
                _gestureHandler.enableConnectMode(_annotationMenuAnnotation!);
              } else {
                logger.w('No annotation available when Connect pressed');
              }
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
            onPressed: () {
              setState(() {
                _showAnnotationMenu = false;
                _annotationMenuAnnotation = null;
                if (_isDragging) {
                  _gestureHandler.hideTrashCanAndStopDragging();
                  _isDragging = false;
                }
              });
            },
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


  // ---------------------------------------------------------------------
  //                           BUILD METHOD
  // ---------------------------------------------------------------------
  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        // The main map widget
        _buildMapWidget(),

        // Only show the rest if the map is ready
        if (_isMapReady) ...[
          // -----------------------------------
          //   TIMELINE BUTTON (from timeline.dart)
          // -----------------------------------
          buildTimelineButton(
            isMapReady: _isMapReady,
            context: context,
            mapboxMap: _mapboxMap,
            annotationsManager: _annotationsManager,
            // This toggles the boolean that shows/hides the timeline
            onToggleTimeline: () {
              setState(() {
                _showTimelineCanvas = !_showTimelineCanvas;
              });
            },
            // This receives the Hive IDs after querying visible features
            onHiveIdsFetched: (List<String> hiveIds) {
              setState(() {
                _hiveUuidsForTimeline = hiveIds;
              });
            },
          ),

          // -----------------------------------
          //   DEBUG UTILITY BUTTONS
          // -----------------------------------
          buildClearAnnotationsButton(annotationsManager: _annotationsManager),
          buildClearImagesButton(),
          buildDeleteImagesFolderButton(),

          // -----------------------------------
          //   SEARCH WIDGET
          // -----------------------------------
          EarthMapSearchWidget(
            mapboxMap: _mapboxMap,
            annotationsManager: _annotationsManager,
            gestureHandler: _gestureHandler,
            localRepo: _localRepo,
            uuid: uuid,
          ),

          // -----------------------------------
          //   ANNOTATION MENU & CONNECT BANNER
          // -----------------------------------
          _buildAnnotationMenu(),
          _buildConnectModeBanner(),

          // -----------------------------------
          //   TIMELINE CANVAS (from timeline.dart)
          // -----------------------------------
          buildTimelineCanvas(
            showTimelineCanvas: _showTimelineCanvas,
            hiveUuids: _hiveUuidsForTimeline,
          ),
        ],
      ],
    ),
  );
}
}