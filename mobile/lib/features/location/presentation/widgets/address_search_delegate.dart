import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_place/google_place.dart' as gp;
import 'package:latlong2/latlong.dart';

const String _kGooglePlacesApiKey = String.fromEnvironment(
  'GOOGLE_PLACES_API_KEY',
  defaultValue: '',
);

/// Search delegate backed by Google Places autocomplete, debounced by 300ms.
/// Restricted to India and biased around Pondicherry.
class AddressSearchDelegate extends SearchDelegate<LatLng?> {
  AddressSearchDelegate({required this.onSelected});

  final ValueChanged<LatLng> onSelected;

  final gp.GooglePlace? _googlePlace = _kGooglePlacesApiKey.isNotEmpty
      ? gp.GooglePlace(_kGooglePlacesApiKey)
      : null;

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
        googlePlace: _googlePlace,
        onSelected: (latLng) {
          onSelected(latLng);
          close(context, null);
        },
      );

  @override
  Widget buildSuggestions(BuildContext context) => _SuggestionsList(
        query: query,
        googlePlace: _googlePlace,
        onSelected: (latLng) {
          onSelected(latLng);
          close(context, null);
        },
      );
}

class _SuggestionsList extends StatefulWidget {
  const _SuggestionsList({
    required this.query,
    required this.googlePlace,
    required this.onSelected,
  });

  final String query;
  final gp.GooglePlace? googlePlace;
  final ValueChanged<LatLng> onSelected;

  @override
  _SuggestionsListState createState() => _SuggestionsListState();
}

class _SuggestionsListState extends State<_SuggestionsList> {
  List<gp.AutocompletePrediction> _predictions = [];
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
    if (input.isEmpty || widget.googlePlace == null) {
      setState(() {
        _predictions = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await widget.googlePlace!.autocomplete.get(
        input,
        components: 'country:in',
        language: 'en',
        location: gp.Location(lat: 11.9356, lng: 79.8301),
        radius: 50000,
      );
      setState(() {
        _predictions = response?.predictions ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _predictions = [];
        _loading = false;
      });
    }
  }

  Future<void> _onPredictionTapped(gp.AutocompletePrediction prediction) async {
    final placeId = prediction.placeId;
    if (placeId == null || placeId.isEmpty || widget.googlePlace == null) return;

    try {
      final details = await widget.googlePlace!.details.get(
        placeId,
        fields: ['geometry'],
      );
      final lat = details?.result?.geometry?.location?.lat;
      final lng = details?.result?.geometry?.location?.lng;
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
          title: Text(prediction.description ?? ''),
          onTap: () => _onPredictionTapped(prediction),
        );
      },
    );
  }
}
