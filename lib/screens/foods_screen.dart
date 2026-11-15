import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

import '../core/localization/app_localizations.dart';
import '../core/food_categories.dart';
import '../models/post_model.dart';
import '../services/mention_service.dart';
import '../services/post_service.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/global_bottom_nav.dart';

class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  static const int _kPageSize = 24;

  bool _isFrench = false;
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'all';
  String _sortBy = 'date_desc';
  String _search = '';
  final _searchCtrl = TextEditingController();

  // Raw server rows, accumulated across pages
  List<Map<String, dynamic>> _rawRows = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  late final ScrollController _scrollCtrl;

  double? _meLat;
  double? _meLng;

  int _gridCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 800) return 3;
    return 2;
  }

  double _gridAspectRatio(double width) {
    final count = _gridCount(width);
    if (count == 2) return 0.58;
    if (count == 3) return 0.72;
    return 0.88;
  }

  String _plainListingText(String raw) {
    return MentionService.parseTaggedContent(raw).body;
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  double _toRad(double d) => d * math.pi / 180;

  double? _distanceKm(Post p) {
    if (_meLat == null || _meLng == null) return null;
    const earth = 6371.0;
    final dLat = _toRad(p.latitude - _meLat!);
    final dLng = _toRad(p.longitude - _meLng!);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(_meLat!)) *
            math.cos(_toRad(p.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earth * c;
  }

  void _sortItems(List<Post> items) {
    switch (_sortBy) {
      case 'date_asc':
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'price_asc':
        items.sort((a, b) {
          final aPrice = a.marketPrice ?? double.infinity;
          final bPrice = b.marketPrice ?? double.infinity;
          return aPrice.compareTo(bPrice);
        });
        break;
      case 'price_desc':
        items.sort((a, b) {
          final aPrice = a.marketPrice ?? -1;
          final bPrice = b.marketPrice ?? -1;
          return bPrice.compareTo(aPrice);
        });
        break;
      case 'date_desc':
      default:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }

  /// Compute the filtered + sorted list from raw server rows.
  List<Post> get _filteredFoods {
    var items = _rawRows.map((e) => Post.fromMap(e)).toList();

    if (_selectedCategory != 'all') {
      items = items.where((p) => (p.marketCategory ?? '') == _selectedCategory).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      items = items.where((p) {
        return (p.marketTitle ?? '').toLowerCase().contains(q) ||
            p.content.toLowerCase().contains(q) ||
            (p.authorBusinessName ?? '').toLowerCase().contains(q) ||
            (p.authorName ?? '').toLowerCase().contains(q) ||
            foodCategoryLabel(p.marketCategory ?? '', isFrench: _isFrench).toLowerCase().contains(q);
      }).toList();
    }

    _sortItems(items);
    return items;
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
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('latitude, longitude')
            .eq('id', me)
            .maybeSingle();
        _meLat = (profile?['latitude'] as num?)?.toDouble();
        _meLng = (profile?['longitude'] as num?)?.toDouble();
      }

      // Default to launch hub (Ris-Orangis, Essonne) if user location is unavailable
      _meLat ??= 48.6508;
      _meLng ??= 2.4143;

      final data = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(full_name, business_name, avatar_url, city, zipcode)')
          .inFilter('post_type', ['food_ad', 'food'])
          .order('created_at', ascending: false)
          .range(0, _kPageSize - 1);

      final rows = await PostService(Supabase.instance.client)
          .excludeUnavailableAuthorRows((data as List).cast<Map<String, dynamic>>());

      if (!mounted) return;
      setState(() {
        _rawRows = rows;
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
      final from = _page * _kPageSize;
      final to = from + _kPageSize - 1;

      final data = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(full_name, business_name, avatar_url, city, zipcode)')
          .inFilter('post_type', ['food_ad', 'food'])
          .order('created_at', ascending: false)
          .range(from, to);

      final rows = await PostService(Supabase.instance.client)
          .excludeUnavailableAuthorRows((data as List).cast<Map<String, dynamic>>());

      if (!mounted) return;
      setState(() {
        _rawRows = [..._rawRows, ...rows];
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
    return Scaffold(
      appBar: GlobalAppBar(
        title: l10n.tr('food_ads'),
        showBackIfPossible: true,
        homeRoute: '/feed',
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Column(
        children: [
          // Switch between Dishes and Restaurants
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fastfood, size: 16, color: Color(0xFF0F766E)),
                          const SizedBox(width: 6),
                          Text(
                            _isFrench ? 'Plats à la carte' : 'Dishes & Items',
                            style: const TextStyle(
                              color: Color(0xFF0F766E),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/restaurants'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restaurant_menu, size: 16, color: Colors.black87),
                          const SizedBox(width: 6),
                          Text(
                            _isFrench ? 'Voir restaurants (50)' : 'View restaurants (50)',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Compact Search & Sort Header
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
                        hintText: l10n.tr('search_foods_category_restaurant'),
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
                PopupMenuButton<String>(
                  tooltip: l10n.tr('sort_by'),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_vert, size: 18, color: Color(0xFF0F766E)),
                        const SizedBox(width: 4),
                        Text(
                          _sortBy == 'price_asc'
                              ? 'Prix ↑'
                              : _sortBy == 'price_desc'
                                  ? 'Prix ↓'
                                  : _sortBy == 'date_asc'
                                      ? 'Anciens'
                                      : 'Récents',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onSelected: (v) {
                    setState(() => _sortBy = v);
                    _load();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'date_desc', child: Text(l10n.tr('newest_first'))),
                    PopupMenuItem(value: 'date_asc', child: Text(l10n.tr('oldest_first'))),
                    PopupMenuItem(value: 'price_asc', child: Text(l10n.tr('price_low_to_high'))),
                    PopupMenuItem(value: 'price_desc', child: Text(l10n.tr('price_high_to_low'))),
                  ],
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
                _buildCategoryChip('all', l10n.tr('all_food_categories')),
                ...foodMainCategories.map(
                  (c) => _buildCategoryChip(c, foodCategoryLabel(c, isFrench: _isFrench)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(l10n.tr('error_with_detail', args: {'error': '$_error'})))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final posts = _filteredFoods;
                            final showFooter = _loadingMore || _hasMore;
                            final itemCount = posts.isEmpty
                                ? 1
                                : posts.length + (showFooter ? 1 : 0);

                            if (posts.isEmpty) {
                              return GridView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.all(12),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridCount(constraints.maxWidth),
                                  childAspectRatio: _gridAspectRatio(constraints.maxWidth),
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemCount: 1,
                                itemBuilder: (context, index) => Center(
                                  child: Text(l10n.tr('no_food_ads_found')),
                                ),
                              );
                            }

                            return GridView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.all(12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _gridCount(constraints.maxWidth),
                                childAspectRatio: _gridAspectRatio(
                                  constraints.maxWidth,
                                ),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: itemCount,
                              itemBuilder: (context, index) {
                                // Footer item
                                if (index >= posts.length) {
                                  return Center(
                                    child: _loadingMore
                                        ? const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: CircularProgressIndicator(),
                                          )
                                        : const SizedBox.shrink(),
                                  );
                                }

                                final p = posts[index];
                                final distanceKm = _distanceKm(p);
                                final title = (p.marketTitle ?? '').trim().isNotEmpty
                                    ? p.marketTitle!.trim()
                                    : _plainListingText(p.content);
                                final price = p.marketPrice != null
                                    ? '€${p.marketPrice!.toStringAsFixed(2)}'
                                    : l10n.tr('price_on_request');

                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => context.push('/foods/${p.id}'),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 112,
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              color: Colors.grey.shade200,
                                              padding: const EdgeInsets.all(6),
                                              child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                                  ? Image.network(
                                                      p.imageUrl!,
                                                      fit: BoxFit.contain,
                                                      alignment: Alignment.center,
                                                    )
                                                  : const Icon(Icons.fastfood, size: 40),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              if (((p.authorBusinessName ?? p.authorName) ?? '').trim().isNotEmpty) ...[
                                                const SizedBox(height: 5),
                                                InkWell(
                                                  onTap: p.userId.isEmpty ? null : () => context.push('/p/${p.userId}'),
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.restaurant, size: 12, color: Color(0xFF0F766E)),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            ((p.authorBusinessName ?? p.authorName) ?? '').trim(),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: Color(0xFF0F766E),
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              Text(
                                                price,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                foodCategoryLabel(p.marketCategory ?? '', isFrench: _isFrench),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              if ((p.authorCity ?? '').trim().isNotEmpty ||
                                                  (p.authorZipcode ?? '').trim().isNotEmpty ||
                                                  distanceKm != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  [
                                                    if ((p.authorCity ?? '').trim().isNotEmpty)
                                                      p.authorCity!.trim(),
                                                    if ((p.authorCity ?? '').trim().isEmpty &&
                                                        (p.authorZipcode ?? '').trim().isNotEmpty)
                                                      p.authorZipcode!.trim(),
                                                    if (distanceKm != null)
                                                      '${distanceKm.toStringAsFixed(1)} km',
                                                  ].join(' • '),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
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
}
