import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnreadBadgeController {
  UnreadBadgeController(this._db);

  final SupabaseClient _db;

  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  StreamSubscription<List<Map<String, dynamic>>>? _sub1;
  StreamSubscription<List<Map<String, dynamic>>>? _sub2;
  Timer? _fallbackRefreshTimer;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      await refresh();
      return;
    }

    _initialized = true;
    await refresh();

    _fallbackRefreshTimer ??=
        Timer.periodic(const Duration(seconds: 45), (_) => refresh());

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('Unread badge realtime skipped on Android; using polling fallback');
      return;
    }

    _sub1 = _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen(
          (_) => refresh(),
          onError: _handleRealtimeError,
          cancelOnError: false,
        );

    _sub2 = _db
        .from('offer_messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen(
          (_) => refresh(),
          onError: _handleRealtimeError,
          cancelOnError: false,
        );
  }

  void _handleRealtimeError(Object error, [StackTrace? stackTrace]) {
    debugPrint('Unread badge realtime degraded: $error');
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
      // Keep the last known value if refresh fails.
    }
  }

  void dispose() {
    _sub1?.cancel();
    _sub1 = null;
    _sub2?.cancel();
    _sub2 = null;
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = null;
    _initialized = false;
    unread.value = 0;
  }
}
