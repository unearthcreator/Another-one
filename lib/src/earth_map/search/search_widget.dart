import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/geocoding_service.dart';
import 'package:uuid/uuid.dart';

class SearchWidget extends StatefulWidget {
  final Function(Point geometry, Map<String, dynamic> annotation) onAnnotationCreated;
  final Function(CameraOptions) onMoveCamera;

  const SearchWidget({
    Key? key,
    required this.onAnnotationCreated,
    required this.onMoveCamera,
  }) : super(key: key);

  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _addressController = TextEditingController();
  final Uuid uuid = Uuid();
  bool _showSearchBar = false;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _suggestions.clear();
      }
    });
  }

  Future<void> _searchForAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    final coords = await GeocodingService.fetchCoordinatesFromAddress(address);
    if (coords != null) {
      final lat = coords['lat']!;
      final lng = coords['lng']!;
      final geometry = Point(coordinates: Position(lng, lat));

      final annotationId = uuid.v4();
      final annotation = {
        'id': annotationId,
        'title': address.isNotEmpty ? address : null,
        'iconName': "cross",
        'startDate': null,
        'note': null,
        'latitude': lat,
        'longitude': lng,
        'imagePath': null,
        'endDate': null,
      };

      // Trigger annotation creation callback
      widget.onAnnotationCreated(geometry, annotation);

      // Trigger camera movement callback
      widget.onMoveCamera(
        CameraOptions(
          center: geometry,
          zoom: 14.0,
        ),
      );

      _addressController.clear();
      _suggestions.clear();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No coordinates found for the given address.')),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isNotEmpty) {
      // Example of fetching suggestions, replace with actual API logic
      final suggestions = await GeocodingService.fetchAddressSuggestions(query);
      setState(() {
        _suggestions = suggestions;
      });
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Search Toggle Button
        Positioned(
          top: 40,
          left: 10,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(8),
            ),
            onPressed: _toggleSearchBar,
            child: const Icon(Icons.search),
          ),
        ),
        // Search Bar and Suggestions
        if (_showSearchBar)
          Positioned(
            top: 140,
            left: 10,
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input and Button
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
                          onChanged: _fetchSuggestions,
                          decoration: const InputDecoration(
                            hintText: 'Enter address',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _searchForAddress,
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                ),
                // Suggestions
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
                  ),
              ],
            ),
          ),
      ],
    );
  }
}