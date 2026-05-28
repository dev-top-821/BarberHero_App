import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';

const int _kMaxUploadBytes = 5 * 1024 * 1024;

/// Customer edit profile — name, phone, avatar. Name and phone save via
/// PATCH /users/me on "Save"; avatar uploads directly to Firebase Storage
/// via a signed URL, then PATCH /users/me records the public download URL.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();

  String? _profilePhotoUrl;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController.text = user?.fullName ?? '';
    _phoneController.text = user?.phone ?? '';
    _profilePhotoUrl = user?.profilePhoto;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    // Capture provider refs before awaits to avoid using context after
    // an async gap if the widget unmounts.
    final api = context.read<ApiClient>();
    final auth = context.read<AuthProvider>();

    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (xf == null) return;
    final file = File(xf.path);
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _kMaxUploadBytes) {
      _snack('Image is too large. Maximum 5 MB.');
      return;
    }

    setState(() => _uploadingPhoto = true);
    try {
      // Single multipart round-trip: server saves to the photos disk and
      // returns the public URL already persisted on User.profilePhoto.
      final segs = file.path.split(RegExp(r'[\\/]'));
      final name = segs.isEmpty ? 'avatar' : segs.last;
      final url = await api.uploadUserPhoto(
        imageMultipartFromBytes(bytes, filename: name),
      );
      if (!mounted) return;
      setState(() => _profilePhotoUrl = url);
      // Keep the AuthProvider in sync so the profile tab re-renders with
      // the new avatar on the next frame.
      await auth.refreshUser();
    } catch (_) {
      if (mounted) _snack('Could not upload photo. Try again.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = context.read<ApiClient>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await api.updateMe(
        fullName: _nameController.text.trim(),
        // Empty string clears the phone on the server.
        phone: _phoneController.text.trim(),
      );
      await auth.refreshUser();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved.')));
      Navigator.pop(context);
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] is Map &&
              (data['error'] as Map)['message'] is String)
          ? (data['error'] as Map)['message'] as String
          : 'Could not save. Please try again.';
      if (mounted) setState(() => _error = msg);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar picker — tap to replace.
                    Center(
                      child: GestureDetector(
                        onTap: _uploadingPhoto ? null : _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border, width: 1.5),
                                image: _profilePhotoUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(_profilePhotoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _profilePhotoUrl == null
                                  ? const Icon(
                                      Icons.person_outline_rounded,
                                      size: 44,
                                      color: AppColors.textSecondary,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: _uploadingPhoto
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
                                        size: 16,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Full name
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Phone (optional)
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Phone (optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

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
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
