import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/env.dart';
import '../providers/location_provider.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _showManualEntry = false;
  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  bool _isGeocoding = false;

  @override
  void dispose() {
    _addressController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _requestGps() async {
    final location = context.read<LocationProvider>();
    final success = await location.requestGpsLocation();
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _submitManualAddress() async {
    final street = _addressController.text.trim();
    final postcode = _postcodeController.text.trim();

    if (street.isEmpty || postcode.isEmpty) return;

    final query = '$street, $postcode, London, UK';
    final location = context.read<LocationProvider>();

    setState(() => _isGeocoding = true);

    final coords = await location.geocodeAddress(query, apiKey: Env.mapTilerKey);

    if (!mounted) return;
    setState(() => _isGeocoding = false);

    if (coords != null) {
      await location.setManualLocation(
        coords['latitude']!,
        coords['longitude']!,
        query,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Map pin icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Headline
              const Text(
                'Where are you?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Allow location access so we can show barbers near you',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Error
              if (location.error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    location.error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Allow Location button
              if (!_showManualEntry) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: location.isLoading ? null : _requestGps,
                    icon: location.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                    label: Text(location.isLoading ? 'Getting location...' : 'Allow Location'),
                  ),
                ),
                const SizedBox(height: 16),

                // Manual entry toggle
                GestureDetector(
                  onTap: () {
                    location.clearError();
                    setState(() => _showManualEntry = true);
                  },
                  child: const Text(
                    'Enter address manually',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // Manual address entry
              if (_showManualEntry) ...[
                TextFormField(
                  controller: _addressController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Street and house number',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _postcodeController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  onFieldSubmitted: (_) => _submitManualAddress(),
                  decoration: const InputDecoration(
                    hintText: 'Postcode',
                    prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isGeocoding ? null : _submitManualAddress,
                    child: _isGeocoding
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirm'),
                  ),
                ),
                const SizedBox(height: 12),

                // Back to GPS option
                GestureDetector(
                  onTap: () {
                    location.clearError();
                    setState(() => _showManualEntry = false);
                  },
                  child: const Text(
                    'Use GPS instead',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
