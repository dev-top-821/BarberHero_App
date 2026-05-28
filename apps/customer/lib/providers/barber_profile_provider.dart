import 'package:flutter/material.dart';
import 'package:api_client/api_client.dart';
import 'package:shared_models/shared_models.dart';

class BarberProfileProvider extends ChangeNotifier {
  final ApiClient _api;

  BarberProfile? _profile;
  List<Service> _services = [];
  List<Review> _reviews = [];
  bool _isLoading = false;
  String? _error;

  BarberProfileProvider(this._api);

  BarberProfile? get profile => _profile;
  List<Service> get services => _services;
  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBarber(String barberId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch profile, services, and reviews in parallel
      final results = await Future.wait([
        _api.getBarberProfile(barberId),
        _api.getBarberServices(barberId),
        _api.getBarberReviews(barberId),
      ]);

      _profile = results[0] as BarberProfile;
      _services = results[1] as List<Service>;
      _reviews = results[2] as List<Review>;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Could not load barber profile. Please try again.';
      notifyListeners();
    }
  }

  void clear() {
    _profile = null;
    _services = [];
    _reviews = [];
    _error = null;
    notifyListeners();
  }
}
