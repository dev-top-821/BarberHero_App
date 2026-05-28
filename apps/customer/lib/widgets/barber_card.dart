import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_models/shared_models.dart';
import '../config/theme.dart';

class BarberCard extends StatelessWidget {
  final NearbyBarber barber;
  final VoidCallback? onTap;

  const BarberCard({super.key, required this.barber, this.onTap});

  @override
  Widget build(BuildContext context) {
    final distanceMiles = barber.distanceKm != null
        ? (barber.distanceKm! / 1.60934)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile photo
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.surface,
              backgroundImage: barber.profilePhoto != null
                  ? CachedNetworkImageProvider(barber.profilePhoto!)
                  : null,
              child: barber.profilePhoto == null
                  ? Text(
                      barber.fullName.isNotEmpty ? barber.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    barber.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (barber.rating != null) ...[
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text(
                          barber.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        if (barber.reviewCount != null)
                          Text(
                            ' (${barber.reviewCount})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                      ],
                      if (barber.rating != null && distanceMiles != null)
                        const Text(
                          '  ·  ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      if (distanceMiles != null)
                        Text(
                          '${distanceMiles.toStringAsFixed(1)} mi',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Starting price
            if (barber.startingPriceInPence != null)
              Text(
                'From £${(barber.startingPriceInPence! / 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
