import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

const _supportEmail = 'support@barberhero.app';
const _appVersion = '1.0.0';

/// Static help screen — FAQ + support contact. No in-app messaging so we
/// keep it dead-simple: tap-to-copy support email, plus a short FAQ.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Contact card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Our team usually responds within 24 hours.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(const ClipboardData(text: _supportEmail));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email copied to clipboard')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _supportEmail,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Frequently asked',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          const _Faq(
            q: 'When is my card actually charged?',
            a: "At booking your card is only authorised. You're charged when "
                "the barber arrives and you share your 4-digit code.",
          ),
          const _Faq(
            q: 'What if the barber doesn\'t turn up?',
            a: "30 minutes after the scheduled start, a 'Barber didn't arrive' "
                "button appears on the booking. Tapping it releases the hold "
                "and you're not charged.",
          ),
          const _Faq(
            q: 'Can I get a refund after the service?',
            a: "Within 24 hours of the service starting you can tap "
                "'Report issue / Request refund' on the booking. Our team "
                "reviews and responds within 24 hours.",
          ),
          const _Faq(
            q: 'Can I change my booking?',
            a: "If the booking is still pending (barber hasn't accepted yet) "
                "you can cancel it from the Bookings tab. To rebook for a "
                "different time, cancel and book again.",
          ),
          const _Faq(
            q: 'Where can I find my verification code?',
            a: "Open the booking from the Bookings tab — it's displayed on "
                "the card for any confirmed booking.",
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'BarberHero v$_appVersion',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(
          q,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              a,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
