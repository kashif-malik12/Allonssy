import 'package:supabase_flutter/supabase_flutter.dart';

class FeedFilterService {
  FeedFilterService(this._db);

  static const String feedFiltersKey = 'feed_filters';

  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  static Map<String, dynamic> defaultFilters() {
    return {
      'general_enabled': true,
      'general_scope': 'all',
      'market_enabled': true,
      'market_intents': ['buying', 'selling'],
      'market_categories': <String>[],
      'gigs_enabled': true,
      'gig_types': ['service_offer', 'service_request'],
      'gig_categories': <String>[],
      'lost_found_enabled': true,
      'lost_found_scope': 'all',
      'food_enabled': true,
      'food_categories': <String>[],
      'org_enabled': false,
      'org_kinds': <String>[],
    };
  }

  Future<Map<String, dynamic>?> load() async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final row = await _db
          .from('profiles')
          .select('feed_filters')
          .eq('id', uid)
          .maybeSingle();
      final profileFilters = row?['feed_filters'];
      if (profileFilters is Map) {
        return Map<String, dynamic>.from(profileFilters);
      }
    } catch (_) {
      // Fall back to auth metadata.
    }

    final metadataFilters = _db.auth.currentUser?.userMetadata?[feedFiltersKey];
    if (metadataFilters is Map) {
      return Map<String, dynamic>.from(metadataFilters);
    }
    return null;
  }

  Future<bool> hasConfiguredFilters() async {
    final loaded = await load();
    return loaded != null;
  }

  Future<void> save(Map<String, dynamic> filters) async {
    final uid = _uid;
    if (uid == null) return;

    final normalized = Map<String, dynamic>.from(filters);

    try {
      await _db.from('profiles').update({
        'feed_filters': normalized,
      }).eq('id', uid);
    } catch (_) {
      // Keep auth metadata fallback for older schemas.
    }

    try {
      await _db.auth.updateUser(
        UserAttributes(data: {
          feedFiltersKey: normalized,
        }),
      );
    } catch (_) {
      // Non-blocking.
    }
  }
}
