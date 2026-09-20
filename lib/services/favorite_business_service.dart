import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteBusinessService {
  final SupabaseClient _db;
  FavoriteBusinessService([SupabaseClient? db]) : _db = db ?? Supabase.instance.client;

  String? get _me => _db.auth.currentUser?.id;

  /// Check if a business or restaurant is favorited by current user.
  Future<bool> isFavorite(String businessId) async {
    final uid = _me;
    if (uid == null || businessId.isEmpty) return false;

    try {
      final row = await _db
          .from('favorite_businesses')
          .select('id')
          .eq('business_id', businessId)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Batch-fetch favorite status for multiple business IDs.
  Future<Set<String>> fetchFavoriteIds(List<String> businessIds) async {
    final uid = _me;
    final ids = businessIds.where((id) => id.isNotEmpty).toSet().toList();
    if (uid == null || ids.isEmpty) return {};

    try {
      final rows = await _db
          .from('favorite_businesses')
          .select('business_id')
          .eq('user_id', uid)
          .inFilter('business_id', ids);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (r['business_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Add a business/restaurant to favorites.
  Future<void> addFavorite(String businessId) async {
    final uid = _me;
    if (uid == null) throw Exception('Must be logged in to favorite a business');

    await _db.from('favorite_businesses').upsert({
      'user_id': uid,
      'business_id': businessId,
    }, onConflict: 'user_id,business_id');
  }

  /// Remove a business/restaurant from favorites.
  Future<void> removeFavorite(String businessId) async {
    final uid = _me;
    if (uid == null) throw Exception('Must be logged in to unfavorite a business');

    await _db
        .from('favorite_businesses')
        .delete()
        .eq('user_id', uid)
        .eq('business_id', businessId);
  }

  /// Toggle favorite status.
  Future<bool> toggleFavorite(String businessId) async {
    final currentlyFav = await isFavorite(businessId);
    if (currentlyFav) {
      await removeFavorite(businessId);
      return false;
    } else {
      await addFavorite(businessId);
      return true;
    }
  }
}
