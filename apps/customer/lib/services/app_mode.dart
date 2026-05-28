import 'package:shared_preferences/shared_preferences.dart';

/// Tri-state flag that drives first-launch routing.
///
/// - [firstRun]  — brand new install; show the Welcome screen.
/// - [guest]     — user chose "Continue as guest"; skip Welcome forever and
///                 drop straight into the browsing UI. Booking wall still
///                 triggers at payment.
/// - [account]   — user has registered or logged in at least once on this
///                 device; guest option is revoked permanently, even after
///                 logout.
enum AppMode { firstRun, guest, account }

class AppModeService {
  static const _key = 'app_mode';

  static Future<AppMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'guest':
        return AppMode.guest;
      case 'account':
        return AppMode.account;
      default:
        return AppMode.firstRun;
    }
  }

  static Future<void> setGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'guest');
  }

  /// Idempotent — safe to call on every successful login/register.
  /// Once set, this is never reverted (logout keeps the device in `account`).
  static Future<void> setAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'account');
  }
}
