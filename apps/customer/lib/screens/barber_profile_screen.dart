import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import '../config/theme.dart';
import '../providers/barber_profile_provider.dart';
import '../providers/booking_provider.dart';

class BarberProfileScreen extends StatefulWidget {
  final String barberId;
  final String? barberName;
  final double? distanceKm;

  const BarberProfileScreen({
    super.key,
    required this.barberId,
    this.barberName,
    this.distanceKm,
  });

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarberProfileProvider>().loadBarber(widget.barberId);
    });
  }

  @override
  void dispose() {
    // Don't clear here — screen might be revisited from back stack
    super.dispose();
  }

  double? get _distanceMiles {
    final km = widget.distanceKm;
    return km != null ? km / 1.60934 : null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarberProfileProvider>();

    if (provider.isLoading && provider.profile == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null && provider.profile == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  provider.error!,
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadBarber(widget.barberId),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = provider.profile!;
    final services = provider.services;
    final reviews = provider.reviews;
    final userName = profile.user?.fullName ?? widget.barberName ?? 'Barber';
    final userPhoto = profile.user?.profilePhoto;
    final photos = profile.photos ?? [];
    final experienceLabel = _experienceLabel(profile.experience);

    // Use first portfolio photo as hero, or null
    final heroUrl = photos.isNotEmpty ? photos.first.url : null;

    // Avatar sizing: the visible circle (photo) is 2 * avatarRadius, plus the
    // white border ring (borderWidth) on each side. Total avatar footprint =
    // 2*(avatarRadius + borderWidth). Put the avatar's vertical centre on the
    // hero's bottom edge so it's half over the image, half hanging below.
    const avatarRadius = 46.0;
    const borderWidth = 4.0;
    const avatarDiameter = (avatarRadius + borderWidth) * 2; // 100
    const heroHeight = 250.0;
    // Vertical box for hero + room below for the hanging avatar + text row.
    // 116 fits name + rating + experience + distance (4 rows). It was 68
    // when there were only 3 rows; the experience row was added in M5
    // Bucket 2 and the bottom row was overlapping the "Photos" section
    // below until this was bumped.
    const headerBoxHeight = heroHeight + 116;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ─── Hero + avatar + text info (all inside ONE Stack so the
              // avatar is guaranteed to paint on top of the hero). ───
              SliverToBoxAdapter(
                child: SizedBox(
                  width: double.infinity,
                  height: headerBoxHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1) Hero image — painted first, sits underneath.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: heroHeight,
                        child: heroUrl != null
                            ? CachedNetworkImage(
                                imageUrl: heroUrl,
                                fit: BoxFit.cover,
                                color: Colors.black.withValues(alpha: 0.2),
                                colorBlendMode: BlendMode.darken,
                              )
                            : Container(
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.content_cut,
                                  size: 64,
                                  color: AppColors.border,
                                ),
                              ),
                      ),

                      // 2) Text column below the hero, on the LEFT. Right
                      //    padding keeps it out from under the avatar.
                      Positioned(
                        top: heroHeight + 8,
                        left: 20,
                        right: 20 + avatarDiameter + 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (profile.rating != null &&
                                    profile.rating! > 0) ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: Color(0xFFFFC107),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    profile.rating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (profile.reviewCount != null)
                                    Text(
                                      ' (${profile.reviewCount} reviews)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                            if (experienceLabel != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_outlined,
                                      size: 15,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      experienceLabel,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_distanceMiles != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 15,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${_distanceMiles!.toStringAsFixed(1)} miles away',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 3) Avatar — painted LAST so it sits on top of the
                      //    hero image. Centre on hero's bottom edge:
                      //    top = heroHeight - avatarDiameter/2.
                      Positioned(
                        top: heroHeight - avatarDiameter / 2,
                        right: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: borderWidth,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          // Original CircleAvatar pattern — the
                          // ClipOval(CachedNetworkImage) variant that was
                          // tried in the HEIC turn caused a regression on
                          // working images on Android. Decode errors
                          // (legacy HEIC) are now handled server-side by
                          // the on-serve sharp transcode, so the avatar
                          // doesn't need its own errorWidget.
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: AppColors.surface,
                            backgroundImage: userPhoto != null
                                ? CachedNetworkImageProvider(userPhoto)
                                : null,
                            child: userPhoto == null
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Portfolio photos ───
              if (photos.length > 1)
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Photos',
                    child: SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: photos[index].url,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 110,
                                height: 110,
                                color: AppColors.surface,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // ─── Services ───
              if (services.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Services',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: services.map((s) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${s.durationMinutes} min',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\u00A3${s.priceInPounds.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

              // ─── Reviews ───
              SliverToBoxAdapter(
                child: _Section(
                  title: reviews.isNotEmpty
                      ? 'Reviews (${reviews.length})'
                      : 'Reviews',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: reviews.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: const Text(
                              'No reviews yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : Column(
                            children: reviews
                                .take(5)
                                .map((r) => _ReviewCard(review: r))
                                .toList(),
                          ),
                  ),
                ),
              ),

              // Bottom padding for the sticky button:
              //   button height (~48) + top pad (12) + bottom pad (12) + safe-area
              //   + small breathing room so the last item isn't flush against it.
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 96,
                ),
              ),
            ],
          ),

          // ─── Pinned back button (always on top of the scrollview) ───
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _CircleBackButton(),
          ),

          // ─── Sticky Book Now button ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
              child: ElevatedButton.icon(
                onPressed: () {
                  final bp = context.read<BarberProfileProvider>();
                  context.read<BookingProvider>().startBooking(
                    bp.profile!.id,
                    bp.profile!.user?.fullName ?? 'Barber',
                  );
                  Navigator.pushNamed(context, '/booking');
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: const Text('Book Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CircleAvatar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Formats the barber's stored experience for display. The value is a
/// whole number of years stored as a string (e.g. "5"); fall back to the
/// raw text for any legacy free-form value, and null when unset.
String? _experienceLabel(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return null;
  final years = int.tryParse(v);
  if (years != null && years >= 1) {
    return years == 1 ? '1 year experience' : '$years years experience';
  }
  return v;
}

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name = review.customer?.fullName ?? 'Customer';
    final daysAgo = DateTime.now().difference(review.createdAt).inDays;
    final timeAgo = daysAgo == 0
        ? 'Today'
        : daysAgo == 1
            ? 'Yesterday'
            : '$daysAgo days ago';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Star rating
                ...List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: i < review.rating ? const Color(0xFFFFC107) : AppColors.border,
                  );
                }),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"${review.comment!}"',
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '$name · $timeAgo',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
