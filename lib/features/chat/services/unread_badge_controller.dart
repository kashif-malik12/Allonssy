import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnreadBadgeController {
  UnreadBadgeController(this._db);

  final SupabaseClient _db;

  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  StreamSubscription<List<Map<String, dynamic>>>? _sub1;
  StreamSubscription<List<Map<String, dynamic>>>? _sub2;

  Future<void> init() async {
    await refresh();

    // ✅ Simple + reliable: whenever messages change, refresh unread counter via RPC
    // (We can't perfectly filter realtime by "my conversations" without extra schema,
    // so we refresh by RPC on any insert/update seen by RLS.)
    _sub1 = _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((_) => refresh());

    _sub2 = _db
        .from('offer_messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _db.rpc('get_unread_total'),
        _db.rpc('get_offer_chat_list'),
      ]);

      final dmUnread = (results[0] as num).toInt();
      final offerRows = (results[1] as List).cast<Map<String, dynamic>>();
      final offerUnread = offerRows.fold<int>(
        0,
        (sum, row) => sum + (((row['unread_count'] as num?)?.toInt()) ?? 0),
      );

      unread.value = dmUnread + offerUnread;
    } catch (_) {
      // ignore; keep last value
    }
  }

  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    unread.value = 0;
  }
}
