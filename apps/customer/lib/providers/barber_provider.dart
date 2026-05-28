import 'package:flutter/material.dart';
import 'package:api_client/api_client.dart';
import 'package:shared_models/shared_models.dart';

class BarberProvider extends ChangeNotifier {
  final ApiClient _api;

  List<NearbyBarber> _nearbyBarbers = [];
  List<NearbyBarber> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  String? _activeServiceFilter;

  BarberProvider(this._api);

  List<NearbyBarber> get nearbyBarbers => _nearbyBarbers;
  List<NearbyBarber> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get activeServiceFilter => _activeServiceFilter;

  Future<void> fetchNearbyBarbers({
    required double latitude,
    required double longitude,
    double radiusMiles = 10,
    String? service,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _nearbyBarbers = await _api.getNearbyBarbers(
        latitude: latitude,
        longitude: longitude,
        radiusMiles: radiusMiles,
        service: service,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Could not load nearby barbers. Pull down to retry.';
      notifyListeners();
    }
  }

  Future<void> searchBarbers({
    required double latitude,
    required double longitude,
    double radiusMiles = 10,
    String? service,
  }) async {
    _isSearching = true;
    _error = null;
    _activeServiceFilter = service;
    notifyListeners();

    try {
      _searchResults = await _api.getNearbyBarbers(
        latitude: latitude,
        longitude: longitude,
        radiusMiles: radiusMiles,
        service: service,
      );
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _isSearching = false;
      _error = 'Could not search barbers. Please try again.';
      notifyListeners();
    }
  }

  /// Filter search results locally by name.
  List<NearbyBarber> filterByName(String query) {
    if (query.isEmpty) return _searchResults;
    final q = query.toLowerCase();
    return _searchResults
        .where((b) => b.fullName.toLowerCase().contains(q))
        .toList();
  }

  void clearSearch() {
    _searchResults = [];
    _activeServiceFilter = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
