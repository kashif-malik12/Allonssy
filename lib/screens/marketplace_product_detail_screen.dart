import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/localization/app_localizations.dart';
import '../core/item_condition.dart';
import '../core/market_categories.dart';
import '../models/post_model.dart';
import '../services/mention_service.dart';
import '../services/post_service.dart';
import '../services/reaction_service.dart';
import '../services/saved_post_service.dart';
import '../services/follow_service.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/global_bottom_nav.dart';
import '../widgets/post_media_view.dart';
import '../widgets/share_button.dart';
import '../widgets/tagged_content.dart';

class MarketplaceProductDetailScreen extends StatefulWidget {
  final String postId;
  final int initialTab;
  const MarketplaceProductDetailScreen({
    super.key,
    required this.postId,
    this.initialTab = 0,
  });

  @override
  State<MarketplaceProductDetailScreen> createState() =>
      _MarketplaceProductDetailScreenState();
}

class _MarketplaceProductDetailScreenState
    extends State<MarketplaceProductDetailScreen> {
  final _reactionService = ReactionService(Supabase.instance.client);
  late final SavedPostService _savedPostService;
  late final FollowService _followService;
  final _questionCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  Post? _post;
  bool _isSaved = false;
  bool _isSellerConnected = false;
  bool _isSellerFollowing = false;
  List<Map<String, dynamic>> _qaComments = [];
  bool _qaLoading = false;
  bool _qaSending = false;
  String? _replyToCommentId;
  String? _replyToName;
  String? _replyToUserId;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _savedPostService = SavedPostService(Supabase.instance.client);
    _followService = FollowService(Supabase.instance.client);
    _selectedTab = widget.initialTab;
    _load();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  String _intentLabel(String? intent) {
    switch (intent) {
      case 'buying':
        return 'Buying';
      case 'selling':
        return 'Selling';
      default:
        return (intent ?? '').trim();
    }
  }

  double? _priceFromContent(String raw) {
    final patterns = [
      RegExp(r'price\s*:\s*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
      RegExp(r'price\s*:\s*(?:eur|euro|€|\$)\s*(\d+(?:[.,]\d{1,2})?)',
          caseSensitive: false),
      RegExp(r'(?:eur|euro|€)\s*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
      RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*eur', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      if (match != null) {
        final value = (match.group(1) ?? '').replaceAll(',', '.');
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  String _plainListingText(String raw) {
    return MentionService.parseTaggedContent(raw).body;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final row = await Supabase.instance.client
          .from('posts')
          .select(PostService.postSelect)
          .eq('id', widget.postId)
          .eq('post_type', 'market')
          .maybeSingle();

      if (row == null) {
        throw Exception('Product not found');
      }

      if (!mounted) return;
      setState(() {
        _post = Post.fromMap(row);
      });
      _savedPostService.isSaved(widget.postId).then((saved) {
        if (mounted) setState(() => _isSaved = saved);
      });
      _followService.fetchMyNetworkIds().then((network) {
        if (mounted && _post != null) {
          setState(() {
            _isSellerConnected = network.connectionIds.contains(_post!.userId);
            _isSellerFollowing = network.followingIds.contains(_post!.userId);
          });
        }
      });
      await _loadQa();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleSave() async {
    final l10n = context.l10n;
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);

    try {
      if (wasSaved) {
        await _savedPostService.unsavePost(widget.postId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('listing_unsaved')),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l10n.tr('undo'),
              onPressed: () async {
                try {
                  await _savedPostService.savePost(widget.postId);
                  if (mounted) setState(() => _isSaved = true);
                } catch (_) {}
              },
            ),
          ),
        );
      } else {
        await _savedPostService.savePost(widget.postId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('listing_saved')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaved = wasSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateStatus(String postId, String newStatus) async {
    try {
      await PostService(Supabase.instance.client).updateItemStatus(postId: postId, status: newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('status_updated'))),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    }
  }

  Widget _buildStatusBadge(String status) {
    final l10n = context.l10n;
    final Color bg;
    final Color fg;
    final Color border;
    final String label;

    switch (status.toLowerCase()) {
      case 'sold':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        border = const Color(0xFFD1D5DB);
        label = l10n.tr('sold');
        break;
      case 'reserved':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        border = const Color(0xFFFCD34D);
        label = l10n.tr('reserved');
        break;
      case 'available':
      default:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        border = const Color(0xFF6EE7B7);
        label = l10n.tr('available');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Future<void> _loadQa() async {
    final post = _post;
    if (post == null) return;

    setState(() => _qaLoading = true);
    try {
      final rows = await _reactionService.fetchComments(post.id);
      if (!mounted) return;
      setState(() => _qaComments = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _qaComments = []);
    } finally {
      if (mounted) setState(() => _qaLoading = false);
    }
  }

  Future<void> _sendQuestionOrReply() async {
    final post = _post;
    final text = _questionCtrl.text.trim();
    if (post == null || text.isEmpty || _qaSending) return;

    setState(() => _qaSending = true);
    try {
      await _reactionService.addComment(
        post.id,
        text,
        parentCommentId: _replyToCommentId,
        postOwnerId: post.userId,
        parentCommentUserId: _replyToUserId,
      );
      _questionCtrl.clear();
      if (!mounted) return;
      setState(() {
        _replyToCommentId = null;
        _replyToName = null;
        _replyToUserId = null;
      });
      await _loadQa();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Q&A error: $e')),
      );
    } finally {
      if (mounted) setState(() => _qaSending = false);
    }
  }

  List<Map<String, dynamic>> _questionRoots() {
    return _qaComments
        .where((row) => row['parent_comment_id'] == null)
        .toList();
  }

  List<Map<String, dynamic>> _answersFor(String questionId) {
    return _qaComments
        .where((row) => row['parent_comment_id']?.toString() == questionId)
        .toList();
  }

  String _displayAuthorName(Map<String, dynamic> comment, String ownerId) {
    final userId = comment['user_id']?.toString();
    if (userId == ownerId) return 'Author';
    final profile = comment['profiles'];
    final name = profile is Map ? profile['full_name']?.toString().trim() : null;
    return (name == null || name.isEmpty) ? 'User' : name;
  }

  Widget _buildQaCard({
    required Map<String, dynamic> comment,
    required String ownerId,
    required bool isAnswer,
  }) {
    final displayName = _displayAuthorName(comment, ownerId);
    final content = comment['content']?.toString() ?? '';
    final commentId = comment['id']?.toString() ?? '';
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = myId == ownerId;

    return Container(
      margin: EdgeInsets.only(top: isAnswer ? 8 : 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAnswer ? const Color(0xFFF4EBDD) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAnswer ? const Color(0xFFDCC8AA) : const Color(0xFFE6DDCE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isAnswer ? const Color(0xFF7A5C2E) : const Color(0xFF12211D),
                  ),
                ),
              ),
              if (!isAnswer && isOwner)
                TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedTab = 1;
                          _replyToCommentId = commentId;
                          _replyToName = _displayAuthorName(comment, ownerId);
                          _replyToUserId = comment['user_id']?.toString();
                        });
                      },
                  child: const Text('Reply'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TaggedContent(content: content),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab(Post p, bool canSendOffer) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const Text(
          'Description',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(_plainListingText(p.content)),
        if (canSendOffer) ...[
          const SizedBox(height: 20),
          if (p.itemStatus == 'sold') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.tr('item_sold'),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: p.itemStatus == 'sold'
                  ? null
                  : () => context.push(
                        '/offer-chat/post/${p.id}/user/${p.userId}',
                      ),
              icon: Icon(p.itemStatus == 'sold' ? Icons.check_circle_outline : Icons.local_offer_outlined),
              label: Text(p.itemStatus == 'sold' ? context.l10n.tr('item_sold') : context.l10n.tr('send_offer')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQaTab(Post p) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = myId == p.userId;
    final questions = _questionRoots();

    return Column(
      children: [
        Expanded(
          child: _qaLoading
              ? const Center(child: CircularProgressIndicator())
              : questions.isEmpty
                  ? const Center(child: Text('No questions yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final question = questions[index];
                        final questionId = question['id']?.toString() ?? '';
                        final answers = _answersFor(questionId);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQaCard(
                              comment: question,
                              ownerId: p.userId,
                              isAnswer: false,
                            ),
                            ...answers.map(
                              (answer) => Padding(
                                padding: const EdgeInsets.only(left: 18),
                                child: _buildQaCard(
                                  comment: answer,
                                  ownerId: p.userId,
                                  isAnswer: true,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6DDCE)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyToCommentId != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EBDD),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying as Author to ${_replyToName ?? 'question'}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _replyToCommentId = null;
                                _replyToName = null;
                                _replyToUserId = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _questionCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: isOwner
                          ? (_replyToCommentId == null
                              ? 'Reply to a question from above'
                              : 'Write your answer...')
                          : 'Ask a question about this product...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (isOwner && _replyToCommentId == null) || _qaSending ? null : _sendQuestionOrReply,
                      child: _qaSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isOwner
                                  ? (_replyToCommentId == null ? 'Select a question to answer' : 'Post answer')
                                  : 'Post question',
                            ),
                    ),
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
    final isFrench = context.l10n.isFrench;
    final p = _post;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final canSendOffer = p != null && myId != null && p.userId != myId;
    final effectivePrice =
        p == null ? null : (p.marketPrice ?? _priceFromContent(p.content));
    final priceMax = p?.marketPriceMax;
    final String priceDisplayText = effectivePrice == null
        ? (p?.marketIntent == 'buying' ? 'Looking to buy' : 'Price on request')
        : (priceMax != null && priceMax > effectivePrice
            ? 'EUR ${effectivePrice.toStringAsFixed(2)} – EUR ${priceMax.toStringAsFixed(2)}'
            : 'EUR ${effectivePrice.toStringAsFixed(2)}');

    return Scaffold(
      appBar: GlobalAppBar(
        title: 'Product details',
        showBackIfPossible: true,
        homeRoute: '/feed',
        actions: p == null
            ? null
            : [
                IconButton(
                  icon: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                    color: _isSaved ? const Color(0xFF2563EB) : null,
                  ),
                  tooltip: _isSaved
                      ? context.l10n.tr('remove_saved')
                      : context.l10n.tr('save_listing'),
                  onPressed: _toggleSave,
                ),
                ShareButton(
                  url: marketplaceShareUrl(p.id),
                  title: (p.marketTitle ?? '').trim().isNotEmpty
                      ? p.marketTitle!.trim()
                      : 'Check out this listing on Allonssy',
                ),
              ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : p == null
                  ? const Center(child: Text('Product not found'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if ((p.imageUrl ?? '').isNotEmpty ||
                                  (p.secondImageUrl ?? '').isNotEmpty ||
                                  (p.videoUrl ?? '').isNotEmpty)
                                PostMediaView(
                                  imageUrl: p.imageUrl,
                                  secondImageUrl: p.secondImageUrl,
                                  videoUrl: p.videoUrl,
                                )
                              else
                                SizedBox(
                                  height: 280,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      color: Colors.grey.shade200,
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.image_outlined,
                                        size: 64,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                (p.marketTitle ?? '').trim().isNotEmpty
                                    ? p.marketTitle!.trim()
                                    : _plainListingText(p.content),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    priceDisplayText,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: p.hasDiscount ? const Color(0xFFDC2626) : null,
                                    ),
                                  ),
                                  if (p.hasDiscount && p.originalPrice != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'EUR ${p.originalPrice!.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEBEE),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFFCDD2)),
                                      ),
                                      child: Text(
                                        '-${p.discountPercentage}%',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 10),
                                  _buildStatusBadge(p.itemStatus),
                                  const Spacer(),
                                  if (myId == p.userId)
                                    PopupMenuButton<String>(
                                      tooltip: context.l10n.tr('change_status'),
                                      onSelected: (newStatus) => _updateStatus(p.id, newStatus),
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'available',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.fiber_manual_record, color: Color(0xFF065F46), size: 16),
                                              const SizedBox(width: 8),
                                              Text(context.l10n.tr('mark_as_available')),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'reserved',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.bookmark_outline, color: Color(0xFF92400E), size: 16),
                                              const SizedBox(width: 8),
                                              Text(context.l10n.tr('mark_as_reserved')),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'sold',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle_outline, color: Color(0xFF4B5563), size: 16),
                                              const SizedBox(width: 8),
                                              Text(context.l10n.tr('mark_as_sold')),
                                            ],
                                          ),
                                        ),
                                      ],
                                      child: IgnorePointer(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          onPressed: () {},
                                          icon: const Icon(Icons.swap_horiz, size: 16),
                                          label: Text(context.l10n.tr('change_status')),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (((p.authorCity ?? '').trim().isNotEmpty) ||
                                  ((p.authorZipcode ?? '').trim().isNotEmpty))
                                Text(
                                  'Location: ${((p.authorCity ?? '').trim().isNotEmpty ? p.authorCity!.trim() : p.authorZipcode!.trim())}',
                                ),
                              if (((p.authorCity ?? '').trim().isNotEmpty) ||
                                  ((p.authorZipcode ?? '').trim().isNotEmpty))
                                const SizedBox(height: 8),
                              if ((p.marketCategory ?? '').isNotEmpty)
                                Text(
                                  '${isFrench ? 'Catégorie' : 'Category'}: ${marketCategoryLabel(p.marketCategory!, isFrench: isFrench)}',
                                ),
                              if ((p.marketIntent ?? '').isNotEmpty)
                                Text('Type: ${_intentLabel(p.marketIntent)}'),
                              if ((p.itemCondition ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text('${context.l10n.tr('item_condition')}: '),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBAE6FD)),
                                      ),
                                      child: Text(
                                        itemConditionLabel(p.itemCondition, context.l10n),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () => context.push('/p/${p.userId}'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage: (p.authorAvatarUrl != null && p.authorAvatarUrl!.isNotEmpty)
                                            ? NetworkImage(p.authorAvatarUrl!)
                                            : null,
                                        child: (p.authorAvatarUrl == null || p.authorAvatarUrl!.isEmpty)
                                            ? const Icon(Icons.person, size: 18)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          (p.authorName ?? '').trim().isNotEmpty ? p.authorName!.trim() : 'Seller',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                      if (_isSellerConnected) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.hub_outlined, size: 12, color: Color(0xFF047857)),
                                              const SizedBox(width: 4),
                                              Text(
                                                context.l10n.tr('connected_badge'),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF047857),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else if (_isSellerFollowing) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check, size: 12, color: Color(0xFF1D4ED8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                context.l10n.tr('following_badge'),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1D4ED8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SegmentedButton<int>(
                                segments: const [
                                  ButtonSegment<int>(
                                    value: 0,
                                    label: Text('Description'),
                                    icon: Icon(Icons.info_outline),
                                  ),
                                  ButtonSegment<int>(
                                    value: 1,
                                    label: Text('Q&A'),
                                    icon: Icon(Icons.forum_outlined),
                                  ),
                                ],
                                selected: {_selectedTab},
                                onSelectionChanged: (value) {
                                  setState(() => _selectedTab = value.first);
                                },
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 420,
                                child: _selectedTab == 0
                                    ? _buildDescriptionTab(p, canSendOffer)
                                    : _buildQaTab(p),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}
