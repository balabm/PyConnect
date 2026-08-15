import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/network/osm_geocoding_service.dart';
import '../../../../core/providers.dart';

/// Address search field with OSM Nominatim autocomplete suggestions.
/// User types → debounced search → dropdown of matching addresses.
/// Selecting a suggestion returns the coordinates via [onSelected].
class AddressSearchField extends ConsumerStatefulWidget {
  const AddressSearchField({
    super.key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.initialText,
    this.initialLocation,
    this.hintText,
  });

  final String label;
  final IconData icon;
  final void Function(String address, LatLng location) onSelected;
  final String? initialText;
  final LatLng? initialLocation;
  final String? hintText;

  @override
  ConsumerState<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends ConsumerState<AddressSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<GeocodingResult> _suggestions = [];
  bool _loading = false;
  bool _showSuggestions = false;
  String? _selectedDisplayName;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText ?? '';
    _selectedDisplayName = widget.initialText;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Delay to allow tap on suggestion
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      } else if (_controller.text.isNotEmpty && _controller.text != _selectedDisplayName) {
        setState(() => _showSuggestions = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value == _selectedDisplayName) return;
    setState(() {
      _showSuggestions = true;
      _selectedDisplayName = null;
    });
    _debouncedSearch(value);
  }

  DateTime? _lastSearchTime;
  void _debouncedSearch(String query) {
    _lastSearchTime = DateTime.now();
    final searchTime = _lastSearchTime!;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (searchTime == _lastSearchTime && query.trim().length >= 3) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _loading = true);
    try {
      final service = ref.read(geocodingProvider);
      final results = await service.search(query, countryCodes: ['in'], limit: 5);
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {
      // Silent fail — suggestions just stay empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectSuggestion(GeocodingResult result) {
    _controller.text = result.displayName;
    _selectedDisplayName = result.displayName;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    widget.onSelected(result.displayName, result.location);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText ?? 'Search for an address...',
            prefixIcon: Icon(widget.icon),
            suffixIcon: _loading
                ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                : _controller.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _controller.clear(); setState(() { _suggestions = []; _selectedDisplayName = null; }); })
                    : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: _onChanged,
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final result = _suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.location_on, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      title: Text(result.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      onTap: () => _selectSuggestion(result),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
