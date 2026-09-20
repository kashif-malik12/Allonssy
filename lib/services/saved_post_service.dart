import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_service.dart';

class SavedPostService {
  final SupabaseClient _db;
  SavedPostService(this._db);

  String? get _me => _db.auth.currentUser?.id;

  /// Check if a post is saved by the current user.
  Future<bool> isSaved(String postId) async {
    final uid = _me;
    if (uid == null || postId.isEmpty) return false;

    try {
      final row = await _db
          .from('saved_posts')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Batch-fetch saved status for a collection of post IDs.
  Future<Set<String>> fetchSavedPostIds(List<String> postIds) async {
    final uid = _me;
    final ids = postIds.where((id) => id.isNotEmpty).toSet().toList();
    if (uid == null || ids.isEmpty) return {};

    try {
      final rows = await _db
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', uid)
          .inFilter('post_id', ids);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (r['post_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Save a post for the current user.
  Future<void> savePost(String postId) async {
    final uid = _me;
    if (uid == null) throw Exception('Must be logged in to save posts');

    await _db.from('saved_posts').upsert({
      'user_id': uid,
      'post_id': postId,
    }, onConflict: 'user_id,post_id');
  }

  /// Remove a post from saved.
  Future<void> unsavePost(String postId) async {
    final uid = _me;
    if (uid == null) throw Exception('Must be logged in to unsave posts');

    await _db
        .from('saved_posts')
        .delete()
        .eq('user_id', uid)
        .eq('post_id', postId);
  }

  /// Toggle save status. Returns the new saved state (`true` if saved, `false` if unsaved).
  Future<bool> toggleSave(String postId) async {
    final currentlySaved = await isSaved(postId);
    if (currentlySaved) {
      await unsavePost(postId);
      return false;
    } else {
      await savePost(postId);
      return true;
    }
  }

  /// Fetch saved marketplace posts for current user, ordered by most recently saved first.
  Future<List<Map<String, dynamic>>> fetchSavedMarketplacePosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final uid = _me;
    if (uid == null) return [];

    try {
      // 1. Fetch saved post IDs in order
      final savedRows = await _db
          .from('saved_posts')
          .select('post_id, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final postIds = (savedRows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (r['post_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (postIds.isEmpty) return [];

      // 2. Fetch full post records with author profiles
      final postData = await _db
          .from('posts')
          .select(PostService.postSelect)
          .inFilter('id', postIds);

      final rawPosts = (postData as List).cast<Map<String, dynamic>>();

      // 3. Filter out unavailable authors
      final availablePosts =
          await PostService(_db).excludeUnavailableAuthorRows(rawPosts);

      // 4. Maintain original saved order
      final postMap = {
        for (final p in availablePosts) (p['id'] ?? '').toString(): p,
      };

      final ordered = <Map<String, dynamic>>[];
      for (final id in postIds) {
        if (postMap.containsKey(id)) {
          ordered.add(postMap[id]!);
        }
      }

      return ordered;
    } catch (_) {
      return [];
    }
  }

  /// Fetch saved gig / service posts for current user, ordered by most recently saved first.
  Future<List<Map<String, dynamic>>> fetchSavedGigPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final uid = _me;
    if (uid == null) return [];

    try {
      final savedRows = await _db
          .from('saved_posts')
          .select('post_id, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final postIds = (savedRows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (r['post_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (postIds.isEmpty) return [];

      final postData = await _db
          .from('posts')
          .select(PostService.postSelect)
          .inFilter('id', postIds)
          .inFilter('post_type', ['service_offer', 'service_request']);

      final rawPosts = (postData as List).cast<Map<String, dynamic>>();

      final availablePosts =
          await PostService(_db).excludeUnavailableAuthorRows(rawPosts);

      final postMap = {
        for (final p in availablePosts) (p['id'] ?? '').toString(): p,
      };

      final ordered = <Map<String, dynamic>>[];
      for (final id in postIds) {
        if (postMap.containsKey(id)) {
          ordered.add(postMap[id]!);
        }
      }

      return ordered;
    } catch (_) {
      return [];
    }
  }
}
