import 'package:flutter/material.dart';
import 'package:api_client/api_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'booking/code_entry_screen.dart';
import 'chat/chat_conversation_screen.dart';

/// Barber dashboard — jobs list + online toggle. Lives inside the
/// bottom-nav HomeShell as the "Jobs" tab, so wallet/chat/profile/etc.
/// are reached via tabs rather than AppBar shortcuts.
///
/// Each booking card exposes the action appropriate for its status:
///   PENDING     → Accept
///   CONFIRMED   → On the way (→ ON_THE_WAY; unlocks customer phone)
///   ON_THE_WAY  → Call customer + Enter arrival code (→ STARTED)
///   STARTED     → read-only (awaiting 24h release)
///   COMPLETED   → read-only (released)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  List<Booking> _bookings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final bookings = await api.getBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load bookings.';
      });
    }
  }

  List<Booking> get _active => _bookings.where((b) {
        const live = {'PENDING', 'CONFIRMED', 'ON_THE_WAY', 'STARTED'};
        return live.contains(b.status);
      }).toList();

  List<Booking> get _past => _bookings.where((b) {
        const done = {'COMPLETED', 'CANCELLED'};
        return done.contains(b.status);
      }).toList();

  Future<void> _accept(String id) async {
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.updateBookingStatus(id, 'CONFIRMED');
      await _load();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not accept booking.')));
    }
  }

  Future<void> _markOnTheWay(String id) async {
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.updateBookingStatus(id, 'ON_THE_WAY');
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text("Customer notified. You can now call them if needed."),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Could not update status. Please try again."),
      ));
    }
  }

  Future<void> _callCustomer(Booking b) async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = b.customer?.phone;
    if (phone == null || phone.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Customer's phone number isn't available yet."),
      ));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't open the dialer."),
      ));
    }
  }

  bool _onlineToggling = false;

  Future<void> _setOnline(bool value) async {
    // Capture refs before awaits so we don't use context after setState gaps.
    final api = context.read<ApiClient>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _onlineToggling = true);
    try {
      await api.setOnlineStatus(value);
      // Refresh user so the AuthProvider's cached BarberProfileSummary
      // reflects the new isOnline value — keeps the switch in sync after
      // rebuilds without another GET.
      await auth.refreshUser();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not update your status. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _onlineToggling = false);
    }
  }

  Future<void> _cancel(String id) async {
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('The customer will be refunded immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.cancelBooking(id);
      await _load();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not cancel booking.')));
    }
  }

  Future<void> _enterCode(Booking b) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CodeEntryScreen(
          bookingId: b.id,
          customerName: b.customer?.fullName ?? 'customer',
        ),
      ),
    );
    if (ok == true) await _load();
  }

  /// Opens the chat room for this booking. Mirrors the customer-side flow
  /// in bookings_screen.dart — booking JSON doesn't carry the room id, so
  /// we resolve it from /chat/rooms on demand.
  Future<void> _openChat(Booking b) async {
    final api = context.read<ApiClient>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final currentUserId = auth.user?.id;
    if (currentUserId == null) return;

    try {
      final rooms = await api.getChatRooms();
      if (!mounted) return;
      final match = rooms.where((r) => r.bookingId == b.id).toList();
      if (match.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text("Chat isn't available for this booking yet."),
        ));
        return;
      }
      final room = match.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            roomId: room.id,
            peerName: b.customer?.fullName ?? 'Customer',
            peerPhoto: b.customer?.profilePhoto,
            currentUserId: currentUserId,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not open chat. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (auth.user != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Hi, ${auth.user!.fullName.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Online/offline status — drives visibility in the
                  // customer map (`GET /barbers/nearby` filters by isOnline).
                  _OnlineStatusCard(
                    isOnline: auth.user?.barberProfile?.isOnline ?? false,
                    isToggling: _onlineToggling,
                    onChanged: _onlineToggling ? null : _setOnline,
                  ),
                  const SizedBox(height: 16),


                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Active',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_active.isEmpty)
                    _EmptySection(
                      icon: Icons.event_available_outlined,
                      title: 'No active bookings',
                      message: (auth.user?.barberProfile?.isOnline ?? false)
                          ? "Customers nearby can see you. New bookings will land here."
                          : "Flip the switch above to start showing on the customer map.",
                    )
                  else
                    ..._active.map((b) => _BookingCard(
                          booking: b,
                          onAccept: () => _accept(b.id),
                          onEnterCode: () => _enterCode(b),
                          onCancel: () => _cancel(b.id),
                          onMarkOnTheWay: () => _markOnTheWay(b.id),
                          onCallCustomer: () => _callCustomer(b),
                          onOpenChat: () => _openChat(b),
                        )),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_past.isEmpty)
                    const _EmptySection(
                      icon: Icons.history_rounded,
                      title: 'No past bookings yet',
                      message: 'Completed and cancelled bookings will appear here.',
                    )
                  else
                    ..._past.take(10).map((b) => _BookingCard(
                          booking: b,
                          onAccept: () {},
                          onEnterCode: () {},
                          onCancel: () {},
                          onMarkOnTheWay: () {},
                          onCallCustomer: () {},
                          onOpenChat: () => _openChat(b),
                        )),
                ],
              ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineStatusCard extends StatelessWidget {
  final bool isOnline;
  final bool isToggling;
  final ValueChanged<bool>? onChanged;

  const _OnlineStatusCard({
    required this.isOnline,
    required this.isToggling,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isOnline ? AppColors.online : AppColors.offline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "You're online" : "You're offline",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isOnline
                      ? 'Visible to customers and accepting bookings.'
                      : 'Hidden from the customer map.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isToggling)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: isOnline,
              onChanged: onChanged,
              activeThumbColor: AppColors.online,
            ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onAccept;
  final VoidCallback onEnterCode;
  final VoidCallback onCancel;
  final VoidCallback onMarkOnTheWay;
  final VoidCallback onCallCustomer;
  final VoidCallback onOpenChat;

  const _BookingCard({
    required this.booking,
    required this.onAccept,
    required this.onEnterCode,
    required this.onCancel,
    required this.onMarkOnTheWay,
    required this.onCallCustomer,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final customerName = booking.customer?.fullName ?? 'Customer';
    final serviceNames = booking.services
            ?.map((s) => s.service?.name ?? 'Service')
            .join(', ') ??
        '';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${booking.date.day} ${months[booking.date.month - 1]}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: booking.status),
              const Spacer(),
              Text(
                '£${booking.totalInPounds.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            customerName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (serviceNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                serviceNames,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '$dateStr · ${booking.startTime}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (booking.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    booking.address,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _actionsFor(booking.status),
        ],
      ),
    );
  }

  Widget _actionsFor(String status) {
    // PENDING: only Decline + Accept — chat room + customer phone don't
    // exist yet (chat room is created on CONFIRMED, phone unlocks at
    // ON_THE_WAY). Show no chat/call row here.
    if (status == 'PENDING') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('Accept'),
            ),
          ),
        ],
      );
    }

    // For CONFIRMED / ON_THE_WAY / STARTED, layout is two stacked rows:
    //   1. Status row — the action that advances the booking lifecycle
    //   2. Chat + Call row — communication actions, always visible
    // The Call button gates on customer phone visibility (server returns
    // it only for ON_THE_WAY / STARTED, see booking-privacy.ts).
    final statusRow = _statusActionRow(status);
    if (statusRow == null) return const SizedBox.shrink();

    final hasCustomerPhone = (booking.customer?.phone ?? '').isNotEmpty;
    final canCall = hasCustomerPhone &&
        (status == 'ON_THE_WAY' || status == 'STARTED');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        statusRow,
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Chat'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canCall ? onCallCustomer : null,
                icon: Icon(
                  Icons.call_outlined,
                  size: 16,
                  color: canCall ? null : AppColors.textSecondary,
                ),
                label: Text(
                  'Call',
                  style: TextStyle(
                    color: canCall ? null : AppColors.textSecondary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The top-row action that drives the booking forward. Returns null for
  /// terminal statuses (COMPLETED / CANCELLED) where there's nothing to
  /// surface.
  Widget? _statusActionRow(String status) {
    switch (status) {
      case 'CONFIRMED':
        // Cancel + "On the way" — marking on-the-way unlocks the customer
        // phone number server-side (see booking-privacy.ts).
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onMarkOnTheWay,
                icon: const Icon(Icons.directions_run_rounded, size: 16),
                label: const Text('On the way'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
        );
      case 'ON_THE_WAY':
        // Single full-width "I've arrived" — once tapped, the customer
        // enters the verification code which flips status to STARTED.
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onEnterCode,
            icon: const Icon(Icons.pin_outlined, size: 16),
            label: const Text("I've arrived"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              minimumSize: Size.zero,
            ),
          ),
        );
      case 'STARTED':
        // No active action — service is in progress. Show the funds-hold
        // notice instead of a button.
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: AppColors.warning),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Funds pending — released 24h after start.',
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      default:
        return null;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      'PENDING' => (AppColors.warning.withValues(alpha: 0.15), AppColors.warning, 'New request'),
      'CONFIRMED' => (AppColors.earnings.withValues(alpha: 0.15), AppColors.earnings, 'Confirmed'),
      'ON_THE_WAY' => (const Color(0xFF2196F3).withValues(alpha: 0.15), const Color(0xFF2196F3), 'On the way'),
      'STARTED' => (const Color(0xFF9C27B0).withValues(alpha: 0.15), const Color(0xFF9C27B0), 'Started'),
      'COMPLETED' => (AppColors.earnings.withValues(alpha: 0.15), AppColors.earnings, 'Completed'),
      'CANCELLED' => (AppColors.error.withValues(alpha: 0.15), AppColors.error, 'Cancelled'),
      _ => (AppColors.surface, AppColors.textSecondary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
