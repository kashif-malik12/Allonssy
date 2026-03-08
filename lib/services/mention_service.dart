import 'package:supabase_flutter/supabase_flutter.dart';

class MentionCandidate {
  final String id;
  final String name;
  final String? avatarUrl;

  const MentionCandidate({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory MentionCandidate.fromMap(Map<String, dynamic> map) {
    final rawName = (map['full_name'] ?? '').toString().trim();
    return MentionCandidate(
      id: (map['id'] ?? '').toString(),
      name: rawName.isEmpty ? 'Unknown' : rawName,
      avatarUrl: map['avatar_url']?.toString(),
    );
  }
}

class ParsedMentionTag {
  final String name;
  final String? userId;

  const ParsedMentionTag({
    required this.name,
    this.userId,
  });
}

class ParsedTaggedContent {
  final List<ParsedMentionTag> tags;
  final String body;

  const ParsedTaggedContent({
    required this.tags,
    required this.body,
  });
}

class MentionService {
  MentionService(this._db);

  final SupabaseClient _db;

  String? get _me => _db.auth.currentUser?.id;

  Future<List<MentionCandidate>> fetchMutualConnections() async {
    final me = _me;
    if (me == null) return const [];

    final results = await Future.wait([
      _db
          .from('follows')
          .select('followed_profile_id')
          .eq('follower_id', me)
          .eq('status', 'accepted'),
      _db
          .from('follows')
          .select('follower_id')
          .eq('followed_profile_id', me)
          .eq('status', 'accepted'),
    ]);

    final followingIds = (results[0] as List)
        .map((row) => (row as Map<String, dynamic>)['followed_profile_id']?.toString())
        .whereType<String>()
        .toSet();
    final followerIds = (results[1] as List)
        .map((row) => (row as Map<String, dynamic>)['follower_id']?.toString())
        .whereType<String>()
        .toSet();

    final mutualIds = followingIds.intersection(followerIds)..remove(me);
    if (mutualIds.isEmpty) return const [];

    final rows = await _db
        .from('profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', mutualIds.toList());

    final items = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MentionCandidate.fromMap)
        .where((item) => item.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return items;
  }

  Future<List<String>> filterAllowedUserIds(List<String> userIds) async {
    if (userIds.isEmpty) return const [];

    final allowed = (await fetchMutualConnections()).map((e) => e.id).toSet();
    return userIds.where(allowed.contains).toSet().toList();
  }

  String composeTaggedContent(String content, List<MentionCandidate> mentions) {
    final trimmed = content.trim();
    if (mentions.isEmpty) return trimmed;

    final cleanMentions = mentions.where((m) => m.name.trim().isNotEmpty).toList();
    if (cleanMentions.isEmpty) return trimmed;

    final names = cleanMentions.map((m) => m.name.trim()).join(', ');
    final ids = cleanMentions.map((m) => m.id).join(',');
    return 'Tagged: $names\nTagIds: $ids\n\n$trimmed';
  }

  static ParsedTaggedContent parseTaggedContent(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (!normalized.startsWith('Tagged: ')) {
      return ParsedTaggedContent(tags: const [], body: normalized);
    }

    final lines = normalized.split('\n');
    final rawNames = lines.first.substring('Tagged: '.length).trim();
    final names = rawNames
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    final ids = <String>[];
    var bodyStartIndex = 1;

    if (lines.length > 1 && lines[1].startsWith('TagIds: ')) {
      ids.addAll(
        lines[1]
            .substring('TagIds: '.length)
            .split(',')
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty),
      );
      bodyStartIndex = 2;
    }

    while (bodyStartIndex < lines.length && lines[bodyStartIndex].trim().isEmpty) {
      bodyStartIndex++;
    }

    final tags = <ParsedMentionTag>[];
    for (var i = 0; i < names.length; i++) {
      tags.add(
        ParsedMentionTag(
          name: names[i],
          userId: i < ids.length ? ids[i] : null,
        ),
      );
    }

    final body = lines.skip(bodyStartIndex).join('\n').trim();
    return ParsedTaggedContent(tags: tags, body: body);
  }
}
