import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../core/utils/youtube_utils.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/reaction_service.dart';
import 'network_video_player.dart';

class MobileVideoFeed extends StatefulWidget {
  const MobileVideoFeed({super.key});

  @override
  State<MobileVideoFeed> createState() => _MobileVideoFeedState();
}

class _MobileVideoFeedState extends State<MobileVideoFeed> {
  final _pageController = PageController();

  bool _loading = true;
  String? _error;
  String _scope = 'following';
  List<Post> _posts = [];
  int _profileRadiusKm = 5;
  final ReactionService _reactionService =
      ReactionService(Supabase.instance.client);
  final Map<String, bool> _likedByMe = {};
  final Map<String, int> _likeCounts = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadProfileRadius();
    await _load();
  }

  bool _isYoutubeUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.contains('youtu.be');
  }

  Future<void> _openYoutubeVideo(String videoUrl) async {
    final videoId = extractYoutubeId(videoUrl);
    final targetUrl =
        videoId == null ? videoUrl.trim() : youtubeWatchUrlFromId(videoId);
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open YouTube video.')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open YouTube video.')),
      );
    }
  }

  String _serviceScope() {
    switch (_scope) {
      case 'public':
        return 'public';
      case 'trending':
        return 'public';
      case 'nearby':
        return 'all';
      case 'following':
      default:
        return 'following';
    }
  }

  Future<void> _loadProfileRadius() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final me = await Supabase.instance.client
          .from('profiles')
          .select('radius_km')
          .eq('id', user.id)
          .maybeSingle();
      final radius = (me?['radius_km'] as num?)?.toInt();
      if (!mounted || radius == null) return;
      setState(() => _profileRadiusKm = radius);
    } catch (_) {
      // keep default radius
    }
  }

  Future<void> _primeReactions(List<Post> posts) async {
    final liked = <String, bool>{};
    final counts = <String, int>{};
    await Future.wait(
      posts.map((post) async {
        final values = await Future.wait<dynamic>([
          _reactionService.isLiked(post.id),
          _reactionService.likesCount(post.id),
        ]);
        liked[post.id] = values[0] as bool;
        counts[post.id] = values[1] as int;
      }),
    );

    if (!mounted) return;
    setState(() {
      _likedByMe
        ..clear()
        ..addAll(liked);
      _likeCounts
        ..clear()
        ..addAll(counts);
      if (_scope == 'trending') {
        _posts.sort((a, b) => (_likeCounts[b.id] ?? 0).compareTo(_likeCounts[a.id] ?? 0));
      }
    });
  }

  Future<void> _toggleLike(Post post) async {
    final liked = _likedByMe[post.id] ?? false;
    final count = _likeCounts[post.id] ?? 0;

    if (mounted) {
      setState(() {
        _likedByMe[post.id] = !liked;
        _likeCounts[post.id] = liked ? (count > 0 ? count - 1 : 0) : count + 1;
      });
    }

    try {
      if (liked) {
        await _reactionService.unlike(post.id);
      } else {
        await _reactionService.like(post.id);
      }
      final refreshed = await _reactionService.likesCount(post.id);
      final refreshedLiked = await _reactionService.isLiked(post.id);
      if (!mounted) return;
      setState(() {
        _likeCounts[post.id] = refreshed;
        _likedByMe[post.id] = refreshedLiked;
        if (_scope == 'trending') {
          _posts.sort((a, b) => (_likeCounts[b.id] ?? 0).compareTo(_likeCounts[a.id] ?? 0));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _likedByMe[post.id] = liked;
        _likeCounts[post.id] = count;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await PostService(Supabase.instance.client).fetchPublicFeed(
        limit: 80,
        scope: _serviceScope(),
        radiusKmOverride: _scope == 'nearby' ? _profileRadiusKm : null,
      );
      final hydrated = await PostService(Supabase.instance.client).attachSharedPosts(rows);
      final posts = hydrated
          .map((row) => Post.fromMap(row))
          .where((post) => (post.videoUrl ?? '').trim().isNotEmpty && (post.sharedPostId ?? '').isEmpty)
          .toList();

      if (!mounted) return;
      setState(() => _posts = posts);
      await _primeReactions(posts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _scopeChip({
    required String value,
    required String label,
  }) {
    final selected = _scope == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        if (_scope == value) return;
        setState(() => _scope = value);
        _load();
      },
      label: Text(label),
      selectedColor: const Color(0xFF0F766E),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF17322C),
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF0F766E) : const Color(0xFFD8C8AF),
      ),
      backgroundColor: const Color(0xFFF7F0E4),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    if (_isYoutubeUrl(videoUrl)) {
      return _InlineYoutubePlayer(
        videoUrl: videoUrl,
        autoplay: true,
        muteTopOffset: 120,
      );
    }
    return NetworkVideoPlayer(
      videoUrl: videoUrl,
      maxHeight: double.infinity,
      startMuted: true,
      showMuteToggle: true,
      autoplay: true,
      muteTopOffset: 120,
    );
  }

  Widget _buildPostCard(Post post) {
    final isYoutubePost = _isYoutubeUrl(post.videoUrl);
    final liked = _likedByMe[post.id] ?? false;
    final likes = _likeCounts[post.id] ?? 0;
    final openLabel = post.postType == 'market'
        ? 'Open product'
        : post.postType == 'service_offer' || post.postType == 'service_request'
            ? 'Open gig'
            : post.postType == 'food' || post.postType == 'food_ad'
                ? 'Open food'
                : 'Open';
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black, child: _buildVideoPlayer(post.videoUrl!.trim())),
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99000000),
                Color(0x11000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xAA000000),
              ],
              stops: [0.0, 0.14, 0.45, 0.62, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: (post.authorAvatarUrl ?? '').isNotEmpty
                        ? NetworkImage(post.authorAvatarUrl!)
                        : null,
                    child: (post.authorAvatarUrl ?? '').isEmpty
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => context.push('/p/${post.userId}'),
                          child: Text(
                            post.authorName ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.locationName?.trim().isNotEmpty == true
                              ? post.locationName!.trim()
                              : (_scope == 'nearby'
                                  ? 'Nearby videos within $_profileRadiusKm km'
                                  : 'Video feed'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.distanceKm != null && _scope == 'nearby')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${post.distanceKm!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 24,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.26),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post.content.trim().isNotEmpty)
                    Text(
                      post.content.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _scopeChip(value: 'following', label: 'Following'),
                        const SizedBox(width: 8),
                        _scopeChip(
                          value: 'nearby',
                          label: 'Radius $_profileRadiusKm km',
                        ),
                        const SizedBox(width: 8),
                        _scopeChip(value: 'public', label: 'Public'),
                        const SizedBox(width: 8),
                        _scopeChip(value: 'trending', label: 'Trending'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _toggleLike(post),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.24),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                liked ? Icons.favorite : Icons.favorite_border,
                                size: 14,
                                color: liked ? const Color(0xFFFF6B81) : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$likes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.35),
                            ),
                            backgroundColor: Colors.black.withOpacity(0.18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 34),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => context.push('/post/${post.id}'),
                          child: Text(openLabel),
                        ),
                      ),
                      if (isYoutubePost) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.35),
                              ),
                              backgroundColor: Colors.black.withOpacity(0.18),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 34),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => _openYoutubeVideo(post.videoUrl!.trim()),
                            icon: const Icon(
                              Icons.smart_display_outlined,
                              size: 14,
                            ),
                            label: const Text('YouTube'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08111C),
      child: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Video feed error:\n$_error',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _posts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No videos found for this filter yet.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            scrollDirection: Axis.vertical,
                            itemCount: _posts.length,
                            itemBuilder: (_, index) => _buildPostCard(_posts[index]),
                          ),
          ),
        ],
      ),
    );
  }
}

class _InlineYoutubePlayer extends StatefulWidget {
  const _InlineYoutubePlayer({
    required this.videoUrl,
    this.autoplay = false,
    this.muteTopOffset = 12,
  });

  final String videoUrl;
  final bool autoplay;
  final double muteTopOffset;

  @override
  State<_InlineYoutubePlayer> createState() => _InlineYoutubePlayerState();
}

class _InlineYoutubePlayerState extends State<_InlineYoutubePlayer> {
  YoutubePlayerController? _controller;
  bool _failed = false;
  bool _muted = true;
  late final bool _autoplay;

  @override
  void initState() {
    super.initState();
    final videoId = extractYoutubeId(widget.videoUrl);
    if (videoId == null) {
      _failed = true;
      return;
    }
    _autoplay = widget.autoplay;

    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        mute: true,
        strictRelatedVideos: true,
        playsInline: true,
      ),
    );
    if (_autoplay) {
      controller.loadVideoById(videoId: videoId);
    } else {
      controller.cueVideoById(videoId: videoId);
    }
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        color: Colors.black,
        child: const Text(
          'YouTube video unavailable in app',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return YoutubePlayerScaffold(
      controller: controller,
      builder: (context, player) {
        return Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: player,
            ),
            Positioned(
              top: widget.muteTopOffset,
              right: 12,
              child: Material(
                color: Colors.black.withOpacity(0.5),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (_muted) {
                      controller.unMute();
                    } else {
                      controller.mute();
                    }
                    setState(() => _muted = !_muted);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
