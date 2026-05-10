import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:api_client/api_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/photo_uploader.dart';

const int _minPortfolio = 2;
const int _maxPortfolio = 6;
const int _minBio = 50;
const int _maxBio = 500;

// UK postcode — same pattern used on register.
final _postcodeRegex = RegExp(
  r'^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$',
  caseSensitive: false,
);

/// Barber's profile screen — doubles as onboarding (INCOMPLETE/REJECTED)
/// and post-approval editor (APPROVED/PENDING). Mode is inferred from
/// `status` returned by GET /barber/profile:
///   INCOMPLETE / REJECTED → "Complete Your Profile", shows Submit bar.
///   APPROVED / PENDING   → "Edit Profile", no Submit bar, back button on.
/// Every section saves incrementally; the Submit bar only flips status.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final ApiClient _api;
  late final PhotoUploader _uploader;
  final _picker = ImagePicker();
  final _bioController = TextEditingController();
  final _postcodeController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  // Hydrated from GET /barber/profile on open.
  String _status = 'INCOMPLETE';
  String? _profilePhoto;
  List<Map<String, dynamic>> _photos = [];
  List<Service> _services = [];

  // Settings — editable inline; dirty bit drives the Save button.
  double _radiusMiles = 5.0;
  int _noticeHours = 2;
  double _loadedRadius = 5.0;
  int _loadedNotice = 2;
  bool _savingSettings = false;

  bool _uploadingProfile = false;
  bool _uploadingPortfolio = false;

  bool get _isEditMode =>
      _status == 'APPROVED' || _status == 'PENDING' || _status == 'BLOCKED';
  bool get _settingsDirty =>
      _radiusMiles != _loadedRadius || _noticeHours != _loadedNotice;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _uploader = PhotoUploader(_api);
    _load();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.getMyBarberProfile();
      _status = profile.status;
      _profilePhoto = profile.user?.profilePhoto;
      _photos = (profile.photos ?? [])
          .map((p) => {
                'id': p.id,
                'url': p.url,
              })
          .toList();
      _services = profile.services ?? [];
      _bioController.text = profile.bio ?? '';
      _postcodeController.text = profile.postcode ?? '';

      // Settings — use existing values or safe defaults.
      final s = profile.settings;
      if (s != null) {
        _radiusMiles = s.serviceRadiusMiles;
        _noticeHours = s.minBookingNoticeHours;
      }
      _loadedRadius = _radiusMiles;
      _loadedNotice = _noticeHours;
    } catch (e) {
      _error = 'Could not load profile. Please try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // ─── Profile photo ───

  Future<void> _pickProfilePhoto() async {
    // Capture provider ref before any await — avoids reaching into
    // context after the picker / upload async gap.
    final auth = context.read<AuthProvider>();
    final file = await _pickImage();
    if (file == null) return;
    setState(() => _uploadingProfile = true);
    try {
      final url = await _uploader.uploadProfilePhoto(file);
      if (!mounted) return;
      setState(() => _profilePhoto = url);
      // Refresh AuthProvider so the new avatar appears on the dashboard
      // header + chat list immediately after the picker closes.
      await auth.refreshUser();
    } catch (e) {
      if (mounted) _showSnack('Upload failed: ${_shortError(e)}');
    } finally {
      if (mounted) setState(() => _uploadingProfile = false);
    }
  }

  // ─── Portfolio ───

  Future<void> _addPortfolio() async {
    if (_photos.length >= _maxPortfolio) return;
    final file = await _pickImage();
    if (file == null) return;
    setState(() => _uploadingPortfolio = true);
    try {
      final photo = await _uploader.uploadPortfolioPhoto(file);
      if (!mounted) return;
      setState(() {
        _photos = [..._photos, {'id': photo['id'], 'url': photo['url']}];
      });
    } catch (e) {
      if (mounted) _showSnack('Upload failed: ${_shortError(e)}');
    } finally {
      if (mounted) setState(() => _uploadingPortfolio = false);
    }
  }

  Future<void> _removePortfolio(String id) async {
    try {
      await _api.deletePortfolioPhoto(id);
      if (!mounted) return;
      setState(() {
        _photos = _photos.where((p) => p['id'] != id).toList();
      });
    } catch (e) {
      if (mounted) _showSnack('Could not remove photo.');
    }
  }

  // ─── Bio ───

  // Saves silently when the user moves focus off the bio field. We don't
  // surface errors here — the Submit step will re-validate anyway.
  Future<void> _saveBioQuiet() async {
    try {
      await _api.updateBarberProfile({'bio': _bioController.text.trim()});
    } catch (_) {}
  }

  // Same pattern for postcode — persist on blur so partial edits don't
  // get lost when the barber closes the screen.
  Future<void> _savePostcodeQuiet() async {
    final value = _postcodeController.text.trim().toUpperCase();
    if (value.isEmpty) return;
    if (!_postcodeRegex.hasMatch(value)) return;
    try {
      await _api.updateBarberProfile({'postcode': value});
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.updateSettings({
        'serviceRadiusMiles': _radiusMiles,
        'minBookingNoticeHours': _noticeHours,
      });
      if (!mounted) return;
      setState(() {
        _loadedRadius = _radiusMiles;
        _loadedNotice = _noticeHours;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not save settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  // ─── Services ───

  Future<void> _addServiceDialog() async {
    final result = await showModalBottomSheet<_ServiceFormResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _ServiceFormSheet(),
    );
    if (result == null) return;

    try {
      final created = await _api.addService({
        'name': result.name,
        'durationMinutes': result.durationMinutes,
        'priceInPence': result.priceInPounds * 100,
      });
      if (!mounted) return;
      setState(() => _services = [..._services, created]);
    } catch (e) {
      if (mounted) _showSnack('Could not add service.');
    }
  }

  Future<void> _removeService(String id) async {
    try {
      await _api.deleteService(id);
      if (!mounted) return;
      setState(() {
        _services = _services.where((s) => s.id != id).toList();
      });
    } catch (_) {
      if (mounted) _showSnack('Could not remove service.');
    }
  }

  // ─── Submit ───

  bool get _canSubmit {
    if (_profilePhoto == null) return false;
    if (_photos.length < _minPortfolio) return false;
    final bio = _bioController.text.trim();
    if (bio.length < _minBio || bio.length > _maxBio) return false;
    if (_services.isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    // Capture provider ref before any await — avoids using context after
    // an async gap if the widget unmounts.
    final auth = context.read<AuthProvider>();

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Persist the latest bio text before asking the server to validate.
    await _saveBioQuiet();

    try {
      await _api.submitForReview();
      // Refresh user so AuthProvider picks up status=PENDING before the
      // next splash-equivalent check.
      await auth.refreshUser();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/pending', (_) => false);
    } on DioException catch (e) {
      final msg = _extractServerError(e);
      if (mounted) setState(() => _error = msg);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ─── Helpers ───

  Future<File?> _pickImage() async {
    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return xf == null ? null : File(xf.path);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _shortError(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 117)}…' : s;
  }

  String _extractServerError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['message'] is String) return err['message'] as String;
      if (data['message'] is String) return data['message'] as String;
    }
    return 'Could not submit. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bioLength = _bioController.text.trim().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Profile' : 'Complete Your Profile'),
        // Onboarding locks the barber in until submit; editing allows back.
        automaticallyImplyLeading: _isEditMode,
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile photo ──
                  const _SectionHeader(
                    title: 'Profile Photo',
                    hint: 'This is what customers see in search and chat. Use a clear face photo, shoulders up.',
                  ),
                  const SizedBox(height: 10),
                  _ProfilePhotoPicker(
                    url: _profilePhoto,
                    uploading: _uploadingProfile,
                    onTap: _pickProfilePhoto,
                  ),
                  const SizedBox(height: 24),

                  // ── Portfolio ──
                  _SectionHeader(
                    title: 'Portfolio',
                    hint: 'Add $_minPortfolio–$_maxPortfolio haircut photos.',
                    trailing: '${_photos.length}/$_maxPortfolio',
                  ),
                  const SizedBox(height: 10),
                  _PortfolioGrid(
                    photos: _photos,
                    uploading: _uploadingPortfolio,
                    canAddMore: _photos.length < _maxPortfolio,
                    onAdd: _addPortfolio,
                    onRemove: _removePortfolio,
                  ),
                  const SizedBox(height: 24),

                  // ── Bio ──
                  _SectionHeader(
                    title: 'Short Bio',
                    hint: 'Tell customers a little about yourself.',
                    trailing: '$bioLength/$_maxBio',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: _maxBio,
                    onChanged: (_) => setState(() {}), // update counter
                    onEditingComplete: _saveBioQuiet,
                    onTapOutside: (_) => _saveBioQuiet(),
                    decoration: InputDecoration(
                      hintText: 'e.g. 10 years experience in fades and beard trims…',
                      helperText:
                          bioLength < _minBio ? 'At least $_minBio characters' : null,
                      counterText: '', // using the section trailing instead
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Postcode ──
                  const _SectionHeader(
                    title: 'Postcode',
                    hint: 'Used to match you with nearby customers.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _postcodeController,
                    textCapitalization: TextCapitalization.characters,
                    onEditingComplete: _savePostcodeQuiet,
                    onTapOutside: (_) => _savePostcodeQuiet(),
                    decoration: const InputDecoration(
                      hintText: 'e.g. SW1A 1AA',
                      prefixIcon: Icon(Icons.pin_drop_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Services ──
                  _SectionHeader(
                    title: 'Services & Prices',
                    hint: 'Add at least one service.',
                  ),
                  const SizedBox(height: 10),
                  _ServicesList(
                    services: _services,
                    onAdd: _addServiceDialog,
                    onRemove: _removeService,
                  ),
                  const SizedBox(height: 24),

                  // ── Settings ──
                  _SectionHeader(
                    title: 'Settings',
                    hint: 'Service area and booking notice.',
                  ),
                  const SizedBox(height: 10),
                  _SettingsBlock(
                    radiusMiles: _radiusMiles,
                    noticeHours: _noticeHours,
                    dirty: _settingsDirty,
                    saving: _savingSettings,
                    onRadiusChanged: (v) => setState(() => _radiusMiles = v),
                    onNoticeChanged: (v) => setState(() => _noticeHours = v),
                    onSave: _saveSettings,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Submit bar — only when approval is still pending. In edit
          // mode each section saves on its own so there's nothing to submit.
          if (!_isEditMode)
            Container(
              padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 12,
              ),
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
                  onPressed: (_canSubmit && !_submitting) ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit for Review'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Section header ───

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? hint;
  final String? trailing;

  const _SectionHeader({required this.title, this.hint, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ─── Settings block ───

class _SettingsBlock extends StatelessWidget {
  final double radiusMiles;
  final int noticeHours;
  final bool dirty;
  final bool saving;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<int> onNoticeChanged;
  final VoidCallback onSave;

  const _SettingsBlock({
    required this.radiusMiles,
    required this.noticeHours,
    required this.dirty,
    required this.saving,
    required this.onRadiusChanged,
    required this.onNoticeChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service radius — 0.5 to 20 miles, 0.5 step.
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Service radius',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${radiusMiles.toStringAsFixed(radiusMiles.truncateToDouble() == radiusMiles ? 0 : 1)} mi',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: radiusMiles.clamp(0.5, 20.0),
            min: 0.5,
            max: 20,
            divisions: 39, // (20 - 0.5) / 0.5
            label: '${radiusMiles.toStringAsFixed(1)} mi',
            onChanged: onRadiusChanged,
          ),

          const SizedBox(height: 8),
          // Minimum notice — hours, in stepper form.
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minimum booking notice',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'How far in advance customers must book.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _Stepper(
                value: noticeHours,
                min: 0,
                max: 72,
                suffix: noticeHours == 1 ? 'hour' : 'hours',
                onChanged: onNoticeChanged,
              ),
            ],
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: (dirty && !saving) ? onSave : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 40),
              ),
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

// ─── Profile photo picker ───

class _ProfilePhotoPicker extends StatelessWidget {
  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  const _ProfilePhotoPicker({
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: uploading ? null : onTap,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
                image: url != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(url!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: url == null
                  ? const Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 40,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: uploading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Portfolio grid ───

class _PortfolioGrid extends StatelessWidget {
  final List<Map<String, dynamic>> photos;
  final bool uploading;
  final bool canAddMore;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _PortfolioGrid({
    required this.photos,
    required this.uploading,
    required this.canAddMore,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...photos.map((p) => _PortfolioTile(
              url: p['url'] as String,
              onRemove: () => onRemove(p['id'] as String),
            )),
        if (canAddMore)
          GestureDetector(
            onTap: uploading ? null : onAdd,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: uploading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
      ],
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;

  const _PortfolioTile({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: CachedNetworkImageProvider(url),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Services list ───

class _ServicesList extends StatelessWidget {
  final List<Service> services;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _ServicesList({
    required this.services,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...services.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.durationMinutes} min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '£${s.priceInPounds.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      onPressed: () => onRemove(s.id),
                    ),
                  ],
                ),
              ),
            )),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Service'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ─── Add-service form sheet ───

class _ServiceFormResult {
  final String name;
  final int durationMinutes;
  final int priceInPounds;
  const _ServiceFormResult({
    required this.name,
    required this.durationMinutes,
    required this.priceInPounds,
  });
}

class _ServiceFormSheet extends StatefulWidget {
  const _ServiceFormSheet();

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ServiceFormResult(
        name: _nameController.text.trim(),
        durationMinutes: int.parse(_durationController.text.trim()),
        priceInPounds: int.parse(_priceController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom is the keyboard; padding.bottom is the gesture/nav
    // bar. Without summing both, the sheet's "Add" button gets covered by
    // the system nav on devices with a gesture bar.
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom + mq.padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Service name (e.g. Haircut)',
                prefixIcon: Icon(Icons.content_cut_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Duration',
                      suffixText: 'min',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Price',
                      prefixIcon: Icon(Icons.currency_pound_rounded),
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
