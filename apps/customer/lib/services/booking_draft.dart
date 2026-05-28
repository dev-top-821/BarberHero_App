import 'dart:convert';

import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A guest's in-progress booking, stashed locally when they hit the register
/// wall on the payment step. After register/login succeeds we pull this back
/// out to resume the booking without losing their picks.
class BookingDraft {
  final String barberId;
  final String barberName;
  final List<Service> services;
  final DateTime date;
  final String startTime;

  const BookingDraft({
    required this.barberId,
    required this.barberName,
    required this.services,
    required this.date,
    required this.startTime,
  });

  Map<String, dynamic> toJson() => {
        'barberId': barberId,
        'barberName': barberName,
        'services': services.map((s) => s.toJson()).toList(),
        'date': date.toIso8601String(),
        'startTime': startTime,
      };

  static BookingDraft? tryFromJson(Map<String, dynamic> json) {
    try {
      return BookingDraft(
        barberId: json['barberId'] as String,
        barberName: json['barberName'] as String,
        services: (json['services'] as List)
            .map((s) => Service.fromJson(s as Map<String, dynamic>))
            .toList(),
        date: DateTime.parse(json['date'] as String),
        startTime: json['startTime'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

class BookingDraftService {
  static const _key = 'pending_booking_draft';

  static Future<void> save(BookingDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  static Future<BookingDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    BookingDraft? draft;
    try {
      draft = BookingDraft.tryFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      draft = null;
    }
    if (draft == null) {
      // Corrupt JSON — drop it so we don't re-read it every launch.
      await prefs.remove(_key);
      return null;
    }

    // Stale: the booked slot is already in the past. A guest could have
    // tapped "Continue to Payment" days ago and never completed register —
    // resuming onto a dead slot would only fail at POST /bookings. Drop it
    // silently so the banner doesn't mislead them either.
    final parts = draft.startTime.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final slotMoment = DateTime(
        draft.date.year,
        draft.date.month,
        draft.date.day,
        h,
        m,
      );
      if (slotMoment.isBefore(DateTime.now())) {
        await prefs.remove(_key);
        return null;
      }
    }

    return draft;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
