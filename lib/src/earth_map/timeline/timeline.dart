import 'package:flutter/material.dart';
import 'package:map_mvp_project/models/annotation.dart';
import 'package:map_mvp_project/src/earth_pages/timeline/painter/timeline_painter.dart';
import 'package:map_mvp_project/src/earth_pages/timeline/utils/timeline_annotations.dart';

class TimelineView extends StatelessWidget {
  /// Make this nullable or provide a default empty list.
  final List<String>? hiveUuids;

  const TimelineView({
    Key? key,
    this.hiveUuids, // not required now
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely handle the case where hiveUuids is null or empty
    final localUuids = hiveUuids ?? [];
    if (localUuids.isEmpty) {
      // 1) If no UUIDs, just paint an empty timeline canvas (skips fetching).
      return CustomPaint(
        painter: TimelinePainter(annotationList: const []),
      );
    }

    // 2) Otherwise, fetch the annotations via a FutureBuilder.
    return FutureBuilder<List<Annotation>>(
      future: TimelineAnnotations.fetchAnnotationsByUuids(localUuids),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Still loading, show a spinner or placeholder
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          // No matching annotations or fetch returned empty
          return CustomPaint(
            painter: TimelinePainter(annotationList: const []),
          );
        }

        final annotationList = snapshot.data!;
        // Pass them into your painter
        return CustomPaint(
          painter: TimelinePainter(annotationList: annotationList),
        );
      },
    );
  }
}