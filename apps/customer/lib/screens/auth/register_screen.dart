import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/app_mode.dart';
import '../../services/booking_draft.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Lenient phone shape — digits + optional + / spaces / dashes / parens.
  // Server validates with the same charset before saving.
  static final _phoneRegex = RegExp(r'^\+?[0-9\s().-]{7,20}$');
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _pendingBarberName;

  @override
  void initState() {
    super.initState();
    _checkPendingBooking();
  }

  Future<void> _checkPendingBooking() async {
    final draft = await BookingDraftService.load();
    if (mounted && draft != null) {
      setState(() => _pendingBarberName = draft.barberName);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text,
    );

    if (!success || !mounted) return;

    await AppModeService.setAccount();
    if (!mounted) return;

    final booking = context.read<BookingProvider>();
    final resumed = await booking.rehydrateFromDraft();
    if (!mounted) return;

    if (resumed) {
      Navigator.pushNamedAndRemoveUntil(context, '/payment', (r) => false);
      return;
    }

    final location = context.read<LocationProvider>();
    final hasLocation = location.hasLocation || await location.loadSavedLocation();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      hasLocation ? '/home' : '/location',
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/logo_text.png',
                    height: 120,
                  ),
                  const SizedBox(height: 24),

                  // Booking-resume banner — surfaced when a guest tapped
                  // "Continue to Payment" and was bounced here.
                  if (_pendingBarberName != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sign up to complete your booking with $_pendingBarberName.',
                              style: const TextStyle(fontSize: 13, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 16),

                  // Error message
                  if (auth.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Full name
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Phone — required so the barber can reach the customer
                  // once the booking hits ON_THE_WAY (gate in
                  // booking-privacy.ts).
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Phone (e.g. +44 7700 900200)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Phone number is required';
                      if (!_phoneRegex.hasMatch(value)) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Confirm password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Switch to login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
