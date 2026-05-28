import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:api_client/api_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookings_provider.dart';
import '../chat/chat_conversation_screen.dart';
import '../report_issue_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guests have no token — skip the fetch to avoid a guaranteed 401.
      if (context.read<AuthProvider>().isAuthenticated) {
        context.read<BookingsProvider>().fetchBookings();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<BookingsProvider>();

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bookings')),
        body: const _GuestBookingsPrompt(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _BookingList(
                  bookings: provider.upcoming,
                  emptyMessage: 'No upcoming bookings',
                  showStepper: true,
                ),
                _BookingList(
                  bookings: provider.past,
                  emptyMessage: 'No past bookings',
                  showStepper: false,
                ),
              ],
            ),
    );
  }
}

class _GuestBookingsPrompt extends StatelessWidget {
  const _GuestBookingsPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 56, color: AppColors.border),
          const SizedBox(height: 16),
          const Text(
            'Sign up to see your bookings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Create an account to book a barber and track your appointments here.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Sign Up'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Log In'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyMessage;
  final bool showStepper;

  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.showStepper,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 56, color: AppColors.border),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                showStepper
                    ? 'Find a barber on the map to book your first appointment.'
                    : 'Past bookings will appear here once you have completed appointments.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<BookingsProvider>().fetchBookings(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _BookingCard(
          booking: bookings[index],
          showStepper: showStepper,
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final bool showStepper;

  const _BookingCard({required this.booking, required this.showStepper});

  @override
  Widget build(BuildContext context) {
    final barberName = booking.barber?.user?.fullName ?? 'Barber';
    final barberPhoto = booking.barber?.user?.profilePhoto;
    final serviceNames = booking.services
        ?.map((s) => s.service?.name ?? 'Service')
        .join(', ') ?? '';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${booking.date.day} ${months[booking.date.month - 1]}';
    final code = booking.verificationCode?.code;
    final showCode = code != null && !booking.verificationCode!.isUsed && _isActive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          _StatusBadge(status: booking.status),
          const SizedBox(height: 10),

          // Barber info row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surface,
                backgroundImage: barberPhoto != null
                    ? CachedNetworkImageProvider(barberPhoto)
                    : null,
                child: barberPhoto == null
                    ? Text(
                        barberName.isNotEmpty ? barberName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      barberName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (serviceNames.isNotEmpty)
                      Text(
                        serviceNames,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date, time, price row
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('$dateStr · ${booking.startTime}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                '\u00A3${booking.totalInPounds.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),

          // Verification code + "do not share" warning. Mirrors the
          // post-payment confirmation screen so the customer sees the
          // same reminder wherever the code is displayed.
          if (showCode) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Code: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          "Don't share this code with your barber until they have arrived at your address.",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Status stepper
          if (showStepper && _isActive) ...[
            const SizedBox(height: 12),
            _StatusStepper(status: booking.status),
          ],

          // Action buttons — active bookings.
          // Call button is only enabled once the barber marks himself
          // on the way (the server gates phone visibility on that status;
          // see booking-privacy.ts). Masked calling was deferred per
          // Docs/M3/08-phone-visibility.md.
          if (_isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(context, booking, barberName, barberPhoto),
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
                    onPressed: _canCall
                        ? () => _callBarber(context)
                        : () => _explainCallGate(context),
                    icon: Icon(
                      _canCall ? Icons.call_outlined : Icons.call_outlined,
                      size: 16,
                      color: _canCall ? null : AppColors.textSecondary,
                    ),
                    label: Text(
                      'Call',
                      style: TextStyle(
                        color: _canCall ? null : AppColors.textSecondary,
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

          // Cancel — only while PENDING (barber hasn't accepted yet).
          // Once CONFIRMED, cancellation policy applies — handle in M3.
          if (booking.status == 'PENDING') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, booking.id),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel booking'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],

          // No-show — CONFIRMED booking, >=30 min past scheduled start, and
          // the barber never entered the arrival code (that would have
          // flipped status to STARTED).
          if (booking.status == 'CONFIRMED' && _isPastGracePeriod) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmNoShow(context, booking.id),
                icon: const Icon(Icons.person_off_outlined, size: 16),
                label: const Text("Barber didn't arrive"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],

          // STARTED: customer can either confirm completion (releases the
          // barber's pending funds + opens review) or open a dispute. Both
          // are only available during the 24h hold window — after COMPLETED
          // the booking is archived and refunds would have to go through
          // support.
          if (booking.status == 'STARTED') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openReport(context, booking.id, barberName),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('Dispute'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmComplete(
                      context,
                      booking.id,
                      barberName,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Review button — completed bookings, and refunded bookings
          // (which land here as CANCELLED). Customers may still review
          // after a dispute refund; the server enforces the real rule.
          if (booking.status == 'COMPLETED' || booking.status == 'CANCELLED') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/review', arguments: {
                    'bookingId': booking.id,
                    'barberName': barberName,
                  });
                },
                icon: const Icon(Icons.star_outline_rounded, size: 16),
                label: const Text('Leave a Review'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _isActive {
    const activeStatuses = {'PENDING', 'CONFIRMED', 'ON_THE_WAY', 'STARTED'};
    return activeStatuses.contains(booking.status);
  }

  /// Server only returns the barber's phone for ON_THE_WAY and STARTED
  /// (see Barber_Admin/src/lib/booking-privacy.ts). Mirror that here so
  /// we disable the Call button before the number has arrived.
  bool get _canCall {
    final phone = booking.barber?.user?.phone;
    return phone != null && phone.isNotEmpty;
  }

  Future<void> _callBarber(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = booking.barber?.user?.phone;
    if (phone == null || phone.isEmpty) {
      _explainCallGate(context);
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't open the dialer."),
      ));
    }
  }

  void _explainCallGate(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
        "Calling is available once the barber is on the way. "
        "Use chat in the meantime.",
      ),
    ));
  }

  /// True once the scheduled start time is >= 30 minutes in the past.
  /// Server-side check uses the same threshold; duplicating it client-side
  /// is just so we don't show the "Barber didn't arrive" button too early.
  bool get _isPastGracePeriod {
    final parts = booking.startTime.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    final scheduled = DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      h,
      m,
    );
    return DateTime.now().isAfter(scheduled.add(const Duration(minutes: 30)));
  }

  Future<void> _confirmCancel(BuildContext context, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text(
          'Your payment hold will be released in full. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel booking',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final provider = context.read<BookingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.cancelBooking(bookingId);

    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? 'Booking cancelled.' : 'Could not cancel booking. Please try again.'),
        backgroundColor: success ? null : AppColors.error,
      ),
    );
  }

  Future<void> _confirmNoShow(BuildContext context, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Barber didn't arrive?"),
        content: const Text(
          'Confirm the barber never showed up. Your payment hold will be '
          'released in full. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Wait a bit longer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Confirm no-show',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final api = context.read<ApiClient>();
    final provider = context.read<BookingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await api.reportNoShow(bookingId);
      await provider.fetchBookings();
      messenger.showSnackBar(
        const SnackBar(content: Text('Booking cancelled and refunded.')),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] is Map &&
              (data['error'] as Map)['message'] is String)
          ? (data['error'] as Map)['message'] as String
          : 'Could not report no-show. Please try again.';
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not report no-show. Please try again.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _openChat(
    BuildContext context,
    Booking booking,
    String barberName,
    String? barberPhoto,
  ) async {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.user?.id;
    if (currentUserId == null) return;

    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);

    // Booking JSON doesn't carry the room id, and there's one room per
    // booking — resolve it from /chat/rooms on demand. Cheap enough and
    // avoids a schema change just to thread a single id.
    try {
      final rooms = await api.getChatRooms();
      if (!context.mounted) return;
      final match = rooms.where((r) => r.bookingId == booking.id).toList();
      if (match.isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text("Chat isn't available until the barber accepts."),
        ));
        return;
      }
      final room = match.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            roomId: room.id,
            peerName: barberName,
            peerPhoto: barberPhoto,
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

  Future<void> _openReport(
    BuildContext context,
    String bookingId,
    String barberName,
  ) async {
    final didSubmit = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportIssueScreen(
          bookingId: bookingId,
          barberName: barberName,
        ),
      ),
    );
    if (didSubmit == true && context.mounted) {
      // Refresh so any side-effects (e.g. admin-processed refund flips the
      // booking to CANCELLED) show up.
      await context.read<BookingsProvider>().fetchBookings();
    }
  }

  /// Customer-driven instant completion. Releases the barber's pending
  /// funds + flips status to COMPLETED, then opens the review screen.
  /// Past this point the dispute window is gone — the confirm dialog
  /// surfaces that explicitly so the customer can't bypass it accidentally.
  Future<void> _confirmComplete(
    BuildContext context,
    String bookingId,
    String barberName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm completion?'),
        content: const Text(
          "Funds will be released to the barber straight away. "
          "After this you can leave a review, but you won't be able to "
          "request a refund — use Dispute first if anything went wrong.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final api = context.read<ApiClient>();
    final provider = context.read<BookingsProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await api.completeBooking(bookingId);
      await provider.fetchBookings();
      if (!context.mounted) return;
      // Drop the customer straight onto the review screen — the new
      // booking status is COMPLETED, so the inline "Leave a Review" button
      // would also work, but routing here turns review into the natural
      // next step rather than an extra tap.
      navigator.pushNamed('/review', arguments: {
        'bookingId': bookingId,
        'barberName': barberName,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map &&
              data['error'] is Map &&
              (data['error'] as Map)['message'] is String)
          ? (data['error'] as Map)['message'] as String
          : 'Could not complete the booking. Please try again.';
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not complete the booking. Please try again.'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color text, String label) = switch (status) {
      'PENDING' => (AppColors.warning.withValues(alpha: 0.15), AppColors.warning, 'Pending'),
      'CONFIRMED' => (AppColors.success.withValues(alpha: 0.15), AppColors.success, 'Confirmed'),
      'ON_THE_WAY' => (const Color(0xFF2196F3).withValues(alpha: 0.15), const Color(0xFF2196F3), 'On the way'),
      'STARTED' => (const Color(0xFF9C27B0).withValues(alpha: 0.15), const Color(0xFF9C27B0), 'Started'),
      'COMPLETED' => (AppColors.success.withValues(alpha: 0.15), AppColors.success, 'Completed'),
      'CANCELLED' => (AppColors.error.withValues(alpha: 0.15), AppColors.error, 'Cancelled'),
      _ => (AppColors.surface, AppColors.textSecondary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  static const _steps = ['CONFIRMED', 'ON_THE_WAY', 'STARTED'];
  static const _labels = ['Confirmed', 'On the way', 'Started'];

  int get _currentIndex {
    final idx = _steps.indexOf(status);
    return idx >= 0 ? idx : -1;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length, (i) {
        final isCompleted = i <= _currentIndex;
        final isCurrent = i == _currentIndex;

        return Expanded(
          child: Row(
            children: [
              // Icon
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppColors.success : AppColors.surface,
                  border: Border.all(
                    color: isCompleted ? AppColors.success : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 6),
              // Label
              Flexible(
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Connector line
              if (i < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: i < _currentIndex ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
