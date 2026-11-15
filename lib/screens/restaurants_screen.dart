import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/localization/app_localizations.dart';
import '../core/restaurant_categories.dart';
import '../services/favorite_business_service.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/global_bottom_nav.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  static const int _kPageSize = 30;

  bool _isFrench = false;
  bool _loading = true;
  String? _error;
  String _search = '';
  String _selectedCategory = 'all';
  double _maxDistanceKm = 50;
  bool _onlyFavorites = false;
  bool _isGridView = true;
  final _searchCtrl = TextEditingController();

  late final FavoriteBusinessService _favService;
  Set<String> _favoriteIds = {};

  double? _meLat;
  double? _meLng;

  // Raw server rows, accumulated across pages
  List<Map<String, dynamic>> _rawRows = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  late final ScrollController _scrollCtrl;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _favService = FavoriteBusinessService(Supabase.instance.client);
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earth = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earth * c;
  }

  double _toRad(double d) => d * math.pi / 180;

  /// Apply client-side category/search/distance filters and sort by distance.
  List<Map<String, dynamic>> get _filteredRestaurants {
    var items = List<Map<String, dynamic>>.from(_rawRows);

    if (_selectedCategory != 'all') {
      items = items
          .where((r) => (r['restaurant_type'] ?? '').toString() == _selectedCategory)
          .toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase().trim();
      items = items.where((r) {
        return (r['business_name'] ?? '').toString().toLowerCase().contains(q) ||
            (r['full_name'] ?? '').toString().toLowerCase().contains(q) ||
            (r['bio'] ?? '').toString().toLowerCase().contains(q) ||
            (r['business_profile'] ?? '').toString().toLowerCase().contains(q) ||
            (r['city'] ?? '').toString().toLowerCase().contains(q) ||
            restaurantCategoryLabel((r['restaurant_type'] ?? '').toString(), isFrench: _isFrench)
                .toLowerCase()
                .contains(q);
      }).toList();
    }

    if (_meLat != null && _meLng != null) {
      if (_maxDistanceKm < 100) {
        items = items.where((r) {
          final lat = (r['latitude'] as num?)?.toDouble();
          final lng = (r['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) return false;
          return _distanceKm(_meLat!, _meLng!, lat, lng) <= _maxDistanceKm;
        }).toList();
      }

      items.sort((a, b) {
        final aLat = (a['latitude'] as num?)?.toDouble();
        final aLng = (a['longitude'] as num?)?.toDouble();
        final bLat = (b['latitude'] as num?)?.toDouble();
        final bLng = (b['longitude'] as num?)?.toDouble();
        final ad = (aLat != null && aLng != null)
            ? _distanceKm(_meLat!, _meLng!, aLat, aLng)
            : 9999.0;
        final bd = (bLat != null && bLng != null)
            ? _distanceKm(_meLat!, _meLng!, bLat, bLng)
            : 9999.0;
        return ad.compareTo(bd);
      });
    }

    if (_onlyFavorites) {
      items = items
          .where((r) => _favoriteIds.contains((r['id'] ?? '').toString()))
          .toList();
    }

    return items;
  }

  Future<void> _toggleFavorite(String businessId) async {
    final l10n = context.l10n;
    final wasFav = _favoriteIds.contains(businessId);
    setState(() {
      if (wasFav) {
        _favoriteIds.remove(businessId);
      } else {
        _favoriteIds.add(businessId);
      }
    });

    try {
      if (wasFav) {
        await _favService.removeFavorite(businessId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('business_unfavorited')),
            action: SnackBarAction(
              label: l10n.tr('undo'),
              onPressed: () => _toggleFavorite(businessId),
            ),
          ),
        );
      } else {
        await _favService.addFavorite(businessId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tr('business_favorited'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasFav) {
          _favoriteIds.add(businessId);
        } else {
          _favoriteIds.remove(businessId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rawRows = [];
      _page = 0;
      _hasMore = true;
    });

    try {
      final db = Supabase.instance.client;
      final me = db.auth.currentUser;

      if (me != null) {
        final myProfile = await db
            .from('profiles')
            .select('latitude, longitude')
            .eq('id', me.id)
            .maybeSingle();
        _meLat = (myProfile?['latitude'] as num?)?.toDouble();
        _meLng = (myProfile?['longitude'] as num?)?.toDouble();
      }

      // Default to launch hub (Ris-Orangis, Essonne) if user location is unavailable
      _meLat ??= 48.6508;
      _meLng ??= 2.4143;

      List<Map<String, dynamic>> rows;
      try {
        final data = await db
            .from('profiles')
            .select('id, full_name, bio, business_profile, avatar_url, city, latitude, longitude, is_restaurant, restaurant_type, account_type, business_name, job_title, is_disabled, is_unclaimed, siret, phone, website')
            .eq('is_restaurant', true)
            .eq('is_disabled', false)
            .order('business_name')
            .range(0, _kPageSize - 1);
        rows = (data as List).cast<Map<String, dynamic>>();
      } on PostgrestException {
        final data = await db
            .from('profiles')
            .select('id, full_name, bio, business_profile, avatar_url, city, latitude, longitude, account_type, business_name, job_title, is_disabled, is_unclaimed, siret, phone, website')
            .eq('account_type', 'business')
            .order('business_name')
            .range(0, _kPageSize - 1);
        rows = (data as List)
            .cast<Map<String, dynamic>>()
            .where((r) => r['is_disabled'] != true)
            .toList();
      }

      final ids = rows
          .map((r) => (r['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      final favIds = await _favService.fetchFavoriteIds(ids);

      if (!mounted) return;
      setState(() {
        _rawRows = rows;
        _favoriteIds = favIds;
        _page = 1;
        _hasMore = rows.length == _kPageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final db = Supabase.instance.client;
      final from = _page * _kPageSize;
      final to = from + _kPageSize - 1;

      List<Map<String, dynamic>> rows;
      try {
        final data = await db
            .from('profiles')
            .select('id, full_name, bio, business_profile, avatar_url, city, latitude, longitude, is_restaurant, restaurant_type, account_type, business_name, job_title, is_disabled, is_unclaimed, siret, phone, website')
            .eq('is_restaurant', true)
            .eq('is_disabled', false)
            .order('business_name')
            .range(from, to);
        rows = (data as List).cast<Map<String, dynamic>>();
      } on PostgrestException {
        final data = await db
            .from('profiles')
            .select('id, full_name, bio, business_profile, avatar_url, city, latitude, longitude, account_type, business_name, job_title, is_disabled, is_unclaimed, siret, phone, website')
            .eq('account_type', 'business')
            .order('business_name')
            .range(from, to);
        rows = (data as List)
            .cast<Map<String, dynamic>>()
            .where((r) => r['is_disabled'] != true)
            .toList();
      }

      final ids = rows
          .map((r) => (r['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
      final favIds = await _favService.fetchFavoriteIds(ids);

      if (!mounted) return;
      setState(() {
        _rawRows = [..._rawRows, ...rows];
        _favoriteIds.addAll(favIds);
        _page++;
        _hasMore = rows.length == _kPageSize;
      });
    } catch (_) {
      // silently ignore load-more errors
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    _isFrench = l10n.isFrench;
    final restaurants = _filteredRestaurants;

    return Scaffold(
      appBar: GlobalAppBar(
        title: l10n.tr('restaurants'),
        showBackIfPossible: true,
        homeRoute: '/feed',
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Column(
        children: [
          // Sleek Search & Controls Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.tr('search_restaurants'),
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                  _load();
                                },
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (v) {
                        setState(() => _search = v);
                        _load();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openFilterModal(context),
                  borderRadius: BorderRadius.circular(21),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: (_maxDistanceKm < 50 || _onlyFavorites)
                          ? const Color(0xFF0F766E).withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: (_maxDistanceKm < 50 || _onlyFavorites)
                            ? const Color(0xFF0F766E)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 18,
                          color: (_maxDistanceKm < 50 || _onlyFavorites)
                              ? const Color(0xFF0F766E)
                              : Colors.grey.shade700,
                        ),
                        if (_maxDistanceKm < 50 || _onlyFavorites) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${_maxDistanceKm.toInt()}km',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: _isGridView ? 'Mode Liste' : 'Mode Grille',
                  icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                  color: const Color(0xFF0F766E),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ),
          // Horizontal Category Pills
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildCategoryChip('all', l10n.tr('all_categories')),
                ...restaurantMainCategories.map(
                  (c) => _buildCategoryChip(c, restaurantCategoryLabel(c, isFrench: _isFrench)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          // Discovery Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(l10n.tr('error_with_detail', args: {'error': '$_error'})))
                    : restaurants.isEmpty
                        ? Center(child: Text(l10n.tr('no_restaurants_found')))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _isGridView
                                ? GridView.builder(
                                    controller: _scrollCtrl,
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: MediaQuery.of(context).size.width >= 1000
                                          ? 4
                                          : MediaQuery.of(context).size.width >= 650
                                              ? 3
                                              : 2,
                                      childAspectRatio: 0.82,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemCount: restaurants.length + (_loadingMore || _hasMore ? 1 : 0),
                                    itemBuilder: (context, i) {
                                      if (i >= restaurants.length) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      final r = restaurants[i];
                                      final lat = (r['latitude'] as num?)?.toDouble();
                                      final lng = (r['longitude'] as num?)?.toDouble();
                                      final dist = (_meLat != null && _meLng != null && lat != null && lng != null)
                                          ? _distanceKm(_meLat!, _meLng!, lat, lng)
                                          : null;
                                      return _buildRestaurantGridCard(r, dist, l10n);
                                    },
                                  )
                                : ListView.builder(
                                    controller: _scrollCtrl,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    itemCount: restaurants.length + (_loadingMore || _hasMore ? 1 : 0),
                                    itemBuilder: (context, i) {
                                      if (i >= restaurants.length) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                      final r = restaurants[i];
                                      final lat = (r['latitude'] as num?)?.toDouble();
                                      final lng = (r['longitude'] as num?)?.toDouble();
                                      final dist = (_meLat != null && _meLng != null && lat != null && lng != null)
                                          ? _distanceKm(_meLat!, _meLng!, lat, lng)
                                          : null;
                                      return _buildRestaurantListCard(r, dist, l10n);
                                    },
                                  ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF374151),
        ),
        backgroundColor: Colors.grey.shade100,
        selectedColor: const Color(0xFF0F766E),
        checkmarkColor: Colors.white,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade300,
          ),
        ),
        onSelected: (_) {
          setState(() => _selectedCategory = categoryKey);
          _load();
        },
      ),
    );
  }

  void _openFilterModal(BuildContext context) {
    final l10n = context.l10n;
    double tempDist = _maxDistanceKm;
    bool tempFav = _onlyFavorites;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('filters'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempDist = 50;
                              tempFav = false;
                            });
                          },
                          child: Text(l10n.tr('reset')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('distance_label'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          tempDist >= 100
                              ? '100+ km (Tous)'
                              : '${tempDist.toStringAsFixed(0)} km',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
                        ),
                      ],
                    ),
                    Slider(
                      value: tempDist,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      activeColor: const Color(0xFF0F766E),
                      label: tempDist >= 100 ? '100+ km' : '${tempDist.toStringAsFixed(0)} km',
                      onChanged: (v) => setModalState(() => tempDist = v),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.tr('favorites_only')),
                      value: tempFav,
                      activeColor: const Color(0xFF0F766E),
                      onChanged: (v) => setModalState(() => tempFav = v ?? false),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _maxDistanceKm = tempDist;
                            _onlyFavorites = tempFav;
                          });
                          _load();
                        },
                        child: Text(l10n.tr('apply')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRestaurantGridCard(Map<String, dynamic> r, double? dist, AppLocalizations l10n) {
    final id = (r['id'] ?? '').toString();
    final bName = (r['business_name'] as String?) ?? (r['full_name'] as String?) ?? l10n.tr('restaurant');
    final avatarUrl = (r['avatar_url'] ?? '').toString();
    final categoryStr = (r['restaurant_type'] ?? '').toString();
    final categoryLabel = categoryStr.isNotEmpty
        ? restaurantCategoryLabel(categoryStr, isFrench: _isFrench)
        : l10n.tr('restaurant');
    final isUnclaimed = r['is_unclaimed'] == true;
    final isFav = _favoriteIds.contains(id);

    return Card(
      elevation: 0.8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: id.isEmpty ? null : () => context.push('/p/$id'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholderBanner(categoryStr),
                        )
                      : _buildPlaceholderBanner(categoryStr),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        categoryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (dist != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${dist.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          (r['city'] ?? 'Ris-Orangis').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isUnclaimed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDBA74)),
                          ),
                          child: Text(
                            l10n.tr('unclaimed_business_badge'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.verified, color: Colors.green, size: 16),
                      InkWell(
                        onTap: id.isEmpty ? null : () => _toggleFavorite(id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFav ? Colors.red : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantListCard(Map<String, dynamic> r, double? dist, AppLocalizations l10n) {
    final id = (r['id'] ?? '').toString();
    final bName = (r['business_name'] as String?) ?? (r['full_name'] as String?) ?? l10n.tr('restaurant');
    final avatarUrl = (r['avatar_url'] ?? '').toString();
    final categoryStr = (r['restaurant_type'] ?? '').toString();
    final categoryLabel = categoryStr.isNotEmpty
        ? restaurantCategoryLabel(categoryStr, isFrench: _isFrench)
        : l10n.tr('restaurant');
    final isUnclaimed = r['is_unclaimed'] == true;
    final isFav = _favoriteIds.contains(id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: id.isEmpty ? null : () => context.push('/p/$id'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholderBanner(categoryStr),
                        )
                      : _buildPlaceholderBanner(categoryStr),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnclaimed)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDBA74)),
                            ),
                            child: Text(
                              l10n.tr('unclaimed_business_badge'),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.verified, color: Colors.green, size: 16),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$categoryLabel${dist != null ? ' • ${dist.toStringAsFixed(1)} km' : ''}'
                      '${(r['city'] ?? '').toString().isNotEmpty ? ' • ${(r['city'] ?? '').toString()}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    if (((r['business_profile'] as String?) ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          (r['business_profile'] as String).trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: isFav ? Colors.red : Colors.grey.shade400,
                ),
                onPressed: id.isEmpty ? null : () => _toggleFavorite(id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderBanner(String categoryStr) {
    IconData icon;
    switch (categoryStr) {
      case 'cafe_bakery':
        icon = Icons.bakery_dining_outlined;
        break;
      case 'fast_food':
        icon = Icons.fastfood_outlined;
        break;
      case 'italian':
        icon = Icons.local_pizza_outlined;
        break;
      default:
        icon = Icons.restaurant_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F766E).withValues(alpha: 0.15),
            const Color(0xFF0D9488).withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: const Color(0xFF0F766E), size: 36),
      ),
    );
  }
}
