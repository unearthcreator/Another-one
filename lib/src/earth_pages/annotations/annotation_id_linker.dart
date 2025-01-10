import 'package:flutter/foundation.dart';

/// A utility class to link Mapbox annotation IDs to Hive annotation IDs.
/// This allows you to find the corresponding Hive annotation based on the 
/// Mapbox annotation currently displayed on the map.
///
/// Note:
/// - `mapAnnotationId` is the ID returned by Mapbox when we create annotations.
/// - `hiveId` is the unique ID of the annotation stored in Hive.
/// 
/// You can register a new link whenever you create a new annotation or 
/// when you load annotations from Hive and place them on the map.
/// Then, if you need to look up which Hive annotation an on-screen annotation corresponds to,
/// you can use `getHiveIdForAnnotation`.

class AnnotationIdLinker {
  /// Internal mapping from mapAnnotationId (String) to hiveId (String).
  final Map<String, String> _idMap = {};

  /// Registers a link between a Mapbox annotation ID and a Hive annotation ID.
  void registerAnnotationId(String mapAnnotationId, String hiveId) {
    _idMap[mapAnnotationId] = hiveId;
      print('AnnotationIdLinker: Linked $mapAnnotationId to Hive ID: $hiveId');
  }

  /// Retrieves the Hive IDs for a list of Mapbox annotation IDs.
List<String> getHiveIdsForMultipleAnnotations(List<String> mapboxIds) {
  final List<String> result = [];
  for (final mapboxId in mapboxIds) {
    final hiveId = _idMap[mapboxId];
    if (hiveId != null) {
      result.add(hiveId);
    } else {
      // Optionally log or handle the missing case
    }
  }
  return result;
}

  /// Retrieves the Hive ID for the given mapAnnotationId, if any.
  String? getHiveIdForAnnotation(String mapAnnotationId) {
    return _idMap[mapAnnotationId];
    
  }

  /// Removes the link for a given mapAnnotationId, if it exists.
  void removeLink(String mapAnnotationId) {
    _idMap.remove(mapAnnotationId);
  }

  /// Clears all mappings.
  void clearAll() {
    _idMap.clear();
  }
}