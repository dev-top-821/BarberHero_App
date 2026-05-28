import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import '../config/theme.dart';
import '../providers/barber_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/barber_card.dart';

/// Common service types for filter chips (MVP hardcoded — no global services endpoint).
const _serviceFilters = [
  'Haircut',
  'Fade',
  'Beard Trim',
  'Skin Fade',
  'Buzz Cut',
  'Line Up',
  'Hot Towel Shave',
  'Kids Cut',
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedService;

  // Filter state — distance goes to the server; rating/price filter the
  // returned list client-side.
  double _radiusMiles = 10;
  double _minRating = 0;
  int? _maxPriceInPence; // null = no cap

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    // Load initial results (all nearby barbers)
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search({String? service}) {
    final location = context.read<LocationProvider>();
    if (!location.hasLocation) return;

    context.read<BarberProvider>().searchBarbers(
      latitude: location.latitude!,
      longitude: location.longitude!,
      radiusMiles: _radiusMiles,
      service: service ?? _selectedService,
    );
  }

  void _onServiceChipTap(String service) {
    setState(() {
      if (_selectedService == service) {
        _selectedService = null;
      } else {
        _selectedService = service;
      }
    });
    _search(service: _selectedService);
  }

  /// Count of non-default filters — drives the badge on the filter icon.
  int get _activeFilterCount {
    var n = 0;
    if (_radiusMiles != 10) n++;
    if (_minRating > 0) n++;
    if (_maxPriceInPence != null) n++;
    return n;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilterSheet(
        initialRadiusMiles: _radiusMiles,
        initialMinRating: _minRating,
        initialMaxPriceInPence: _maxPriceInPence,
      ),
    );
    if (result == null) return;
    final radiusChanged = result.radiusMiles != _radiusMiles;
    setState(() {
      _radiusMiles = result.radiusMiles;
      _minRating = result.minRating;
      _maxPriceInPence = result.maxPriceInPence;
    });
    // Radius is a server param so re-run the query; rating/price filter
    // locally and don't need another round-trip.
    if (radiusChanged) _search();
  }

  /// Applies client-side rating + price filters on top of the server result.
  List<NearbyBarber> _applyLocalFilters(List<NearbyBarber> list) {
    return list.where((b) {
      if (_minRating > 0 && (b.rating ?? 0) < _minRating) return false;
      if (_maxPriceInPence != null &&
          b.startingPriceInPence != null &&
          b.startingPriceInPence! > _maxPriceInPence!) {
        return false;
      }
      return true;
    }).toList();
  }

  void _onBarberTap(NearbyBarber barber) {
    Navigator.pushNamed(context, '/barber', arguments: {
      'barberId': barber.id,
      'barberName': barber.fullName,
      'distanceKm': barber.distanceKm,
    });
  }

  @override
  Widget build(BuildContext context) {
    final barberProvider = context.watch<BarberProvider>();
    final query = _searchController.text.trim();
    final rawResults = query.isNotEmpty
        ? barberProvider.filterByName(query)
        : barberProvider.searchResults;
    final results = _applyLocalFilters(rawResults);
    final filterCount = _activeFilterCount;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top bar ───
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      barberProvider.clearSearch();
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search barbers or services...',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  // Filter icon with an active-count badge when any
                  // non-default filter is applied.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'Filters',
                        onPressed: _openFilterSheet,
                      ),
                      if (filterCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            child: Text(
                              '$filterCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Service filter chips ───
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _serviceFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final service = _serviceFilters[index];
                  final isActive = _selectedService == service;

                  return GestureDetector(
                    onTap: () => _onServiceChipTap(service),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isActive ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        service,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // ─── Results ───
            Expanded(
              child: barberProvider.isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: AppColors.border),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedService != null
                                      ? 'No barbers found for "$_selectedService" nearby'
                                      : 'No barbers found nearby',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final barber = results[index];
                            return BarberCard(
                              barber: barber,
                              onTap: () => _onBarberTap(barber),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter sheet ───

class _FilterResult {
  final double radiusMiles;
  final double minRating;
  final int? maxPriceInPence;
  const _FilterResult({
    required this.radiusMiles,
    required this.minRating,
    required this.maxPriceInPence,
  });
}

class _FilterSheet extends StatefulWidget {
  final double initialRadiusMiles;
  final double initialMinRating;
  final int? initialMaxPriceInPence;

  const _FilterSheet({
    required this.initialRadiusMiles,
    required this.initialMinRating,
    required this.initialMaxPriceInPence,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late double _radius = widget.initialRadiusMiles;
  late double _minRating = widget.initialMinRating;
  late int? _maxPrice = widget.initialMaxPriceInPence;

  // Price bucket options — null = Any, then £20/£40/£60/£100.
  static const _priceBuckets = <({String label, int? pence})>[
    (label: 'Any', pence: null),
    (label: 'Up to £20', pence: 2000),
    (label: 'Up to £40', pence: 4000),
    (label: 'Up to £60', pence: 6000),
    (label: 'Up to £100', pence: 10000),
  ];

  // Rating options — 0 = Any, then 3, 3.5, 4, 4.5 stars.
  static const _ratingBuckets = <({String label, double value})>[
    (label: 'Any', value: 0),
    (label: '3+ ★', value: 3),
    (label: '3.5+ ★', value: 3.5),
    (label: '4+ ★', value: 4),
    (label: '4.5+ ★', value: 4.5),
  ];

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom is the keyboard; padding.bottom is the gesture/nav
    // bar. Without summing both, sheet buttons get covered on gesture-bar
    // devices.
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _radius = 10;
                    _minRating = 0;
                    _maxPrice = null;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Distance
          _Label(text: 'Distance', value: '${_radius.toStringAsFixed(_radius.truncateToDouble() == _radius ? 0 : 1)} mi'),
          Slider(
            value: _radius.clamp(1, 25),
            min: 1,
            max: 25,
            divisions: 24,
            label: '${_radius.toStringAsFixed(1)} mi',
            onChanged: (v) => setState(() => _radius = v),
          ),
          const SizedBox(height: 12),

          // Min rating
          const _Label(text: 'Minimum rating'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _ratingBuckets.map((b) {
              final active = _minRating == b.value;
              return ChoiceChip(
                label: Text(b.label),
                selected: active,
                onSelected: (_) => setState(() => _minRating = b.value),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Max starting price
          const _Label(text: 'Starting price'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _priceBuckets.map((b) {
              final active = _maxPrice == b.pence;
              return ChoiceChip(
                label: Text(b.label),
                selected: active,
                onSelected: (_) => setState(() => _maxPrice = b.pence),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _FilterResult(
                    radiusMiles: _radius,
                    minRating: _minRating,
                    maxPriceInPence: _maxPrice,
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? value;
  const _Label({required this.text, this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        if (value != null)
          Text(
            value!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}
