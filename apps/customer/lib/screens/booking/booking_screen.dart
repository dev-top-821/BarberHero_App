import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/barber_profile_provider.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Future<void> _onContinue() async {
    final booking = context.read<BookingProvider>();
    final auth = context.read<AuthProvider>();

    // Signed-in users go straight to payment. Guests hit the wall: we stash
    // their picks and bounce them through register (with "Log In" reachable
    // from there), then resume on /payment after auth completes.
    if (auth.isAuthenticated) {
      Navigator.pushNamed(context, '/payment');
      return;
    }

    await booking.saveDraftForWall();
    if (!mounted) return;
    Navigator.pushNamed(context, '/register');
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final profileProvider = context.watch<BarberProfileProvider>();
    final services = profileProvider.services;

    return Scaffold(
      appBar: AppBar(
        title: Text('Book with ${booking.barberName ?? 'Barber'}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Services ───
                  const _SectionHeader(title: 'Select Services'),
                  const SizedBox(height: 8),
                  if (services.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No services available',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...services.map((service) {
                      final isSelected = booking.isServiceSelected(service.id);
                      return _ServiceTile(
                        service: service,
                        isSelected: isSelected,
                        onTap: () => booking.toggleService(service),
                      );
                    }),

                  const SizedBox(height: 24),

                  // ─── Calendar ───
                  const _SectionHeader(title: 'Select Date'),
                  const SizedBox(height: 8),
                  _MonthCalendar(
                    selectedDate: booking.selectedDate,
                    onDateSelected: (date) => booking.selectDate(date),
                  ),

                  const SizedBox(height: 24),

                  // ─── Time slots ───
                  const _SectionHeader(title: 'Select Time'),
                  const SizedBox(height: 8),
                  if (booking.selectedDate == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Pick a date first',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    )
                  else if (booking.isLoadingSlots)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (booking.availableSlots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        booking.selectedServices.isEmpty
                            ? 'Select a service first to see available times'
                            : 'No available times on this date',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    _TimeSlotGrid(
                      slots: booking.availableSlots,
                      selectedTime: booking.selectedTime,
                      onSelected: (time) => booking.selectTime(time),
                    ),

                  // Error
                  if (booking.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        booking.error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ─── Bottom bar ───
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      '\u00A3${booking.totalInPounds.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                // Confirm button
                Expanded(
                  child: ElevatedButton(
                    onPressed: booking.canConfirm ? _onContinue : null,
                    child: const Text('Continue to Payment'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    );
  }
}

// ─── Service Tile ───

class _ServiceTile extends StatelessWidget {
  final Service service;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${service.durationMinutes} min',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '\u00A3${service.priceInPounds.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month Calendar ───

class _MonthCalendar extends StatefulWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _MonthCalendar({this.selectedDate, required this.onDateSelected});

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon

    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    final canGoPrev = _currentMonth.isAfter(DateTime(now.year, now.month));

    return Column(
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: canGoPrev ? _prevMonth : null,
            ),
            Text(
              '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Day-of-week headers
        Row(
          children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        // Day grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: (firstWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) {
              return const SizedBox.shrink();
            }

            final day = index - (firstWeekday - 1) + 1;
            final date = DateTime(_currentMonth.year, _currentMonth.month, day);
            final isPast = date.isBefore(today);
            final isSelected = widget.selectedDate != null &&
                widget.selectedDate!.year == date.year &&
                widget.selectedDate!.month == date.month &&
                widget.selectedDate!.day == date.day;
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;

            return GestureDetector(
              onTap: isPast ? null : () => widget.onDateSelected(date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : null,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isPast
                            ? AppColors.border
                            : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Time Slot Grid ───

class _TimeSlotGrid extends StatelessWidget {
  final List<String> slots;
  final String? selectedTime;
  final ValueChanged<String> onSelected;

  const _TimeSlotGrid({
    required this.slots,
    this.selectedTime,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = slot == selectedTime;
        return GestureDetector(
          onTap: () => onSelected(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              slot,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
