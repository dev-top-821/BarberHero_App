import 'package:flutter/material.dart';
import 'package:api_client/api_client.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';

const _reportCategories = [
  'SERVICE_QUALITY',
  'NO_SHOW',
  'PAYMENT',
  'BEHAVIOUR',
  'OTHER',
];

const _categoryLabels = {
  'SERVICE_QUALITY': 'Service Quality',
  'NO_SHOW': 'Barber No-Show',
  'PAYMENT': 'Payment Issue',
  'BEHAVIOUR': 'Behaviour',
  'OTHER': 'Other',
};

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  final String barberName;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.barberName,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _showReport = false;
  String? _reportCategory;
  final _reportDescController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _commentController.dispose();
    _reportDescController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a rating.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final api = context.read<ApiClient>();

    try {
      // Submit review
      await api.submitReview(
        widget.bookingId,
        rating: _rating,
        comment: _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
      );

      // Submit report if filled
      if (_showReport &&
          _reportCategory != null &&
          _reportDescController.text.trim().isNotEmpty) {
        await api.submitReport(
          widget.bookingId,
          category: _reportCategory!,
          description: _reportDescController.text.trim(),
        );
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        if (e is DioException && e.response?.data is Map) {
          _error = (e.response!.data as Map)['message'] as String? ??
              'Could not submit. Please try again.';
        } else {
          _error = 'Could not submit. Please try again.';
        }
      });
    }
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
                  'Thank you!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your feedback has been submitted.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barber name
                  Text(
                    'How was your experience with ${widget.barberName}?',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),

                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = star),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40,
                            color: star <= _rating ? const Color(0xFFFFC107) : AppColors.border,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Comment
                  TextFormField(
                    controller: _commentController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment (optional)',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Report toggle
                  GestureDetector(
                    onTap: () => setState(() => _showReport = !_showReport),
                    child: Row(
                      children: [
                        Icon(
                          _showReport ? Icons.flag_rounded : Icons.flag_outlined,
                          size: 20,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showReport ? 'Cancel report' : 'Report an issue',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Report form
                  if (_showReport) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'What went wrong?',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),

                    // Category chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reportCategories.map((cat) {
                        final isActive = _reportCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _reportCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.error : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive ? AppColors.error : AppColors.border,
                              ),
                            ),
                            child: Text(
                              _categoryLabels[cat] ?? cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isActive ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _reportDescController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Describe the issue...',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Photo upload hint
                    Row(
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        const Text(
                          'Photo upload coming soon',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],

                  // Error
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

          // Submit button
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
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
