import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

import '../core/localization/app_localizations.dart';
import '../core/item_condition.dart';
import '../core/market_categories.dart';
import '../models/post_model.dart';
import '../services/mention_service.dart';
import '../services/post_service.dart';
import '../services/saved_post_service.dart';
import '../services/follow_service.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/global_bottom_nav.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const int _kPageSize = 30;

  bool _isFrench = false;
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'all';
  String _selectedIntent = 'all';
  String _selectedCondition = 'all';
  String _sortBy = 'date_desc';
  String _search = '';
  bool _hideSold = false;
  bool _onlySaved = false;
  bool _onlyPriceDrop = false;
  String _selectedSource = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  late final SavedPostService _savedPostService;
  late final FollowService _followService;
  Set<String> _savedPostIds = {};
  Set<String> _followingIds = {};
  Set<String> _connectionIds = {};

  // Raw server rows, accumulated across pages
  List<Map<String, dynamic>> _rawRows = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  late final ScrollController _scrollCtrl;

  double? _meLat;
  double? _meLng;
  bool _showFilters = false;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'all') count++;
    if (_selectedIntent != 'all') count++;
    if (_selectedCondition != 'all') count++;
    if (_sortBy != 'date_desc') count++;
    if (_hideSold) count++;
    if (_onlySaved) count++;
    if (_onlyPriceDrop) count++;
    if (_selectedSource != 'all') count++;
    return count;
  }

  int _gridCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 800) return 3;
    return 2;
  }

  double _gridAspectRatio(double width) {
    final count = _gridCount(width);
    if (count == 2) return 0.58;
    if (count == 3) return 0.70;
    return 0.88;
  }

  String _plainListingText(String raw) {
    return MentionService.parseTaggedContent(raw).body;
  }

  Widget _buildResponsiveDropdownRow({
    required String label,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              child,
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(label),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _savedPostService = SavedPostService(Supabase.instance.client);
    _followService = FollowService(Supabase.instance.client);
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

  String _intentLabel(String? intent) {
    switch (intent) {
      case 'buying':
        return context.l10n.tr('buying');
      case 'selling':
        return context.l10n.tr('selling');
      default:
        return (intent ?? '').trim();
    }
  }

  bool _matchesIntentByContent(Post post, String targetIntent) {
    final text = post.content.toLowerCase();
    if (targetIntent == 'selling') {
      return text.contains('sell') ||
          text.contains('for sale') ||
          text.contains('wts');
    }

    if (targetIntent == 'buying') {
      return text.contains('buy') ||
          text.contains('looking for') ||
          text.contains('wtb');
    }

    return true;
  }

  double? _priceFromContent(String raw) {
    final patterns = [
      RegExp(r'price\s*:\s*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
      RegExp(r'price\s*:\s*(?:eur|euro|€|\$)\s*(\d+(?:[.,]\d{1,2})?)',
          caseSensitive: false),
      RegExp(r'(?:eur|euro|€)\s*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
      RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*eur', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      if (match != null) {
        final value = (match.group(1) ?? '').replaceAll(',', '.');
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  double _toRad(double d) => d * math.pi / 180;

  double? _distanceKm(Post p) {
    if (_meLat == null || _meLng == null) return null;
    final lat2 = p.latitude;
    final lng2 = p.longitude;
    const earth = 6371.0;
    final dLat = _toRad(lat2 - _meLat!);
    final dLng = _toRad(lng2 - _meLng!);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(_meLat!)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earth * c;
  }

  String _formatCreatedDate(DateTime dt) {
    final d = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  void _sortItems(List<Post> items) {
    switch (_sortBy) {
      case 'date_asc':
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'price_asc':
        items.sort((a, b) {
          final aPrice = a.marketPrice ?? _priceFromContent(a.content) ?? double.infinity;
          final bPrice = b.marketPrice ?? _priceFromContent(b.content) ?? double.infinity;
          return aPrice.compareTo(bPrice);
        });
        break;
      case 'price_desc':
        items.sort((a, b) {
          final aPrice = a.marketPrice ?? _priceFromContent(a.content) ?? -1;
          final bPrice = b.marketPrice ?? _priceFromContent(b.content) ?? -1;
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
  List<Post> get _filteredPosts {
    final rows = _rawRows;
    var items = rows.map((e) => Post.fromMap(e)).toList();

    if (_selectedCategory != 'all') {
      items = items
          .where((p) => (p.marketCategory ?? '').trim() == _selectedCategory)
          .toList();
    }

    if (_selectedIntent != 'all') {
      items = items.where((p) {
        final intent = (p.marketIntent ?? '').trim();
        if (intent.isNotEmpty) {
          return intent == _selectedIntent;
        }
        return _matchesIntentByContent(p, _selectedIntent);
      }).toList();
    }

    if (_selectedCondition != 'all') {
      items = items
          .where((p) => (p.itemCondition ?? '').trim().toLowerCase() == _selectedCondition)
          .toList();
    }

    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((p) {
        final title = (p.marketTitle ?? '').toLowerCase();
        final content = p.content.toLowerCase();
        final seller = (p.authorName ?? '').toLowerCase();
        final category = marketCategoryLabel(p.marketCategory ?? '', isFrench: _isFrench).toLowerCase();
        return title.contains(q) ||
            content.contains(q) ||
            seller.contains(q) ||
            category.contains(q);
      }).toList();
    }

    if (_hideSold) {
      items = items.where((p) => p.itemStatus != 'sold').toList();
    }

    if (_onlySaved) {
      items = items.where((p) => _savedPostIds.contains(p.id)).toList();
    }

    if (_onlyPriceDrop) {
      items = items.where((p) => p.hasDiscount).toList();
    }

    _sortItems(items);
    return items;
  }

  Future<void> _toggleSave(Post post) async {
    final l10n = context.l10n;
    final wasSaved = _savedPostIds.contains(post.id);
    setState(() {
      if (wasSaved) {
        _savedPostIds.remove(post.id);
      } else {
        _savedPostIds.add(post.id);
      }
    });

    try {
      if (wasSaved) {
        await _savedPostService.unsavePost(post.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('listing_unsaved')),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l10n.tr('undo'),
              onPressed: () async {
                try {
                  await _savedPostService.savePost(post.id);
                  if (mounted) {
                    setState(() => _savedPostIds.add(post.id));
                  }
                } catch (_) {}
              },
            ),
          ),
        );
      } else {
        await _savedPostService.savePost(post.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('listing_saved')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedPostIds.add(post.id);
        } else {
          _savedPostIds.remove(post.id);
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
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('latitude, longitude')
            .eq('id', me)
            .maybeSingle();
        _meLat = (profile?['latitude'] as num?)?.toDouble();
        _meLng = (profile?['longitude'] as num?)?.toDouble();

        final network = await _followService.fetchMyNetworkIds();
        _followingIds = network.followingIds;
        _connectionIds = network.connectionIds;
      }

      if (_selectedSource != 'all') {
        final targetIds = _selectedSource == 'connections'
            ? _connectionIds
            : _followingIds;
        if (targetIds.isEmpty) {
          if (!mounted) return;
          setState(() {
            _rawRows = [];
            _savedPostIds = {};
            _page = 0;
            _hasMore = false;
            _loading = false;
          });
          return;
        }

        final data = await Supabase.instance.client
            .from('posts')
            .select(PostService.postSelect)
            .eq('post_type', 'market')
            .inFilter('user_id', targetIds.toList())
            .order('created_at', ascending: false)
            .range(0, _kPageSize - 1);

        final rows = await PostService(Supabase.instance.client)
            .excludeUnavailableAuthorRows((data as List).cast<Map<String, dynamic>>());

        final ids = rows.map((r) => (r['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
        final savedIds = await _savedPostService.fetchSavedPostIds(ids);

        if (!mounted) return;
        setState(() {
          _rawRows = rows;
          _savedPostIds = savedIds;
          _page = 1;
          _hasMore = rows.length == _kPageSize;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('posts')
          .select(PostService.postSelect)
          .eq('post_type', 'market')
          .order('created_at', ascending: false)
          .range(0, _kPageSize - 1);

      final rows = await PostService(Supabase.instance.client)
          .excludeUnavailableAuthorRows((data as List).cast<Map<String, dynamic>>());

      final ids = rows.map((r) => (r['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      final savedIds = await _savedPostService.fetchSavedPostIds(ids);

      if (!mounted) return;
      setState(() {
        _rawRows = rows;
        _savedPostIds = savedIds;
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

      var q = Supabase.instance.client
          .from('posts')
          .select(PostService.postSelect)
          .eq('post_type', 'market');

      if (_selectedSource != 'all') {
        final targetIds = _selectedSource == 'connections'
            ? _connectionIds
            : _followingIds;
        if (targetIds.isEmpty) {
          if (mounted) setState(() => _loadingMore = false);
          return;
        }
        q = q.inFilter('user_id', targetIds.toList());
      }

      final data = await q
          .order('created_at', ascending: false)
          .range(from, to);

      final rows = await PostService(Supabase.instance.client)
          .excludeUnavailableAuthorRows((data as List).cast<Map<String, dynamic>>());

      final ids = rows.map((r) => (r['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      final moreSaved = await _savedPostService.fetchSavedPostIds(ids);

      if (!mounted) return;
      setState(() {
        _rawRows = [..._rawRows, ...rows];
        _savedPostIds = {..._savedPostIds, ...moreSaved};
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
        title: l10n.tr('marketplace'),
        showBackIfPossible: true,
        homeRoute: '/feed',
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: l10n.tr('saved_listings'),
            onPressed: () async {
              await context.push('/marketplace/saved');
              if (mounted) _load();
            },
          ),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-post'),
        icon: const Icon(Icons.add),
        label: Text(l10n.tr('sell_buy')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.tr('search_products_category_seller'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _load();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                setState(() => _search = value);
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                ActionChip(
                  avatar: Icon(
                    _showFilters ? Icons.expand_less : Icons.tune,
                    size: 18,
                  ),
                  label: Text(l10n.tr('filters')),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                  backgroundColor: _activeFilterCount > 0
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                if (_activeFilterCount > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '($_activeFilterCount)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'all';
                        _selectedIntent = 'all';
                        _selectedCondition = 'all';
                        _sortBy = 'date_desc';
                        _hideSold = false;
                        _onlySaved = false;
                        _onlyPriceDrop = false;
                        _selectedSource = 'all';
                      });
                      _load();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.tr('clear')),
                  ),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showFilters
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _buildResponsiveDropdownRow(
                          label: l10n.tr('source_label'),
                          child: DropdownButton<String>(
                            value: _selectedSource,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(l10n.tr('all_listings'))),
                              DropdownMenuItem(value: 'network', child: Text(l10n.tr('from_network'))),
                              DropdownMenuItem(value: 'connections', child: Text(l10n.tr('from_connections_only'))),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _selectedSource = v);
                              _load();
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _buildResponsiveDropdownRow(
                          label: l10n.tr('category_label'),
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text(l10n.tr('all_categories')),
                              ),
                              ...marketMainCategories.map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(marketCategoryLabel(c, isFrench: _isFrench)),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _selectedCategory = v);
                              _load();
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _buildResponsiveDropdownRow(
                          label: l10n.tr('type_label'),
                          child: DropdownButton<String>(
                            value: _selectedIntent,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(l10n.tr('all_types'))),
                              DropdownMenuItem(value: 'selling', child: Text(l10n.tr('selling'))),
                              DropdownMenuItem(value: 'buying', child: Text(l10n.tr('buying'))),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _selectedIntent = v);
                              _load();
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _buildResponsiveDropdownRow(
                          label: l10n.tr('item_condition'),
                          child: DropdownButton<String>(
                            value: _selectedCondition,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: 'all', child: Text(l10n.tr('all_conditions'))),
                              DropdownMenuItem(value: 'new', child: Text(l10n.tr('condition_new'))),
                              DropdownMenuItem(value: 'like_new', child: Text(l10n.tr('condition_like_new'))),
                              DropdownMenuItem(value: 'good', child: Text(l10n.tr('condition_good'))),
                              DropdownMenuItem(value: 'fair', child: Text(l10n.tr('condition_fair'))),
                              DropdownMenuItem(value: 'parts', child: Text(l10n.tr('condition_parts'))),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _selectedCondition = v);
                              _load();
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _buildResponsiveDropdownRow(
                          label: l10n.tr('sort_label'),
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: 'date_desc', child: Text(l10n.tr('newest_first'))),
                              DropdownMenuItem(value: 'date_asc', child: Text(l10n.tr('oldest_first'))),
                              DropdownMenuItem(value: 'price_asc', child: Text(l10n.tr('price_low_to_high'))),
                              DropdownMenuItem(value: 'price_desc', child: Text(l10n.tr('price_high_to_low'))),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _sortBy = v);
                              _load();
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 12, 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _hideSold = !_hideSold),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _hideSold,
                                    onChanged: (v) => setState(() => _hideSold = v ?? false),
                                  ),
                                  Text(l10n.tr('hide_sold_items')),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _onlySaved = !_onlySaved),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _onlySaved,
                                    onChanged: (v) => setState(() => _onlySaved = v ?? false),
                                  ),
                                  Text(l10n.tr('saved')),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _onlyPriceDrop = !_onlyPriceDrop),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _onlyPriceDrop,
                                    onChanged: (v) => setState(() => _onlyPriceDrop = v ?? false),
                                  ),
                                  Text(l10n.tr('price_drop_only')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
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
                            final posts = _filteredPosts;
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
                                  child: _selectedSource != 'all'
                                      ? Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                              const SizedBox(height: 12),
                                              Text(
                                                l10n.tr('no_network_listings'),
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                l10n.tr('no_network_listings_subtitle'),
                                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 16),
                                              FilledButton.tonal(
                                                onPressed: () {
                                                  setState(() => _selectedSource = 'all');
                                                  _load();
                                                },
                                                child: Text(l10n.tr('view_all_listings')),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Text(l10n.tr('no_marketplace_posts_found')),
                                ),
                              );
                            }

                            return GridView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _gridCount(constraints.maxWidth),
                                childAspectRatio: _gridAspectRatio(constraints.maxWidth),
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
                                final myId = Supabase.instance.client.auth.currentUser?.id;
                                final canSendOffer = myId != null && p.userId != myId;
                                final title = (p.marketTitle ?? '').trim().isNotEmpty
                                    ? p.marketTitle!.trim()
                                    : _plainListingText(p.content);
                                final intent = p.marketIntent;
                                final effectivePrice =
                                    p.marketPrice ?? _priceFromContent(p.content);
                                final distanceKm = _distanceKm(p);
                                final String priceText;
                                if (effectivePrice != null) {
                                  if (p.marketPriceMax != null && p.marketPriceMax! > effectivePrice) {
                                    priceText = 'EUR ${effectivePrice.toStringAsFixed(2)} – EUR ${p.marketPriceMax!.toStringAsFixed(2)}';
                                  } else {
                                    priceText = 'EUR ${effectivePrice.toStringAsFixed(2)}';
                                  }
                                } else {
                                  priceText = intent == 'buying' ? l10n.tr('looking_to_buy') : l10n.tr('price_on_request');
                                }

                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => context.push('/marketplace/product/${p.id}'),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black12),
                                      color: Theme.of(context).cardColor,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 112,
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(
                                                    top: Radius.circular(12),
                                                  ),
                                                  child: Container(
                                                    width: double.infinity,
                                                    color: Colors.grey.shade200,
                                                    padding: const EdgeInsets.all(6),
                                                    child: Opacity(
                                                      opacity: p.itemStatus == 'sold' ? 0.55 : 1.0,
                                                      child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                                          ? Image.network(
                                                              p.imageUrl!,
                                                              fit: BoxFit.contain,
                                                              alignment: Alignment.center,
                                                            )
                                                          : const Icon(
                                                              Icons.image_outlined,
                                                              size: 40,
                                                              color: Colors.black45,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (p.itemStatus == 'reserved')
                                                Positioned(
                                                  top: 6,
                                                  left: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFEF3C7),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFFCD34D)),
                                                    ),
                                                    child: Text(
                                                      l10n.tr('reserved').toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF92400E),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (p.itemStatus == 'sold')
                                                Positioned(
                                                  top: 6,
                                                  left: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF374151),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      l10n.tr('sold').toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (p.hasDiscount)
                                                Positioned(
                                                  bottom: 6,
                                                  left: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFDC2626),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '-${p.discountPercentage}%',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: Material(
                                                  color: Colors.white.withAlpha(230),
                                                  shape: const CircleBorder(),
                                                  child: InkWell(
                                                    customBorder: const CircleBorder(),
                                                    onTap: () => _toggleSave(p),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(6),
                                                      child: Icon(
                                                        _savedPostIds.contains(p.id)
                                                            ? Icons.bookmark
                                                            : Icons.bookmark_outline,
                                                        size: 18,
                                                        color: _savedPostIds.contains(p.id)
                                                            ? const Color(0xFF2563EB)
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (_connectionIds.contains(p.userId)) ...[
                                                Container(
                                                  margin: const EdgeInsets.only(bottom: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFECFDF5),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.hub_outlined, size: 10, color: Color(0xFF047857)),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        l10n.tr('connected_badge'),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF047857),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ] else if (_followingIds.contains(p.userId)) ...[
                                                Container(
                                                  margin: const EdgeInsets.only(bottom: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.check, size: 10, color: Color(0xFF1D4ED8)),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        l10n.tr('following_badge'),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF1D4ED8),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 6,
                                                runSpacing: 2,
                                                children: [
                                                  Text(
                                                    priceText,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: p.hasDiscount ? const Color(0xFFDC2626) : null,
                                                    ),
                                                  ),
                                                  if (p.hasDiscount && p.originalPrice != null)
                                                    Text(
                                                      'EUR ${p.originalPrice!.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade500,
                                                        decoration: TextDecoration.lineThrough,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                marketCategoryLabel(p.marketCategory ?? '', isFrench: _isFrench),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatCreatedDate(p.createdAt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if ((intent != null && intent.isNotEmpty) ||
                                                  (p.itemCondition != null && p.itemCondition!.isNotEmpty)) ...[
                                                Wrap(
                                                  spacing: 6,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    if (intent != null && intent.isNotEmpty)
                                                      Text(
                                                        _intentLabel(intent),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    if (p.itemCondition != null && p.itemCondition!.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE0F2FE),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: const Color(0xFFBAE6FD)),
                                                        ),
                                                        child: Text(
                                                          itemConditionLabel(p.itemCondition, l10n),
                                                          style: const TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF0369A1),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                              if ((p.authorCity ?? '').trim().isNotEmpty ||
                                                  (p.authorZipcode ?? '').trim().isNotEmpty ||
                                                  distanceKm != null)
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
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 10,
                                                    ),
                                                  ),
                                                  onPressed: (canSendOffer && p.itemStatus != 'sold')
                                                      ? () => context.push(
                                                            '/offer-chat/post/${p.id}/user/${p.userId}',
                                                          )
                                                      : null,
                                                  icon: Icon(
                                                    p.itemStatus == 'sold'
                                                        ? Icons.check_circle_outline
                                                        : Icons.local_offer_outlined,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    p.itemStatus == 'sold'
                                                        ? l10n.tr('sold')
                                                        : l10n.tr('send_offer'),
                                                  ),
                                                ),
                                              ),
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
}
