import 'package:flutter/material.dart';
import 'package:api_client/api_client.dart';
import 'package:shared_models/shared_models.dart';
import '../services/booking_draft.dart';

class BookingProvider extends ChangeNotifier {
  final ApiClient _api;

  // Booking flow state
  String? _barberId;
  String? _barberName;
  List<Service> _selectedServices = [];
  DateTime? _selectedDate;
  String? _selectedTime;
  List<String> _availableSlots = [];
  bool _isLoadingSlots = false;
  bool _isCreatingBooking = false;
  String? _error;

  BookingProvider(this._api);

  String? get barberId => _barberId;
  String? get barberName => _barberName;
  List<Service> get selectedServices => _selectedServices;
  DateTime? get selectedDate => _selectedDate;
  String? get selectedTime => _selectedTime;
  List<String> get availableSlots => _availableSlots;
  bool get isLoadingSlots => _isLoadingSlots;
  bool get isCreatingBooking => _isCreatingBooking;
  String? get error => _error;

  int get totalInPence =>
      _selectedServices.fold(0, (sum, s) => sum + s.priceInPence);

  double get totalInPounds => totalInPence / 100.0;

  bool get canConfirm =>
      _selectedServices.isNotEmpty &&
      _selectedDate != null &&
      _selectedTime != null;

  void startBooking(String barberId, String barberName) {
    _barberId = barberId;
    _barberName = barberName;
    _selectedServices = [];
    _selectedDate = null;
    _selectedTime = null;
    _availableSlots = [];
    _error = null;
    notifyListeners();
  }

  void toggleService(Service service) {
    final exists = _selectedServices.any((s) => s.id == service.id);
    if (exists) {
      _selectedServices = _selectedServices.where((s) => s.id != service.id).toList();
    } else {
      _selectedServices = [..._selectedServices, service];
    }
    // Service change → total duration changes → bookable start times change.
    // Drop the stale time pick so the user re-selects against the new slots.
    _selectedTime = null;
    notifyListeners();

    if (_selectedDate != null) {
      _fetchAvailability(_selectedDate!);
    }
  }

  bool isServiceSelected(String serviceId) =>
      _selectedServices.any((s) => s.id == serviceId);

  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    _selectedTime = null;
    _availableSlots = [];
    _error = null;
    notifyListeners();

    await _fetchAvailability(date);
  }

  void selectTime(String time) {
    _selectedTime = time;
    notifyListeners();
  }

  Future<void> _fetchAvailability(DateTime date) async {
    if (_barberId == null) return;

    // Server requires serviceIds to compute slot duration. Bail early so we
    // don't make a guaranteed-400 round-trip; the booking screen renders a
    // "select a service first" message based on selectedServices.isEmpty.
    if (_selectedServices.isEmpty) {
      _availableSlots = [];
      _isLoadingSlots = false;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoadingSlots = true;
    _error = null;
    notifyListeners();

    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      _availableSlots = await _api.getBarberAvailability(
        _barberId!,
        dateStr,
        serviceIds: _selectedServices.map((s) => s.id).toList(),
      );
      _isLoadingSlots = false;
      notifyListeners();
    } catch (_) {
      _isLoadingSlots = false;
      _error = 'Could not load available times.';
      notifyListeners();
    }
  }

  /// Creates a booking. Returns the booking response data on success (includes clientSecret).
  /// Pass [latitude] / [longitude] so the barber knows where to drive — without
  /// them the booking row stores `null` and the barber app has no map pin.
  Future<Map<String, dynamic>?> createBooking({
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    if (!canConfirm || _barberId == null || _selectedDate == null) return null;

    _isCreatingBooking = true;
    _error = null;
    notifyListeners();

    try {
      final dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

      final result = await _api.createBooking({
        'barberId': _barberId,
        'date': dateStr,
        'startTime': _selectedTime,
        'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'serviceIds': _selectedServices.map((s) => s.id).toList(),
      });

      _isCreatingBooking = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isCreatingBooking = false;
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          _error = data['message'] as String;
        } else {
          _error = 'Could not create booking. Please try again.';
        }
      } else {
        _error = 'Could not create booking. Please try again.';
      }
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Persist the current booking picks so a guest can resume after the
  /// register wall on the payment step.
  Future<void> saveDraftForWall() async {
    if (_barberId == null || _selectedDate == null || _selectedTime == null) {
      return;
    }
    await BookingDraftService.save(
      BookingDraft(
        barberId: _barberId!,
        barberName: _barberName ?? 'Barber',
        services: List<Service>.from(_selectedServices),
        date: _selectedDate!,
        startTime: _selectedTime!,
      ),
    );
  }

  /// Pull the persisted draft into live state (usually called right after
  /// the user signs up / logs in from the register wall). Clears the draft
  /// on success so a second cold start doesn't resurrect it. Returns true
  /// when a draft was loaded.
  Future<bool> rehydrateFromDraft() async {
    final draft = await BookingDraftService.load();
    if (draft == null) return false;

    _barberId = draft.barberId;
    _barberName = draft.barberName;
    _selectedServices = draft.services;
    _selectedDate = draft.date;
    _selectedTime = draft.startTime;
    _availableSlots = [];
    _error = null;
    notifyListeners();

    await BookingDraftService.clear();
    return true;
  }

  void reset() {
    _barberId = null;
    _barberName = null;
    _selectedServices = [];
    _selectedDate = null;
    _selectedTime = null;
    _availableSlots = [];
    _error = null;
    notifyListeners();
  }
}
