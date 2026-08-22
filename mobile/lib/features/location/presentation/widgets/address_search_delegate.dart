import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

const String _kGooglePlacesApiKey = String.fromEnvironment(
  'GOOGLE_PLACES_API_KEY',
  defaultValue: '',
);

/// Search delegate backed by Google Places Autocomplete API via [Dio],
/// debounced by 300ms. Restricted to India and biased around Pondicherry.
///
/// Replaces the abandoned `google_place` package which depends on
/// `http ^0.13.3` and conflicts with `flutter_map`'s `http ^1.2.1`.
/// Uses `dio` (already in the project) for direct REST calls.
class AddressSearchDelegate extends SearchDelegate<LatLng?> {
  AddressSearchDelegate({required this.onSelected});

  final ValueChanged<LatLng> onSelected;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://maps.googleapis.com/maps/api/place',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              query = '';
            },
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _SuggestionsList(
        query: query,
        dio: _dio,
        onSelected: (latLng) {
          onSelected(latLng);
          close(context, null);
        },
      );

  @override
  Widget buildSuggestions(BuildContext context) => _SuggestionsList(
        query: query,
        dio: _dio,
        onSelected: (latLng) {
          onSelected(latLng);
          close(context, null);
        },
      );
}

class _SuggestionsList extends StatefulWidget {
  const _SuggestionsList({
    required this.query,
    required this.dio,
    required this.onSelected,
  });

  final String query;
  final Dio dio;
  final ValueChanged<LatLng> onSelected;

  @override
  _SuggestionsListState createState() => _SuggestionsListState();
}

class _SuggestionsListState extends State<_SuggestionsList> {
  List<_PlacePrediction> _predictions = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search(widget.query);
  }

  @override
  void didUpdateWidget(covariant _SuggestionsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _search(widget.query);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String input) async {
    if (input.isEmpty || _kGooglePlacesApiKey.isEmpty) {
      setState(() {
        _predictions = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await widget.dio.get(
        '/autocomplete/json',
        queryParameters: {
          'input': input,
          'key': _kGooglePlacesApiKey,
          'components': 'country:in',
          'language': 'en',
          'location': '11.9356,79.8301',
          'radius': 50000,
        },
      );
      final predictions = response.data['predictions'] as List? ?? [];
      setState(() {
        _predictions = predictions
            .map((p) => _PlacePrediction(
                  placeId: p['place_id'] as String? ?? '',
                  description: p['description'] as String? ?? '',
                ))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _predictions = [];
        _loading = false;
      });
    }
  }

  Future<void> _onPredictionTapped(_PlacePrediction prediction) async {
    if (prediction.placeId.isEmpty || _kGooglePlacesApiKey.isEmpty) return;

    try {
      final response = await widget.dio.get(
        '/details/json',
        queryParameters: {
          'place_id': prediction.placeId,
          'key': _kGooglePlacesApiKey,
          'fields': 'geometry',
        },
      );
      final location = response.data['result']?['geometry']?['location'];
      final lat = location?['lat']?.toDouble();
      final lng = location?['lng']?.toDouble();
      if (lat != null && lng != null) {
        widget.onSelected(LatLng(lat, lng));
      }
    } catch (_) {
      // Ignore Google Places failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_kGooglePlacesApiKey.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Google Places API key is not configured. Use --dart-define=GOOGLE_PLACES_API_KEY=...',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.query.isEmpty) {
      return const Center(
        child: Text('Start typing to search for an address in India.'),
      );
    }

    if (_predictions.isEmpty) {
      return const Center(child: Text('No results found.'));
    }

    return ListView.builder(
      itemCount: _predictions.length,
      itemBuilder: (context, index) {
        final prediction = _predictions[index];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(prediction.description),
          onTap: () => _onPredictionTapped(prediction),
        );
      },
    );
  }
}

class _PlacePrediction {
  final String placeId;
  final String description;

  _PlacePrediction({required this.placeId, required this.description});
}
