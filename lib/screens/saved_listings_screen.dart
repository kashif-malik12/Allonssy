import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

import '../core/localization/app_localizations.dart';
import '../core/market_categories.dart';
import '../models/post_model.dart';
import '../services/mention_service.dart';
import '../services/saved_post_service.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/global_bottom_nav.dart';

class SavedListingsScreen extends StatefulWidget {
  const SavedListingsScreen({super.key});

  @override
  State<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends State<SavedListingsScreen> {
  bool _loading = true;
  String? _error;
  List<Post> _posts = [];
  double? _meLat;
  double? _meLng;
  late final SavedPostService _savedPostService;

  @override
  void initState() {
    super.initState();
    _savedPostService = SavedPostService(Supabase.instance.client);
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
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

      final rows = await _savedPostService.fetchSavedMarketplacePosts(limit: 50);
      final posts = rows.map((e) => Post.fromMap(e)).toList();

      if (!mounted) return;
      setState(() {
        _posts = posts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unsave(Post post) async {
    final l10n = context.l10n;
    final removedIndex = _posts.indexOf(post);
    setState(() {
      _posts.removeWhere((p) => p.id == post.id);
    });

    try {
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
                  setState(() {
                    if (removedIndex >= 0 && removedIndex <= _posts.length) {
                      _posts.insert(removedIndex, post);
                    } else {
                      _posts.add(post);
                    }
                  });
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Revert if network error
      setState(() {
        if (removedIndex >= 0 && removedIndex <= _posts.length) {
          _posts.insert(removedIndex, post);
        } else {
          _posts.add(post);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFrench = l10n.isFrench;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: GlobalAppBar(
        title: l10n.tr('saved_listings'),
        showBackIfPossible: true,
        homeRoute: '/marketplace',
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.bookmark_border_rounded,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.tr('no_saved_listings'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.tr('no_saved_listings_subtitle'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  context.go('/marketplace');
                                }
                              },
                              icon: const Icon(Icons.storefront_outlined),
                              label: Text(l10n.tr('marketplace')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = _gridCount(constraints.maxWidth);
                          final aspect = _gridAspectRatio(constraints.maxWidth);

                          return GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: aspect,
                            ),
                            itemCount: _posts.length,
                            itemBuilder: (context, index) {
                              final p = _posts[index];
                              final canSendOffer =
                                  myId != null && p.userId != myId;
                              final title = (p.marketTitle ?? '').trim().isNotEmpty
                                  ? p.marketTitle!.trim()
                                  : _plainListingText(p.content);
                              final effectivePrice = p.marketPrice ??
                                  _priceFromContent(p.content);
                              final intent = (p.marketIntent ?? '').trim();
                              final distanceKm = _distanceKm(p);

                              final String priceText;
                              if (effectivePrice != null) {
                                if (p.marketPriceMax != null &&
                                    p.marketPriceMax! > effectivePrice) {
                                  priceText =
                                      'EUR ${effectivePrice.toStringAsFixed(2)} – EUR ${p.marketPriceMax!.toStringAsFixed(2)}';
                                } else {
                                  priceText =
                                      'EUR ${effectivePrice.toStringAsFixed(2)}';
                                }
                              } else {
                                priceText = intent == 'buying'
                                    ? l10n.tr('looking_to_buy')
                                    : l10n.tr('price_on_request');
                              }

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await context
                                      .push('/marketplace/product/${p.id}');
                                  if (mounted) _load();
                                },
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black12),
                                    color: Theme.of(context).cardColor,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 112,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                  top: Radius.circular(12),
                                                ),
                                                child: Container(
                                                  width: double.infinity,
                                                  color: Colors.grey.shade200,
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Opacity(
                                                    opacity: p.itemStatus ==
                                                            'sold'
                                                        ? 0.55
                                                        : 1.0,
                                                    child: p.imageUrl != null &&
                                                            p.imageUrl!
                                                                .isNotEmpty
                                                        ? Image.network(
                                                            p.imageUrl!,
                                                            fit: BoxFit.contain,
                                                            alignment: Alignment
                                                                .center,
                                                          )
                                                        : const Icon(
                                                            Icons.image_outlined,
                                                            size: 40,
                                                            color:
                                                                Colors.black45,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Bookmark remove button
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Material(
                                                color: Colors.white
                                                    .withAlpha(230),
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  customBorder:
                                                      const CircleBorder(),
                                                  onTap: () => _unsave(p),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(6),
                                                    child: Icon(
                                                      Icons.bookmark,
                                                      size: 18,
                                                      color: Color(0xFF2563EB),
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
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFFEF3C7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFFCD34D)),
                                                  ),
                                                  child: Text(
                                                    l10n
                                                        .tr('reserved')
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF374151),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    l10n
                                                        .tr('sold')
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
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
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            10, 8, 10, 10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
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
                                               crossAxisAlignment:
                                                   WrapCrossAlignment.center,
                                               spacing: 6,
                                               runSpacing: 2,
                                               children: [
                                                 Text(
                                                   priceText,
                                                   maxLines: 1,
                                                   overflow:
                                                       TextOverflow.ellipsis,
                                                   style: TextStyle(
                                                     fontSize: 14,
                                                     fontWeight:
                                                         FontWeight.bold,
                                                     color: p.hasDiscount
                                                         ? const Color(0xFFDC2626)
                                                         : null,
                                                   ),
                                                 ),
                                                 if (p.hasDiscount &&
                                                     p.originalPrice != null)
                                                   Text(
                                                     'EUR ${p.originalPrice!.toStringAsFixed(2)}',
                                                     style: TextStyle(
                                                       fontSize: 11,
                                                       color: Colors
                                                           .grey.shade500,
                                                       decoration:
                                                           TextDecoration
                                                               .lineThrough,
                                                     ),
                                                   ),
                                               ],
                                             ),
                                            const SizedBox(height: 4),
                                            Text(
                                              marketCategoryLabel(
                                                  p.marketCategory ?? '',
                                                  isFrench: isFrench),
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
                                            if ((p.authorCity ?? '')
                                                    .trim()
                                                    .isNotEmpty ||
                                                (p.authorZipcode ?? '')
                                                    .trim()
                                                    .isNotEmpty ||
                                                distanceKm != null)
                                              Text(
                                                [
                                                  if ((p.authorCity ?? '')
                                                      .trim()
                                                      .isNotEmpty)
                                                    p.authorCity!.trim(),
                                                  if ((p.authorCity ?? '')
                                                          .trim()
                                                          .isEmpty &&
                                                      (p.authorZipcode ?? '')
                                                          .trim()
                                                          .isNotEmpty)
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
                                                style:
                                                    OutlinedButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 10,
                                                  ),
                                                ),
                                                onPressed: (canSendOffer &&
                                                        p.itemStatus != 'sold')
                                                    ? () => context.push(
                                                          '/offer-chat/post/${p.id}/user/${p.userId}',
                                                        )
                                                    : null,
                                                icon: Icon(
                                                  p.itemStatus == 'sold'
                                                      ? Icons
                                                          .check_circle_outline
                                                      : Icons
                                                          .local_offer_outlined,
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
    );
  }
}
