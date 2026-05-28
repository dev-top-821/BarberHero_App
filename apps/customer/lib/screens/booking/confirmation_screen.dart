import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const ConfirmationScreen({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    final barber = bookingData['barber'];
    final barberUser = barber?['user'];
    final barberName = barberUser?['fullName'] ?? 'Barber';
    final services = bookingData['services'] as List? ?? [];
    final totalInPence = bookingData['totalInPence'] as int? ?? 0;
    final startTime = bookingData['startTime'] ?? '';
    final dateStr = bookingData['date'] ?? '';
    final verificationCode = bookingData['verificationCode'];
    final code = verificationCode?['code'] as String?;

    // Format date
    String displayDate = '';
    if (dateStr is String && dateStr.isNotEmpty) {
      try {
        final d = DateTime.parse(dateStr);
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        displayDate = '${d.day} ${months[d.month - 1]} ${d.year}';
      } catch (_) {
        displayDate = dateStr;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                // Green checkmark
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 20),

                // CF-C2: Updated copy — booking not yet confirmed by barber
                const Text(
                  'Payment Received',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your booking will be confirmed once a barber accepts the request.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Booking card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        barberName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(displayDate, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          const SizedBox(width: 16),
                          const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(startTime, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Services
                      ...services.map((s) {
                        final svc = s['service'];
                        final name = svc?['name'] ?? 'Service';
                        final price = (s['priceInPence'] as int? ?? 0) / 100;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 14)),
                              Text('\u00A3${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(
                            '\u00A3${(totalInPence / 100).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Verification code
                if (code != null && code.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Your Verification Code',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        // Code digits displayed large
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: code.split('').map((digit) {
                            return Container(
                              width: 48,
                              height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                digit,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        // CF-C3: Verification code warning
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Do not share this code until the barber has arrived in person.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Pop everything, then open Home rooted on the
                      // Bookings tab (index 1).
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                        arguments: 1,
                      );
                    },
                    child: const Text('View Bookings'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
