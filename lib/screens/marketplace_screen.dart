import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/market_categories.dart';
import '../models/post_model.dart';
import '../widgets/global_app_bar.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'all';
  String _selectedIntent = 'all';
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Building the query step by step to avoid analyzer issues
      var query = Supabase.instance.client
          .from('posts')
          .select('*, profiles(full_name, avatar_url)')
          ..filter('post_type', 'eq', 'market')
          .order('created_at', ascending: false)
          .limit(60);

      if (_selectedCategory != 'all') {
        query..filter('market_category', 'eq', _selectedCategory);
      }
      if (_selectedIntent != 'all') {
        query..filter('market_intent', 'eq', _selectedIntent);
      }

      final data = await query;
      final rows = (data as List).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _posts = rows.map((e) => Post.fromMap(e)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: 'Marketplace',
        showBackIfPossible: true,
        homeRoute: '/feed',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-post'),
        icon: const Icon(Icons.add),
        label: const Text('Sell / Buy'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                const Text('Category:'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All categories'),
                      ),
                      ...marketMainCategories.map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(marketCategoryLabel(c)),
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                const Text('Type:'),
                const SizedBox(width: 40),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedIntent,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All types')),
                      DropdownMenuItem(value: 'selling', child: Text('Selling')),
                      DropdownMenuItem(value: 'buying', child: Text('Buying')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedIntent = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text('Error: $_error'))
                : _posts.isEmpty
                ? const Center(child: Text('No marketplace posts found'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      itemCount: _posts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _posts[index];
                        final author = (p.authorName ?? 'Unknown').trim();
                        final category = p.marketCategory;
                        final intent = p.marketIntent;

                        return ListTile(
                          onTap: () => context.push('/post/${p.id}'),
                          title: Text(p.content),
                          subtitle: Text(
                            [
                              'by $author',
                              if (intent != null && intent.isNotEmpty)
                                intent == 'buying' ? 'Buying' : intent == 'selling' ? 'Selling' : intent,
                              if (category != null && category.isNotEmpty)
                                marketCategoryLabel(category),
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
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