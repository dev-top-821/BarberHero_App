import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:api_client/api_client.dart';
import 'package:shared_models/shared_models.dart';
import '../../config/theme.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../legal_document_screen.dart';

/// Platform fee in pence (£4.99).
const _platformFeePence = 499;

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _termsAccepted = false;
  String? _paymentError;
  final _addressFormKey = GlobalKey<FormState>();
  final _houseNumberController = TextEditingController();

  @override
  void dispose() {
    _houseNumberController.dispose();
    super.dispose();
  }

  String _composeAddress(String? savedAddress, String houseNumber) {
    final base = savedAddress ?? 'Pinned location';
    final hn = houseNumber.trim();
    if (hn.isEmpty) return base;
    return '$hn, $base';
  }

  void _openLegal(String title, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(title: title, assetPath: assetPath),
      ),
    );
  }

  Future<void> _pay() async {
    // House/flat number is required — geocoded addresses often omit it.
    if (!_addressFormKey.currentState!.validate()) return;

    final booking = context.read<BookingProvider>();
    final location = context.read<LocationProvider>();
    final api = context.read<ApiClient>();

    // Every print starts with >>>PAY so you can grep for it:
    //   flutter run | grep PAY
    debugPrint('>>>PAY step 1: createBooking publishableKeyLen=${Stripe.publishableKey.length}');
    setState(() => _isProcessing = true);

    // Record T&C / Privacy acceptance server-side first — POST /bookings
    // rejects with TERMS_NOT_ACCEPTED otherwise. The button is already
    // gated on the checkbox; this persists it. Skipped entirely while the
    // feature is dormant (placeholder legal text).
    if (kLegalEnabled) {
      try {
        await api.acceptTerms();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _paymentError =
              'Could not record your acceptance. Please try again.';
          _isProcessing = false;
        });
        return;
      }
    }

    final result = await booking.createBooking(
      address: _composeAddress(location.address, _houseNumberController.text),
      latitude: location.latitude,
      longitude: location.longitude,
    );

    debugPrint('>>>PAY step 2: createBooking returned null=${result == null}');
    if (!mounted) {
      setState(() => _isProcessing = false);
      return;
    }

    if (result == null) {
      debugPrint('>>>PAY ABORT: createBooking returned null (server error) — see booking.error=${booking.error}');
      setState(() {
        _paymentError = booking.error ?? 'Could not create booking.';
        _isProcessing = false;
      });
      return;
    }

    final bookingData = result['booking'] as Map<String, dynamic>?;
    final clientSecret = result['stripeClientSecret'] as String?;
    final bookingId = bookingData?['id'] as String?;

    debugPrint('>>>PAY step 3: bookingId=$bookingId clientSecret=${clientSecret == null ? "NULL" : "${clientSecret.substring(0, 15)}..."}');

    if (bookingData == null || clientSecret == null || bookingId == null) {
      debugPrint('>>>PAY ABORT: bookingData/clientSecret/bookingId is null');
      setState(() {
        _paymentError = 'Payment could not be initialised.';
        _isProcessing = false;
      });
      return;
    }

    setState(() => _paymentError = null);

    try {
      debugPrint('>>>PAY step 4: calling Stripe.instance.initPaymentSheet');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'BarberHero',
          style: ThemeMode.light,
        ),
      );
      debugPrint('>>>PAY step 5: initPaymentSheet OK, presenting');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('>>>PAY step 6: presentPaymentSheet OK');
      // The card is now authorized. Tell the server so it notifies the
      // barber — the barber only sees the request after this point
      // (signed flow: customer pays first). Best-effort: if this call
      // is lost the Stripe webhook promotes the booking anyway, so a
      // failure here must not block the customer's confirmation screen.
      try {
        await api.confirmBookingPayment(bookingId);
        debugPrint('>>>PAY step 7: confirmBookingPayment OK');
      } catch (e) {
        debugPrint('>>>PAY step 7: confirmBookingPayment failed (webhook will reconcile): $e');
      }
    } on StripeException catch (e, st) {
      debugPrint('>>>PAY Stripe EXCEPTION: code=${e.error.code} '
          'localized=${e.error.localizedMessage} '
          'message=${e.error.message}\n$st');
      // User cancelled or card was declined — roll back the booking so the
      // barber doesn't see a dangling request and the payment hold is
      // released server-side.
      await _rollbackBooking(api, bookingId);
      if (!mounted) return;
      setState(() {
        _paymentError = e.error.localizedMessage ??
            e.error.message ??
            (e.error.code == FailureCode.Canceled
                ? 'Payment cancelled.'
                : 'Payment failed. Please try again.');
        _isProcessing = false;
      });
      return;
    } catch (e, st) {
      debugPrint('>>>PAY UNEXPECTED ERROR: $e\n$st');
      await _rollbackBooking(api, bookingId);
      if (!mounted) return;
      setState(() {
        _paymentError = 'Payment failed: $e';
        _isProcessing = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    Navigator.pushReplacementNamed(
      context,
      '/confirmation',
      arguments: bookingData,
    );
  }

  Future<void> _rollbackBooking(ApiClient api, String bookingId) async {
    try {
      await api.cancelBooking(bookingId);
    } catch (_) {
      // Ignore — the webhook will also reconcile if the PaymentIntent expires.
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingProvider>();
    final serviceTotalPence = booking.totalInPence;
    final grandTotalPence = serviceTotalPence + _platformFeePence;

    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    String dateStr = '';
    if (booking.selectedDate != null) {
      final d = booking.selectedDate!;
      dateStr = '${d.day} ${monthNames[d.month - 1]} ${d.year}';
    }

    final location = context.watch<LocationProvider>();
    final savedAddress = location.address ?? 'Pinned location';

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Order summary ───
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Barber + date/time
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.barberName ?? 'Barber',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              booking.selectedTime ?? '',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Services breakdown
                  ...booking.selectedServices.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.name, style: const TextStyle(fontSize: 14)),
                          Text(
                            '\u00A3${s.priceInPounds.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 24),

                  // Platform fee
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Platform fee',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      Text(
                        '\u00A3${(_platformFeePence / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '\u00A3${(grandTotalPence / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Service Address ───
                  const Text(
                    'Service Address',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            savedAddress,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Form(
                    key: _addressFormKey,
                    child: TextFormField(
                      controller: _houseNumberController,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Flat / house number (e.g. Flat 3, 12A)',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please add your flat or house number';
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── CF-C1: Held-funds disclosure ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your payment will be held in pending and only released after the barber arrives and starts the service. '
                            'Funds are held for up to 24 hours after completion for dispute protection.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Payment method (via Stripe Payment Sheet) ───
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card_rounded, size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enter card details on the secure Stripe sheet after you tap Pay.',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Security badge
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        'Payments secured by Stripe',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),

                  // ─── T&C / Privacy consent (required before paying;
                  // hidden while the feature is dormant) ───
                  if (kLegalEnabled) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _termsAccepted,
                            onChanged: (v) =>
                                setState(() => _termsAccepted = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('I accept the ',
                                    style: TextStyle(fontSize: 13)),
                                GestureDetector(
                                  onTap: () => _openLegal(
                                    'Terms & Conditions',
                                    kAssetTermsAndConditions,
                                  ),
                                  child: const Text(
                                    'Terms & Conditions',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text(' and ',
                                    style: TextStyle(fontSize: 13)),
                                GestureDetector(
                                  onTap: () => _openLegal(
                                    'Privacy Policy',
                                    kAssetPrivacyPolicy,
                                  ),
                                  child: const Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Errors (booking creation failure OR Stripe payment failure)
                  if (booking.error != null || _paymentError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _paymentError ?? booking.error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ─── Pay button ───
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isProcessing ||
                        booking.isCreatingBooking ||
                        (kLegalEnabled && !_termsAccepted))
                    ? null
                    : _pay,
                child: (_isProcessing || booking.isCreatingBooking)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Pay \u00A3${(grandTotalPence / 100).toStringAsFixed(2)}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
