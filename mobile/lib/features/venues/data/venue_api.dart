import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';

/// Mirrors the backend's DayOfWeek string values.
enum DayOfWeek {
  monday('Monday'),
  tuesday('Tuesday'),
  wednesday('Wednesday'),
  thursday('Thursday'),
  friday('Friday'),
  saturday('Saturday'),
  sunday('Sunday');

  const DayOfWeek(this.value);

  final String value;

  static DayOfWeek parse(String raw) {
    for (final day in values) {
      if (day.value == raw) return day;
    }
    return monday;
  }
}

class Venue {
  Venue({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.occupancy,
    required this.isOpen,
    this.address,
    this.maxCapacity,
    this.description,
    this.availability,
    this.imageUrl,
    this.rating,
    this.reviewCount = 0,
    this.isPriorityPingActive = false,
  });

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        occupancy: (json['occupancy'] as num).toInt(),
        isOpen: json['isOpen'] as bool,
        address: json['address'] as String?,
        maxCapacity: (json['maxCapacity'] as num?)?.toInt(),
        description: json['description'] as String?,
        availability: (json['availability'] as List?)
            ?.map((e) => VenueAvailability.fromJson(e as Map<String, dynamic>))
            .toList(),
        imageUrl: json['imageUrl'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        isPriorityPingActive: json['isPriorityPingActive'] as bool? ?? false,
      );

  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final int occupancy;
  final bool isOpen;
  final String? address;
  final int? maxCapacity;
  final String? description;
  final List<VenueAvailability>? availability;
  final String? imageUrl;
  final double? rating;
  final int reviewCount;
  final bool isPriorityPingActive;
}

class VenueAvailability {
  VenueAvailability({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
  });

  factory VenueAvailability.fromJson(Map<String, dynamic> json) => VenueAvailability(
        dayOfWeek: _parseDayOfWeek(json['dayOfWeek'] as String),
        opensAt: _parseTimeOfDay(json['opensAt'] as String),
        closesAt: _parseTimeOfDay(json['closesAt'] as String),
      );

  static DayOfWeek _parseDayOfWeek(String value) => DayOfWeek.parse(value);

  static TimeOfDay _parseTimeOfDay(String value) {
    // Format: "HH:mm:ss" or "HH:mm"
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  final DayOfWeek dayOfWeek;
  final TimeOfDay opensAt;
  final TimeOfDay closesAt;
}

class VenueApi {
  VenueApi(this._api);

  final ApiClient _api;

  Future<List<Venue>> list({int? category, int page = 1, int pageSize = 50}) async {
    final body = await _api.get(
      '/api/venues',
      queryParameters: {
        'category': category,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (body as List)
        .map((e) => Venue.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single venue by ID with full details (capacity, hours, description).
  /// Used as fallback when deep-linking to /venues/:id/book without cached data.
  Future<Venue> getById(String id) async {
    final body = await _api.get('/api/venues/$id');
    return Venue.fromJson(body as Map<String, dynamic>);
  }
}