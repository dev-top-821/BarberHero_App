import 'package:flutter/material.dart';
import 'package:api_client/api_client.dart';
import 'package:shared_models/shared_models.dart';

class BookingsProvider extends ChangeNotifier {
  final ApiClient _api;

  List<Booking> _bookings = [];
  bool _isLoading = false;
  String? _error;

  BookingsProvider(this._api);

  List<Booking> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Booking> get upcoming => _bookings
      .where((b) => !_isPast(b))
      .toList();

  List<Booking> get past => _bookings
      .where((b) => _isPast(b))
      .toList();

  bool _isPast(Booking b) {
    return b.status == 'COMPLETED' || b.status == 'CANCELLED';
  }

  Future<void> fetchBookings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bookings = await _api.getBookings();
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      _error = 'Could not load bookings.';
      notifyListeners();
    }
  }

  /// Cancels a booking. Server releases the Stripe hold and notifies the barber.
  /// Returns true on success; the caller can show a snackbar on false.
  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _api.cancelBooking(bookingId);
      await fetchBookings();
      return true;
    } catch (_) {
      return false;
    }
  }
}
