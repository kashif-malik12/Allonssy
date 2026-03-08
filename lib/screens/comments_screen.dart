import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mention_service.dart';
import '../services/reaction_service.dart';
import '../widgets/global_bottom_nav.dart';
import '../widgets/mention_picker_sheet.dart';
import '../widgets/tagged_content.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _svc = ReactionService(Supabase.instance.client);
  final _ctrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _mentionSvc = MentionService(Supabase.instance.client);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _comments = [];
  String? _replyToCommentId;
  String? _replyToUserId;
  String? _replyToName;
  List<MentionCandidate> _selectedMentions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _svc.fetchComments(widget.postId);
      setState(() => _comments = rows);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final rawText = _ctrl.text.trim();
    if (rawText.isEmpty) return;

    try {
      final postOwnerId = _comments.isNotEmpty ? (_comments.first['post_owner_id']?.toString()) : null;
      final allowedTagIds =
          await _mentionSvc.filterAllowedUserIds(_selectedMentions.map((e) => e.id).toList());
      await _svc.addComment(
        widget.postId,
        _mentionSvc.composeTaggedContent(rawText, _selectedMentions),
        parentCommentId: _replyToCommentId,
        postOwnerId: postOwnerId,
        parentCommentUserId: _replyToUserId,
        taggedUserIds: allowedTagIds,
      );
      _ctrl.clear();
      setState(() {
        _replyToCommentId = null;
        _replyToUserId = null;
        _replyToName = null;
        _selectedMentions = const [];
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment error: $e')),
      );
    }
  }

  Future<void> _pickMentions() async {
    try {
      final connections = await _mentionSvc.fetchMutualConnections();
      if (!mounted) return;
      if (connections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No mutual connections available to tag')),
        );
        return;
      }

      final selected = await showMentionPickerSheet(
        context: context,
        available: connections,
        initialSelection: _selectedMentions,
        title: 'Tag connections',
      );

      if (selected != null && mounted) {
        setState(() => _selectedMentions = selected);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tag loading failed: $e')),
      );
    }
  }

  List<_CommentView> _visibleComments() {
    final byParent = <String?, List<Map<String, dynamic>>>{};
    for (final comment in _comments) {
      final parentId = comment['parent_comment_id']?.toString();
      byParent.putIfAbsent(parentId, () => []).add(comment);
    }

    final output = <_CommentView>[];

    void visit(String? parentId, int depth) {
      final children = byParent[parentId] ?? const [];
      for (final comment in children) {
        output.add(_CommentView(comment: comment, depth: depth));
        visit(comment['id']?.toString(), depth + 1);
      }
    }

    visit(null, 0);
    return output;
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, String? me, int depth) {
    final profile = comment['profiles'];
    final name = (profile is Map ? profile['full_name'] : null) ?? 'Unknown';
    final avatarUrl = profile is Map ? profile['avatar_url']?.toString() : null;
    final userId = comment['user_id']?.toString();
    final mine = me != null && comment['user_id']?.toString() == me;
    final likeCount = (comment['like_count'] as num?)?.toInt() ?? 0;
    final likedByMe = comment['liked_by_me'] == true;
    final commentId = (comment['id'] ?? '').toString();
    final postId = (comment['post_id'] ?? widget.postId).toString();

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFF4EBDD) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6DDCE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: userId == null || userId.isEmpty ? null : () => context.push('/p/$userId'),
              borderRadius: BorderRadius.circular(999),
              child: CircleAvatar(
                radius: 18,
                backgroundImage:
                    avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        name.toString().trim().isEmpty
                            ? '?'
                            : name.toString().trim()[0].toUpperCase(),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: userId == null || userId.isEmpty ? null : () => context.push('/p/$userId'),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              name.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      if (mine)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TaggedContent(content: comment['content']?.toString() ?? ''),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      TextButton.icon(
                        onPressed: commentId.isEmpty || userId == null || userId.isEmpty
                            ? null
                            : () async {
                                try {
                                  if (likedByMe) {
                                    await _svc.unlikeComment(commentId);
                                  } else {
                                    await _svc.likeComment(
                                      commentId: commentId,
                                      postId: postId,
                                      commentOwnerId: userId,
                                    );
                                  }
                                  await _load();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Comment like error: $e')),
                                  );
                                }
                              },
                        icon: Icon(
                          likedByMe ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                        ),
                        label: Text('$likeCount'),
                      ),
                      TextButton.icon(
                        onPressed: commentId.isEmpty || userId == null || userId.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _replyToCommentId = commentId;
                                  _replyToUserId = userId;
                                  _replyToName = name.toString();
                                });
                                _inputFocus.requestFocus();
                              },
                        icon: const Icon(Icons.reply_outlined, size: 18),
                        label: const Text('Reply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (mine) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Delete comment',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  await _svc.deleteComment(comment['id'].toString());
                  await _load();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final theme = Theme.of(context);
    final visibleComments = _visibleComments();

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFBF8F2), Color(0xFFF2EEE5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE6DDCE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Post comments',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_comments.length} ${_comments.length == 1 ? 'comment' : 'comments'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Error:\n$_error'),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(12),
                                itemCount: visibleComments.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => _buildCommentItem(
                                  visibleComments[i].comment,
                                  me,
                                  visibleComments[i].depth,
                                ),
                              ),
                            ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE6DDCE)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedMentions.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedMentions
                                    .map(
                                      (mention) => InputChip(
                                        label: Text(mention.name),
                                        backgroundColor: const Color(0xFFF4EBDD),
                                        side: const BorderSide(color: Color(0xFFD8C8AF)),
                                        labelStyle: const TextStyle(
                                          color: Color(0xFF12211D),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        deleteIconColor: const Color(0xFF7A5C2E),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedMentions = _selectedMentions
                                                .where((item) => item.id != mention.id)
                                                .toList();
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (_replyToCommentId != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4EBDD),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Replying to ${_replyToName ?? 'comment'}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setState(() {
                                        _replyToCommentId = null;
                                        _replyToUserId = null;
                                        _replyToName = null;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _pickMentions,
                                tooltip: 'Tag connections',
                                icon: const Icon(Icons.alternate_email),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  focusNode: _inputFocus,
                                  minLines: 1,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(),
                                  decoration: InputDecoration(
                                    hintText: _replyToCommentId == null
                                        ? 'Write a comment...'
                                        : 'Write a reply...',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: _send,
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: Text(_replyToCommentId == null ? 'Send' : 'Reply'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentView {
  final Map<String, dynamic> comment;
  final int depth;

  const _CommentView({
    required this.comment,
    required this.depth,
  });
}
