import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationProvider extends ChangeNotifier {
  static const _latKey = 'user_latitude';
  static const _lngKey = 'user_longitude';
  static const _addressKey = 'user_address';

  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoading = false;
  String? _error;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get address => _address;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _latitude != null && _longitude != null;

  /// Load saved location from SharedPreferences.
  Future<bool> loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat != null && lng != null) {
      _latitude = lat;
      _longitude = lng;
      _address = prefs.getString(_addressKey);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Request GPS location via geolocator.
  Future<bool> requestGpsLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLoading = false;
        _error = 'Location services are disabled. Please enable them in settings.';
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLoading = false;
          _error = 'Location permission denied. You can enter your address manually.';
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLoading = false;
        _error = 'Location permission permanently denied. Please enable it in app settings or enter your address manually.';
        notifyListeners();
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      await _saveLocation(position.latitude, position.longitude, null);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Could not get your location. Please try again or enter your address manually.';
      notifyListeners();
      return false;
    }
  }

  /// Set location from a manually entered address (geocoded externally).
  Future<void> setManualLocation(double lat, double lng, String address) async {
    await _saveLocation(lat, lng, address);
    notifyListeners();
  }

  /// Geocode an address string using MapTiler API.
  /// Returns (lat, lng) or null if not found.
  Future<Map<String, double>?> geocodeAddress(String query, {required String apiKey}) async {
    _error = null;

    // Use dart:io HttpClient-free approach via Uri + http package
    // The api_client's Dio could be used, but we keep this standalone
    // to avoid coupling location logic to the auth-intercepted client.
    try {
      final uri = Uri.parse(
        'https://api.maptiler.com/geocoding/${Uri.encodeComponent(query)}.json'
        '?key=$apiKey&limit=1',
      );

      // Using dart:convert + dart:io-free http via the Dio from api_client
      // We do a simple inline fetch here:
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        _error = 'Could not find this address. Please check and try again.';
        notifyListeners();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final features = json['features'] as List;

      if (features.isEmpty) {
        _error = 'No results found for this address. Please try a different one.';
        notifyListeners();
        return null;
      }

      final coords = features[0]['geometry']['coordinates'] as List;
      // GeoJSON is [lng, lat]
      return {'latitude': (coords[1] as num).toDouble(), 'longitude': (coords[0] as num).toDouble()};
    } catch (_) {
      _error = 'Could not look up this address. Please check your connection.';
      notifyListeners();
      return null;
    }
  }

  Future<void> _saveLocation(double lat, double lng, String? address) async {
    _latitude = lat;
    _longitude = lng;
    _address = address;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, lat);
    await prefs.setDouble(_lngKey, lng);
    if (address != null) {
      await prefs.setString(_addressKey, address);
    } else {
      await prefs.remove(_addressKey);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
