import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';

const int _kMaxReportImages = 5;
const int _kMaxImageBytes = 5 * 1024 * 1024;

/// Standalone "Report Issue" screen — used during the 24h hold window after
/// a booking starts. Unlike the review-screen report flow (post-completion),
/// this one offers a checkbox to request a refund. The server flags the
/// report with requestRefund=true so it bubbles up in the admin disputes
/// queue; the admin decides whether to issue the refund.
class ReportIssueScreen extends StatefulWidget {
  final String bookingId;
  final String barberName;

  const ReportIssueScreen({
    super.key,
    required this.bookingId,
    required this.barberName,
  });

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

const _categories = [
  'SERVICE_QUALITY',
  'PAYMENT',
  'BEHAVIOUR',
  'OTHER',
];
const _categoryLabels = {
  'SERVICE_QUALITY': 'Service quality',
  'PAYMENT': 'Payment issue',
  'BEHAVIOUR': 'Behaviour',
  'OTHER': 'Other',
};

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  String? _category;
  final _descController = TextEditingController();
  final _picker = ImagePicker();
  bool _requestRefund = false;
  bool _submitting = false;
  String? _error;
  bool _submitted = false;

  // Uploaded (not just picked) — each URL comes back from the upload
  // endpoint. Stored as strings so we can hand them straight to the
  // report creation call.
  final List<String> _imageUrls = [];
  bool _uploadingImage = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_imageUrls.length >= _kMaxReportImages) return;

    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);

    final xf = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (xf == null) return;
    final file = File(xf.path);
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _kMaxImageBytes) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Image is too large. Maximum 5 MB.'),
      ));
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final segs = file.path.split(RegExp(r'[\\/]'));
      final name = segs.isEmpty ? 'report' : segs.last;
      final url = await api.uploadReportImage(
        imageMultipartFromBytes(bytes, filename: name),
      );
      if (!mounted) return;
      setState(() => _imageUrls.add(url));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Could not upload photo. Try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _removeImage(int index) {
    // Only drops the reference client-side. The file stays on the
    // server's disk until the report is submitted (or forever if the
    // user closes the screen without submitting) — same liveness story
    // as other upload flows.
    setState(() => _imageUrls.removeAt(index));
  }

  Future<void> _submit() async {
    final desc = _descController.text.trim();
    if (_category == null) {
      setState(() => _error = 'Pick a category.');
      return;
    }
    if (desc.length < 10) {
      setState(() => _error = 'Please describe the issue (at least 10 characters).');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final api = context.read<ApiClient>();
    try {
      await api.submitReport(
        widget.bookingId,
        category: _category!,
        description: desc,
        requestRefund: _requestRefund,
        imageUrls: _imageUrls.isEmpty ? null : List<String>.from(_imageUrls),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _extractError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit. Please try again.';
      });
    }
  }

  String _extractError(DioException e) {
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
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
                const SizedBox(height: 16),
                const Text(
                  'Thanks for letting us know',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _requestRefund
                      ? 'Our team will review your request and respond within 24 hours.'
                      : 'Our team will review your report and follow up if needed.',
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell us what went wrong with ${widget.barberName}.',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Reports made during the 24-hour hold window are reviewed by our team.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final active = _category == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? AppColors.error : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active ? AppColors.error : AppColors.border,
                            ),
                          ),
                          child: Text(
                            _categoryLabels[cat] ?? cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: active ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'What happened?',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Photo evidence — up to 5. Each tap picks + uploads
                  // immediately so we can validate errors one at a time.
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Photos (optional)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${_imageUrls.length}/$_kMaxReportImages',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _imageUrls.length; i++)
                        _ThumbWithClose(
                          url: _imageUrls[i],
                          onRemove: () => _removeImage(i),
                        ),
                      if (_imageUrls.length < _kMaxReportImages)
                        GestureDetector(
                          onTap: _uploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border, width: 1.5),
                            ),
                            child: _uploadingImage
                                ? const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 24,
                                    color: AppColors.textSecondary,
                                  ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Refund request
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              const Text(
                                'Request a refund',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _requestRefund
                                    ? "Our team will review and respond within 24h."
                                    : "We'll just log the report.",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _requestRefund,
                          onChanged: (v) => setState(() => _requestRefund = v),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
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
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_requestRefund ? 'Submit & request refund' : 'Submit report'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbWithClose extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _ThumbWithClose({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.black,
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
