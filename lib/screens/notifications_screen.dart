// lib/screens/notifications_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/notifications/providers/notification_unread_provider.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/follow_service.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/global_bottom_nav.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _db = Supabase.instance.client;
  late final NotificationService _svc;
  late final FollowService _followSvc;

  final _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  List<AppNotification> _items = [];

  static const int _pageSize = 25;
  int _offset = 0;

  RealtimeChannel? _channel;
  Timer? _debounce;

  // ✅ Prevent double taps on Accept/Decline
  final Set<String> _actingIds = {};

  @override
  void initState() {
    super.initState();
    _svc = NotificationService(_db);
    _followSvc = FollowService(_db);

    _scrollCtrl.addListener(_onScroll);
    _refreshFirstPage();

    _channel = _svc.subscribeToMyNotifications(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        await _refreshFirstPage(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _debounce?.cancel();
    final ch = _channel;
    _channel = null;
    if (ch != null) _svc.unsubscribe(ch);
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 250) {
      _loadMore();
    }
  }

  Future<void> _refreshFirstPage({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (mounted) setState(() => _error = null);
    }

    try {
      _offset = 0;
      final rows = await _svc.fetchPage(from: 0, to: _pageSize - 1);
      final page = rows.map(AppNotification.fromMap).toList();

      if (!mounted) return;
      setState(() {
        _items = page;
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);

    try {
      final nextFrom = _offset + _pageSize;
      final nextTo = nextFrom + _pageSize - 1;

      final rows = await _svc.fetchPage(from: nextFrom, to: nextTo);
      final page = rows.map(AppNotification.fromMap).toList();

      if (!mounted) return;
      setState(() {
        _offset = nextFrom;
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load more failed: $e')),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _svc.markAllRead();
      ref.read(notificationUnreadProvider.notifier).clear();
      final now = DateTime.now();
      setState(() {
        _items = _items
            .map((n) => n.readAt == null
                ? AppNotification(
                    id: n.id,
                    recipientId: n.recipientId,
                    type: n.type,
                    createdAt: n.createdAt,
                    actorId: n.actorId,
                    postId: n.postId,
                    commentId: n.commentId,
                    readAt: now,
                    actorName: n.actorName,
                    actorAvatarUrl: n.actorAvatarUrl,
                  )
                : n)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _onTap(AppNotification n) async {
    // mark read (best-effort)
    if (n.readAt == null) {
      try {
        await _svc.markRead(n.id);
        ref.read(notificationUnreadProvider.notifier).decrement();
        if (mounted) {
          setState(() {
            _items = _items.map((x) {
              if (x.id != n.id) return x;
              return AppNotification(
                id: x.id,
                recipientId: x.recipientId,
                type: x.type,
                createdAt: x.createdAt,
                actorId: x.actorId,
                postId: x.postId,
                commentId: x.commentId,
                readAt: DateTime.now(),
                actorName: x.actorName,
                actorAvatarUrl: x.actorAvatarUrl,
              );
            }).toList();
          });
        }
      } catch (_) {}
    }

    // navigation
    if ((n.type == 'follow_request' || n.type == 'follow' || n.type == 'follow_accepted') &&
        n.actorId != null) {
      if (!mounted) return;
      context.push('/p/${n.actorId}');
      return;
    }

    if ((n.type == 'like' || n.type == 'comment' || n.type == 'share') && n.postId != null) {
      if (!mounted) return;
      context.push('/post/${n.postId}');
      return;
    }

    if ((n.type == 'comment_like' || n.type == 'comment_reply') && n.postId != null) {
      if (!mounted) return;
      context.push('/post/${n.postId}/comments');
      return;
    }

    if (n.type == 'mention' && n.postId != null) {
      if (!mounted) return;
      if (n.commentId != null && n.commentId!.isNotEmpty) {
        context.push('/post/${n.postId}/comments');
      } else {
        context.push('/post/${n.postId}');
      }
      return;
    }

    if ((n.type == 'offer_message' ||
            n.type == 'offer_sent' ||
            n.type == 'offer_accepted' ||
            n.type == 'offer_rejected') &&
        n.postId != null) {
      final post = await _db
          .from('posts')
          .select('post_type')
          .eq('id', n.postId!)
          .maybeSingle();

      final postType = (post?['post_type'] as String?) ?? '';
      if (!mounted) return;

      if (postType == 'market') {
        context.push('/marketplace/product/${n.postId}');
        return;
      }
      if (postType == 'service_offer' || postType == 'service_request') {
        context.push('/gigs/service/${n.postId}');
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to open')),
    );
  }

  Future<void> _acceptRequest(AppNotification n) async {
    final requesterId = n.actorId;
    if (requesterId == null) return;

    if (_actingIds.contains(n.id)) return;
    setState(() => _actingIds.add(n.id));

    try {
      await _followSvc.acceptRequest(requesterId);

      // mark read (best effort)
      try {
        await _svc.markRead(n.id);
        ref.read(notificationUnreadProvider.notifier).decrement();
      } catch (_) {}

      // remove immediately
      if (mounted) {
        setState(() {
          _items.removeWhere((x) => x.id == n.id);
          _actingIds.remove(n.id);
        });
      }

      await _refreshFirstPage(silent: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actingIds.remove(n.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  Future<void> _declineRequest(AppNotification n) async {
    final requesterId = n.actorId;
    if (requesterId == null) return;

    if (_actingIds.contains(n.id)) return;
    setState(() => _actingIds.add(n.id));

    try {
      await _followSvc.declineRequest(requesterId);

      // mark read (best effort)
      try {
        await _svc.markRead(n.id);
        ref.read(notificationUnreadProvider.notifier).decrement();
      } catch (_) {}

      // remove immediately
      if (mounted) {
        setState(() {
          _items.removeWhere((x) => x.id == n.id);
          _actingIds.remove(n.id);
        });
      }

      await _refreshFirstPage(silent: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request declined')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actingIds.remove(n.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Decline failed: $e')),
      );
    }
  }

  String _titleFor(AppNotification n) {
    final name = (n.actorName?.trim().isNotEmpty ?? false) ? n.actorName!.trim() : 'Someone';

    switch (n.type) {
      case 'follow_request':
        return '$name requested to follow you';
      case 'follow_accepted':
        return '$name accepted your follow request';
      case 'follow':
        return '$name started following you';
      case 'like':
        return '$name liked your post';
      case 'comment':
        return '$name commented on your post';
      case 'comment_like':
        return '$name liked your comment';
      case 'comment_reply':
        return '$name replied to your comment';
      case 'share':
        return '$name shared your post';
      case 'mention':
        return n.commentId != null && n.commentId!.isNotEmpty
            ? '$name mentioned you in a comment'
            : '$name mentioned you in a post';
      case 'offer_message':
        return '$name sent a message about your listing';
      case 'offer_sent':
        return '$name sent an offer on your listing';
      case 'offer_accepted':
        return '$name accepted the offer';
      case 'offer_rejected':
        return '$name rejected the offer';
      default:
        return '$name sent an update';
    }
  }

  String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = dt.toLocal();
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _avatar(String? url) {
    if (url == null || url.trim().isEmpty) {
      return const CircleAvatar(child: Icon(Icons.person));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }

  Widget _buildNotificationCard(AppNotification n) {
    final isActing = _actingIds.contains(n.id);
    final isActionableRequest = n.type == 'follow_request' && n.readAt == null;
    final isUnread = n.readAt == null;
    final statusColor = isUnread ? const Color(0xFF0B5D56) : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFEAF7F3) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUnread ? const Color(0xFF0F766E).withOpacity(0.55) : const Color(0xFFE6DDCE),
          width: isUnread ? 1.4 : 1,
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: const Color(0xFF0F766E).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: isActionableRequest ? null : () => _onTap(n),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: _avatar(n.actorAvatarUrl),
                  ),
                  if (isUnread)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titleFor(n),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnread ? const Color(0xFF0B5D56) : const Color(0xFF12211D),
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8EFE8),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFF8EC5B7)),
                            ),
                            child: const Text(
                              'Unread',
                              style: TextStyle(
                                color: Color(0xFF0B5D56),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatTime(n.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (isUnread && !isActionableRequest) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tap to open',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                    if (isActionableRequest) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: isActing ? null : () => _declineRequest(n),
                            child: const Text('Decline'),
                          ),
                          FilledButton(
                            onPressed: isActing ? null : () => _acceptRequest(n),
                            child: isActing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!isActionableRequest)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.chevron_right),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((e) => e.readAt == null).length;

    return Scaffold(
      appBar: GlobalAppBar(
        title: unread > 0 ? 'Notifications ($unread)' : 'Notifications',
        showBackIfPossible: true,
        homeRoute: '/feed',
        actions: [
          if (_items.isNotEmpty && unread > 0)
            TextButton(onPressed: _markAllRead, child: const Text('Mark all read')),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: RefreshIndicator(
        onRefresh: () => _refreshFirstPage(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFCF7), Color(0xFFF4EBDD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE6DDCE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unread > 0 ? 'Notifications ($unread)' : 'Notifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stay on top of follows, messages, offers, and updates.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  )
                else if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE6DDCE)),
                    ),
                    child: const Center(child: Text('No notifications yet')),
                  )
                else
                  ..._items.map(_buildNotificationCard),
                if (_items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: Center(
                      child: !_hasMore
                          ? const SizedBox.shrink()
                          : _loadingMore
                              ? const CircularProgressIndicator()
                              : const Text('Scroll down to load more'),
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
