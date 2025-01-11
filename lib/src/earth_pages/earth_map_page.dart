import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/repositories/local_annotations_repository.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_pages/annotations/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_pages/gestures/map_gesture_handler.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:map_mvp_project/services/geocoding_service.dart';
import 'package:uuid/uuid.dart'; // for unique IDs
import 'package:map_mvp_project/models/annotation.dart'; // for Annotation model
import 'package:map_mvp_project/src/earth_pages/dialogs/annotation_form_dialog.dart';
// Import your timeline view
import 'package:map_mvp_project/src/earth_pages/timeline/timeline.dart';
import 'package:map_mvp_project/src/earth_pages/annotations/annotation_id_linker.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_queries.dart';
import 'package:map_mvp_project/models/world_config.dart';

class EarthMapPage extends StatefulWidget {
  final WorldConfig worldConfig; // Add this parameter

  const EarthMapPage({Key? key, required this.worldConfig}) : super(key: key);

  @override
  EarthMapPageState createState() => EarthMapPageState();
}

class EarthMapPageState extends State<EarthMapPage> {
  late MapboxMap _mapboxMap;
  late MapAnnotationsManager _annotationsManager;
  late MapGestureHandler _gestureHandler;
  late LocalAnnotationsRepository _localRepo;

  bool _isMapReady = false;
  bool _isError = false;
  String _errorMessage = '';

  final TextEditingController _addressController = TextEditingController();
  bool _showSearchBar = false;

  // For address suggestions
  List<String> _suggestions = [];

  // Store Hive UUIDs for timeline display
  List<String> _hiveUuidsForTimeline = [];

  Timer? _debounceTimer;

  final uuid = Uuid(); // for unique IDs

  bool _showAnnotationMenu = false;
  PointAnnotation? _annotationMenuAnnotation;
  Offset _annotationMenuOffset = Offset.zero;

  bool _isDragging = false;
  String get _annotationButtonText => _isDragging ? 'Lock' : 'Move';

  bool _isConnectMode = false;
  bool _showTimelineCanvas = false;

  @override
  void initState() {
    super.initState();
    logger.i('Initializing EarthMapPage');
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onAddressChanged() {
    // Debounce the user's typing
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final query = _addressController.text.trim();
      if (query.isNotEmpty) {
        final suggestions = await GeocodingService.fetchAddressSuggestions(query);
        setState(() {
          _suggestions = suggestions;
        });
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    });
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    try {
      logger.i('Starting map initialization');
      _mapboxMap = mapboxMap;

      // Create the underlying Mapbox annotation manager:
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

      _gestureHandler = MapGestureHandler(
        mapboxMap: mapboxMap,
        annotationsManager: _annotationsManager,
        context: context,
        localAnnotationsRepository: _localRepo,
        annotationIdLinker: annotationIdLinker, // <-- Pass it here
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

      if (mounted) {
        setState(() => _isMapReady = true);

        // Now that the map is ready, load any previously saved Hive annotations
        await _annotationsManager.loadAnnotationsFromHive();
      }
    } catch (e, stackTrace) {
      logger.e('Error during map initialization', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = 'Failed to initialize map: ${e.toString()}';
        });
      }
    }
  }

  // ---------------------- Annotation UI & Callbacks ----------------------

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

  Future<void> _editAnnotation() async {
    if (_annotationMenuAnnotation == null) return;
    final hiveId = _gestureHandler.getHiveIdForAnnotation(_annotationMenuAnnotation!);
    if (hiveId == null) {
      logger.w('No hive ID found for this annotation.');
      return;
    }

    final allHiveAnnotations = await _localRepo.getAnnotations();
    final ann = allHiveAnnotations.firstWhere((a) => a.id == hiveId, orElse: () => Annotation(id: 'notFound'));

    if (ann.id == 'notFound') {
      logger.w('Annotation not found in Hive.');
      return;
    }

    final title = ann.title ?? '';
    final startDate = ann.startDate ?? '';
    final note = ann.note ?? '';
    final iconName = ann.iconName ?? 'cross';
    IconData chosenIcon = Icons.star;

    final result = await showAnnotationFormDialog(
      context,
      title: title,
      chosenIcon: chosenIcon,
      date: startDate,
      note: note,
    );

    if (result != null) {
      final updatedNote = result['note'] ?? '';
      final updatedImagePath = result['imagePath'];
      final updatedFilePath = result['filePath'];
      logger.i('User edited note: $updatedNote, imagePath: $updatedImagePath, filePath: $updatedFilePath');

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

      await _localRepo.updateAnnotation(updatedAnnotation);
      logger.i('Annotation updated in Hive with id: ${ann.id}');

      // Remove from map visually
      await _annotationsManager.removeAnnotation(_annotationMenuAnnotation!);

      // Attempt to load the icon
      final iconBytes = await rootBundle.load('assets/icons/${updatedAnnotation.iconName ?? 'cross'}.png');
      final imageData = iconBytes.buffer.asUint8List();

      // Add updated annotation visually
      final mapAnnotation = await _annotationsManager.addAnnotation(
        Point(coordinates: Position(updatedAnnotation.longitude ?? 0.0, updatedAnnotation.latitude ?? 0.0)),
        image: imageData,
        title: updatedAnnotation.title ?? '',
        date: updatedAnnotation.startDate ?? '',
      );

      // Re-link
      _gestureHandler.registerAnnotationId(mapAnnotation.id, updatedAnnotation.id);

      setState(() {
        _annotationMenuAnnotation = mapAnnotation;
      });

      logger.i('Annotation visually updated on map.');
    } else {
      logger.i('User cancelled edit.');
    }
  }

  // ---------------------- UI Builders ----------------------

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

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

  Widget _buildBackButton() {
    return Positioned(
      top: 40,
      left: 10,
      child: BackButton(
        onPressed: () {
          logger.i('Navigating back from EarthMapPage');
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildSearchToggleButton() {
    return Positioned(
      top: 40,
      left: 10,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(8),
        ),
        onPressed: () {
          setState(() {
            _showSearchBar = !_showSearchBar;
            if (!_showSearchBar) {
              _suggestions.clear();
            }
          });
        },
        child: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildTimelineButton() {
    return Positioned(
      top: 90,
      left: 10,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(8),
        ),
        onPressed: () async {
          logger.i('Timeline button clicked');

          // 1) Query visible Mapbox annotation IDs
          final annotationIds = await queryVisibleFeatures(
            context: context,
            isMapReady: _isMapReady,
            mapboxMap: _mapboxMap,
            annotationsManager: _annotationsManager,
          );
          logger.i('Received annotationIds from map_queries: $annotationIds');
          logger.i('Number of IDs returned: ${annotationIds.length}');

          // 2) Convert those mapbox IDs -> Hive IDs
          final hiveIds = _annotationsManager.annotationIdLinker
              .getHiveIdsForMultipleAnnotations(annotationIds);

          logger.i('Got these Hive IDs from annotationIdLinker: $hiveIds');
          logger.i('Number of Hive IDs: ${hiveIds.length}');

          // 3) Toggle the timeline + store IDs so the timeline can show them
          setState(() {
            _showTimelineCanvas = !_showTimelineCanvas;
            _hiveUuidsForTimeline = hiveIds;
          });
        },
        child: const Icon(Icons.timeline),
      ),
    );
  }

  Widget _buildClearAnnotationsButton() {
    return Positioned(
      top: 40,
      right: 10,
      child: ElevatedButton(
        onPressed: () async {
          logger.i('Clear button pressed - clearing all annotations from Hive and from the map.');

          // 1) Remove all from Hive
          final box = await Hive.openBox<Map>('annotationsBox');
          await box.clear();

          logger.i('After clearing, the "annotationsBox" has ${box.length} items.');
          await box.close();
          logger.i('Annotations cleared from Hive.');

          // 2) Remove all from the map visually
          await _annotationsManager.removeAllAnnotations();
          logger.i('All annotations removed from the map.');

          logger.i('Done clearing. You can now add new annotations.');
        },
        child: const Text('Clear Annotations'),
      ),
    );
  }

  Widget _buildClearImagesButton() {
    return Positioned(
      top: 90,
      right: 10,
      child: ElevatedButton(
        onPressed: () async {
          logger.i('Clear images button pressed - clearing images folder files.');
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory(p.join(appDir.path, 'images'));

          if (await imagesDir.exists()) {
            final files = imagesDir.listSync();
            for (var file in files) {
              if (file is File) {
                await file.delete();
              }
            }
            logger.i('All image files cleared from ${imagesDir.path}');
          } else {
            logger.i('Images directory does not exist, nothing to clear.');
          }
        },
        child: const Text('Clear Images'),
      ),
    );
  }

  Widget _buildDeleteImagesFolderButton() {
    return Positioned(
      top: 140,
      right: 10,
      child: ElevatedButton(
        onPressed: () async {
          logger.i('Delete images folder button pressed - deleting entire images folder.');
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory(p.join(appDir.path, 'images'));

          if (await imagesDir.exists()) {
            await imagesDir.delete(recursive: true);
            logger.i('Images directory deleted.');
          } else {
            logger.i('Images directory does not exist, nothing to delete.');
          }
        },
        child: const Text('Delete Images Folder'),
      ),
    );
  }

  Widget _buildAddressSearchWidget() {
    if (!_showSearchBar) return const SizedBox.shrink();

    return Positioned(
      top: 140,
      left: 10,
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      hintText: 'Enter address',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final address = _addressController.text.trim();
                    if (address.isEmpty) return;

                    final coords = await GeocodingService.fetchCoordinatesFromAddress(address);
                    if (coords != null) {
                      logger.i('Coordinates received: $coords');
                      final lat = coords['lat']!;
                      final lng = coords['lng']!;

                      final geometry = Point(coordinates: Position(lng, lat));
                      final bytes = await rootBundle.load('assets/icons/cross.png');
                      final imageData = bytes.buffer.asUint8List();

                      final annotationId = uuid.v4();
                      final annotation = Annotation(
                        id: annotationId,
                        title: address.isNotEmpty ? address : null,
                        iconName: "cross",
                        startDate: null,
                        note: null,
                        latitude: lat,
                        longitude: lng,
                        imagePath: null,
                        endDate: null,
                      );
                      await _localRepo.addAnnotation(annotation);
                      logger.i('Searched annotation saved to Hive with id: $annotationId');

                      final mapAnnotation = await _annotationsManager.addAnnotation(
                        geometry,
                        image: imageData,
                        title: annotation.title ?? '',
                        date: annotation.startDate ?? '',
                      );
                      logger.i('Annotation placed at searched location.');

                      // Link
                      _gestureHandler.registerAnnotationId(mapAnnotation.id, annotationId);

                      // Move camera
                      _mapboxMap.setCamera(
                        CameraOptions(
                          center: geometry,
                          zoom: 14.0,
                        ),
                      );
                    } else {
                      logger.w('No coordinates found for the given address.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No coordinates found for the given address.')),
                      );
                    }
                  },
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              width: 250,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _suggestions.map((s) {
                  return InkWell(
                    onTap: () {
                      _addressController.text = s;
                      _suggestions.clear();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(s),
                    ),
                  );
                }).toList(),
              ),
            )
        ],
      ),
    );
  }

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

  Widget _buildAnnotationMenu() {
    if (!_showAnnotationMenu || _annotationMenuAnnotation == null) return const SizedBox.shrink();

    return Positioned(
      left: _annotationMenuOffset.dx,
      top: _annotationMenuOffset.dy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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

  Widget _buildTimelineCanvas() {
    if (!_showTimelineCanvas) return const SizedBox.shrink();

    return Positioned(
      left: 76,
      right: 76,
      top: 19,
      bottom: 19,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          // We pass the Hive IDs to the TimelineView
          child: TimelineView(hiveUuids: _hiveUuidsForTimeline),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isError
          ? _buildErrorWidget()
          : Stack(
              children: [
                _buildMapWidget(),
                if (_isMapReady) _buildBackButton(),
                if (_isMapReady) _buildSearchToggleButton(),
                if (_isMapReady) _buildTimelineButton(),
                if (_isMapReady) _buildClearAnnotationsButton(),
                if (_isMapReady) _buildClearImagesButton(),
                if (_isMapReady) _buildDeleteImagesFolderButton(),
                if (_isMapReady) _buildAddressSearchWidget(),
                if (_isMapReady) _buildAnnotationMenu(),
                if (_isMapReady) _buildConnectModeBanner(),
                if (_isMapReady) _buildTimelineCanvas(),
              ],
            ),
    );
  }
}