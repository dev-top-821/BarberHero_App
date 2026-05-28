import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import '../../config/theme.dart';
import '../../config/env.dart';
import '../../providers/location_provider.dart';
import '../../providers/barber_provider.dart';
import '../../widgets/barber_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  static String get _mapTilerKey => Env.mapTilerKey;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBarbers());
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _loadBarbers() {
    final location = context.read<LocationProvider>();
    if (location.hasLocation) {
      context.read<BarberProvider>().fetchNearbyBarbers(
        latitude: location.latitude!,
        longitude: location.longitude!,
      );
    }
  }

  void _recenter() {
    final location = context.read<LocationProvider>();
    if (location.hasLocation) {
      _mapController.move(
        LatLng(location.latitude!, location.longitude!),
        14.0,
      );
    }
  }

  void _onBarberTap(NearbyBarber barber) {
    Navigator.pushNamed(context, '/barber', arguments: {
      'barberId': barber.id,
      'barberName': barber.fullName,
      'distanceKm': barber.distanceKm,
    });
  }

  void _onMarkerTap(NearbyBarber barber) {
    _onBarberTap(barber);
    // Expand bottom sheet slightly to show the list
    _sheetController.animateTo(
      0.4,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final barberProvider = context.watch<BarberProvider>();

    final userLatLng = location.hasLocation
        ? LatLng(location.latitude!, location.longitude!)
        : const LatLng(51.5074, -0.1278); // London fallback

    return Stack(
      children: [
        // ─── Map ───
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 14.0,
            minZoom: 10,
            maxZoom: 18,
          ),
          children: [
            // MapTiler tile layer
            TileLayer(
              urlTemplate: _mapTilerKey.isNotEmpty
                  ? 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}@2x.png?key=$_mapTilerKey'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.barberhero.customer',
              maxZoom: 18,
              tileDimension: 512,
              zoomOffset: _mapTilerKey.isNotEmpty ? -1 : 0,
            ),

            // User location blue dot
            CurrentLocationLayer(
              style: const LocationMarkerStyle(
                markerSize: Size(20, 20),
                accuracyCircleColor: Color(0x182196F3),
                headingSectorColor: Color(0x802196F3),
                marker: DefaultLocationMarker(color: Color(0xFF2196F3)),
              ),
            ),

            // Barber markers
            MarkerLayer(
              markers: barberProvider.nearbyBarbers
                  .where((b) => b.latitude != null && b.longitude != null)
                  .map((barber) => Marker(
                        point: LatLng(barber.latitude!, barber.longitude!),
                        width: 26,
                        height: 32,
                        // Anchor the tip of the teardrop on the coordinate.
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () => _onMarkerTap(barber),
                          child: _BarberMarker(barber: barber),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),

        // ─── Search bar (top) ───
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/search'),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text(
                    'Search services...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ─── Re-center button (top-right, below the search bar) ───
        Positioned(
          top: MediaQuery.of(context).padding.top + 64,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            onPressed: _recenter,
            child: const Icon(Icons.my_location_rounded, size: 20),
          ),
        ),

        // ─── Bottom sheet ───
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.25,
          minChildSize: 0.08,
          maxChildSize: 0.7,
          snap: true,
          snapSizes: const [0.08, 0.25, 0.7],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (_) {},
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Nearby Barbers',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (barberProvider.isLoading)
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (!barberProvider.isLoading)
                          Text(
                            '${barberProvider.nearbyBarbers.length} found',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Barber list
                  Expanded(
                    child: barberProvider.nearbyBarbers.isEmpty && !barberProvider.isLoading
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.content_cut, size: 40, color: AppColors.border),
                                  const SizedBox(height: 12),
                                  Text(
                                    barberProvider.error ?? 'No barbers found nearby',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: barberProvider.nearbyBarbers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final barber = barberProvider.nearbyBarbers[index];
                              return BarberCard(
                                barber: barber,
                                onTap: () => _onBarberTap(barber),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Teardrop map pin: single continuous path (no seam) with a sharp tip at
/// the bottom that lands exactly on the anchor point. Photo sits on top of
/// the head via a Stack.
class _BarberMarker extends StatelessWidget {
  final NearbyBarber barber;

  const _BarberMarker({required this.barber});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 32,
      child: Stack(
        children: [
          // Teardrop silhouette (red fill + drop shadow).
          Positioned.fill(
            child: CustomPaint(
              painter: _PinShapePainter(color: AppColors.primary),
            ),
          ),
          // Photo disc inset inside the head — 3 px red ring visible around it.
          Positioned(
            top: 3,
            left: 3,
            child: ClipOval(
              child: Container(
                width: 20,
                height: 20,
                color: Colors.white,
                alignment: Alignment.center,
                child: barber.profilePhoto != null
                    ? CachedNetworkImage(
                        imageUrl: barber.profilePhoto!,
                        fit: BoxFit.cover,
                        width: 20,
                        height: 20,
                        placeholder: (_, __) => _initials(),
                        errorWidget: (_, __, ___) => _initials(),
                      )
                    : _initials(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() {
    return Text(
      barber.fullName.isNotEmpty ? barber.fullName[0].toUpperCase() : '?',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Paints a classic map-pin teardrop:
///   - Circular head at the top (fills the widget's width as diameter).
///   - Tail wedges emerging from inside the circle's bottom arc, meeting at
///     a sharp point at the bottom-center.
/// Assumes size.width is the head diameter and size.height = width + tailLength.
class _PinShapePainter extends CustomPainter {
  final Color color;
  _PinShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final headRadius = w / 2;
    final headCenter = Offset(w / 2, headRadius);

    // Angle at which the tail detaches from the circle (measured from centre,
    // down from 3 o'clock). 50° gives a clean merge — wider than a cone, so
    // no visible seam between head and tail.
    final detachRad = 50.0 * math.pi / 180.0;
    final junctionY = headRadius + headRadius * math.sin(detachRad);
    final junctionDx = headRadius * math.cos(detachRad);
    final leftJunction = Offset(w / 2 - junctionDx, junctionY);
    final rightJunction = Offset(w / 2 + junctionDx, junctionY);

    final path = ui.Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius))
      ..moveTo(leftJunction.dx, leftJunction.dy)
      ..lineTo(w / 2, h)
      ..lineTo(rightJunction.dx, rightJunction.dy)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 3, false);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _PinShapePainter oldDelegate) =>
      oldDelegate.color != color;
}
