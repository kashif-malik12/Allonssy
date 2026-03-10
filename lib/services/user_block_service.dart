import 'package:supabase_flutter/supabase_flutter.dart';

class UserBlockService {
  final SupabaseClient _db;

  UserBlockService(this._db);

  Future<void> blockUser(String blockedUserId) async {
    final me = _db.auth.currentUser?.id;
    if (me == null) throw Exception('Not logged in');
    if (blockedUserId.isEmpty || blockedUserId == me) {
      throw Exception('Invalid user');
    }

    try {
      await _db.from('user_blocks').insert({
        'blocker_id': me,
        'blocked_id': blockedUserId,
      });
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if ((e.code ?? '') == '23505' || message.contains('duplicate')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> unblockUser(String blockedUserId) async {
    final me = _db.auth.currentUser?.id;
    if (me == null) throw Exception('Not logged in');
    await _db
        .from('user_blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', blockedUserId);
  }

  Future<Set<String>> fetchBlockedRelatedUserIds() async {
    final me = _db.auth.currentUser?.id;
    if (me == null) return <String>{};

    final rows = await _db
        .from('user_blocks')
        .select('blocker_id, blocked_id')
        .or('blocker_id.eq.$me,blocked_id.eq.$me');

    final ids = <String>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final blockerId = (row['blocker_id'] ?? '').toString();
      final blockedId = (row['blocked_id'] ?? '').toString();
      if (blockerId.isNotEmpty && blockerId != me) ids.add(blockerId);
      if (blockedId.isNotEmpty && blockedId != me) ids.add(blockedId);
    }
    return ids;
  }

  Future<bool> isBlockedEitherWay(String otherUserId) async {
    final ids = await fetchBlockedRelatedUserIds();
    return ids.contains(otherUserId);
  }
}
