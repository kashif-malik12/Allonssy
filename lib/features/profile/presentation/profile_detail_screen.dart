import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/business_categories.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/restaurant_categories.dart';
import '../../../models/post_model.dart';
import '../../../models/portfolio_item.dart';
import '../../../services/reaction_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/portfolio_service.dart';
import '../../../services/post_service.dart';
import '../../../services/favorite_business_service.dart';
import '../../../core/item_condition.dart';
import '../../../screens/feedback_screen.dart';
import '../../../widgets/share_button.dart';
import '../../../widgets/global_app_bar.dart';
import '../../../widgets/global_bottom_nav.dart';
import '../../../widgets/post_media_view.dart';
import '../../../widgets/tagged_content.dart';
import '../../../widgets/report_post_sheet.dart'; // ✅ NEW
import '../../../widgets/report_user_sheet.dart'; // ✅ NEW

enum ProfileTab { posts, marketplace, services }

class ProfileDetailScreen extends StatefulWidget {
  final String profileId; // ✅ in your app this equals auth uid
  const ProfileDetailScreen({super.key, required this.profileId});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final _db = Supabase.instance.client;
  final _favService = FavoriteBusinessService();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  bool _isMe = false;
  bool _isFavorite = false;
  FollowStatus _followStatus = FollowStatus.none;

  bool get _isBusinessOrRestaurant =>
      _profile?['account_type'] == 'business' || _profile?['is_restaurant'] == true;

  // ✅ Messaging permission (mutual follow)
  bool _canMessage = false;
  bool _canMessageLoading = true;

  int _followersCount = 0;
  int _followingCount = 0;
  int _connectionsCount = 0;

  // ✅ Follow requests badge (only for me)
  int _pendingRequests = 0;
  RealtimeChannel? _reqChannel;

  // ✅ Posts on profile
  ProfileTab _selectedProfileTab = ProfileTab.posts;
  bool _postsLoading = true;
  String? _postsError;
  List<Post> _posts = [];
  int _postsPage = 0;
  bool _postsHasMore = true;
  bool _postsLoadingMore = false;

  // ✅ Marketplace listings on profile
  bool _marketPostsLoading = true;
  String? _marketPostsError;
  List<Post> _marketPosts = [];

  // ✅ Gigs & Services on profile
  bool _servicePostsLoading = true;
  String? _servicePostsError;
  List<Post> _servicePosts = [];

  // ✅ Portfolio (business/org only)
  bool _portfolioLoading = true;
  String? _portfolioError;
  List<PortfolioItem> _portfolio = [];
  bool _portfolioActionLoading = false;
  bool _showMyProfileActions = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required String name,
    required String type,
    required String location,
    required String bio,
    required bool canOpenLists,
  }) {
    final l10n = context.l10n;
    final entityName = _profileEntityName();
    final categoryLabel = _profileCategoryLabel(isFrench: l10n.isFrench);
    final roleTitle = _profileRoleTitle();
    final businessDescription = _profileBusinessDescription();
    return Container(
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
          // Avatar
          Builder(builder: (context) {
            final avatarUrl = (_profile?['avatar_url'] ?? '').toString().trim();
            return Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ],
            );
          }),
          const SizedBox(height: 14),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (entityName != null) ...[
            const SizedBox(height: 4),
            Text(
              entityName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (categoryLabel != null || roleTitle != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (categoryLabel != null) _ProfileMetaChip(label: categoryLabel),
                if (roleTitle != null) _ProfileMetaChip(label: roleTitle),
              ],
            ),
          ],
          if (type.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.tr('type', args: {'value': type}),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.tr('location', args: {'value': location}),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(bio),
          ],
          if (businessDescription != null) ...[
            const SizedBox(height: 10),
            Text(
              businessDescription,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _clickableStat(
                  enabled: canOpenLists,
                  onTap: canOpenLists
                      ? () => context.push('/p/${widget.profileId}/followers')
                      : null,
                  child: _StatTile(
                    label: l10n.tr('followers'),
                    value: _followersCount,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _clickableStat(
                  enabled: canOpenLists,
                  onTap: canOpenLists
                      ? () => context.push('/p/${widget.profileId}/following')
                      : null,
                  child: _StatTile(
                    label: l10n.tr('following'),
                    value: _followingCount,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _clickableStat(
                  enabled: _isMe,
                  onTap: _isMe ? () => context.push('/p/${widget.profileId}/connections') : null,
                  child: _StatTile(
                    label: l10n.tr('connections'),
                    value: _connectionsCount,
                  ),
                ),
              ),
            ],
          ),
          if (!canOpenLists) ...[
            const SizedBox(height: 8),
            Text(
              l10n.tr('followers_following_private'),
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
          ],
          if (!_isMe) ...[
            const SizedBox(height: 16),
            if (!_canMessageLoading && _canMessage) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/chat/user/${widget.profileId}'),
                  icon: const Icon(Icons.message_outlined),
                  label: Text(l10n.tr('message')),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_loading || _followStatus == FollowStatus.pending) ? null : _toggleFollow,
                child: Text(_followButtonText(context)),
              ),
            ),
            if (_isBusinessOrRestaurant) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : null,
                  ),
                  label: Text(
                    _isFavorite ? l10n.tr('remove_favorite') : l10n.tr('add_favorite'),
                  ),
                ),
              ),
            ],
            if (!_canMessageLoading && !_canMessage) ...[
              const SizedBox(height: 8),
              Text(
                l10n.tr('message_after_mutual_follow'),
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _profileTypeLabel(BuildContext context) {
    final l10n = context.l10n;
    final type = (_profile?['profile_type'] ?? _profile?['account_type'] ?? '').toString();
    if (type != 'org') return type;

    final orgKind = (_profile?['org_kind'] ?? '').toString();
    switch (orgKind) {
      case 'government':
        return l10n.tr('organization_government');
      case 'nonprofit':
        return l10n.tr('organization_nonprofit');
      case 'news_agency':
        return l10n.tr('organization_news_agency');
      default:
        return l10n.tr('organization');
    }
  }

  String? _profileEntityName() {
    final accountType =
        (_profile?['profile_type'] ?? _profile?['account_type'] ?? '').toString();
    if (accountType != 'business' && accountType != 'org') return null;
    final businessName = (_profile?['business_name'] ?? '').toString().trim();
    return businessName.isEmpty ? null : businessName;
  }

  String? _profileCategoryLabel({bool isFrench = false}) {
    final accountType =
        (_profile?['profile_type'] ?? _profile?['account_type'] ?? '').toString();
    if (accountType == 'business') {
      if (_profile?['is_restaurant'] == true) {
        final restaurantType = (_profile?['restaurant_type'] ?? '').toString().trim();
        return restaurantType.isEmpty ? 'Restaurant' : restaurantCategoryLabel(restaurantType, isFrench: isFrench);
      }

      final businessType = (_profile?['business_type'] ?? '').toString().trim();
      final businessSubtype = (_profile?['business_subtype'] ?? '').toString().trim();
      if (businessType.isEmpty && businessSubtype.isEmpty) return null;
      return businessCategoryLabel(businessType, subcategory: businessSubtype, isFrench: isFrench);
    }

    if (accountType == 'org') {
      switch ((_profile?['org_kind'] ?? '').toString().trim()) {
        case 'government':
          return 'Government';
        case 'nonprofit':
          return 'Non-profit';
        case 'news_agency':
          return 'News agency';
        default:
          return 'Organization';
      }
    }

    return null;
  }

  String? _profileRoleTitle() {
    final role = (_profile?['job_title'] ?? '').toString().trim();
    return role.isEmpty ? null : role;
  }

  String? _profileBusinessDescription() {
    final accountType =
        (_profile?['profile_type'] ?? _profile?['account_type'] ?? '').toString();
    if (accountType != 'business' && accountType != 'org') return null;
    final value = (_profile?['business_profile'] ?? '').toString().trim();
    return value.isEmpty ? null : value;
  }

  Widget _buildProfileSidebar(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6DDCE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('profile_actions'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              if (_isMe) ...[
                _buildSidebarAction(
                  context: context,
                  icon: Icons.person_add_alt_1_outlined,
                  title: l10n.tr('follow_requests'),
                  subtitle: _pendingRequests > 0
                      ? l10n.tr(
                          'follow_requests_pending',
                          args: {'count': '$_pendingRequests'},
                        )
                      : l10n.tr('review_incoming_requests'),
                  onTap: () => context.push('/follow-requests'),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.edit_outlined,
                  title: l10n.tr('edit_profile'),
                  subtitle: l10n.tr('update_details_location'),
                  onTap: () async {
                    final router = GoRouter.of(context);
                    await router.push('/profile/edit');
                    if (!mounted) return;
                    await _loadAll();
                  },
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: l10n.tr('profile_settings'),
                  subtitle: l10n.tr('manage_app_preferences'),
                  onTap: () => context.push('/profile/settings'),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.groups_outlined,
                  title: l10n.tr('followers'),
                  subtitle: l10n.tr(
                    'followers_count_subtitle',
                    args: {'count': '$_followersCount'},
                  ),
                  onTap: () => context.push('/p/${widget.profileId}/followers'),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.group_outlined,
                  title: l10n.tr('following'),
                  subtitle: l10n.tr(
                    'following_count_subtitle',
                    args: {'count': '$_followingCount'},
                  ),
                  onTap: () => context.push('/p/${widget.profileId}/following'),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.hub_outlined,
                  title: l10n.tr('connections'),
                  subtitle: l10n.tr(
                    'connections_count_subtitle',
                    args: {'count': '$_connectionsCount'},
                  ),
                  onTap: () => context.push('/p/${widget.profileId}/connections'),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.inventory_2_outlined,
                  title: l10n.tr('my_products'),
                  subtitle: l10n.tr('edit_delete_marketplace_ads'),
                  onTap: () => context.push('/profile/my-products'),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.bookmark_outline,
                  title: l10n.tr('saved_listings'),
                  subtitle: l10n.tr('no_saved_listings_subtitle'),
                  onTap: () => context.push('/marketplace/saved'),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.work_outline,
                  title: l10n.tr('my_gigs'),
                  subtitle: l10n.tr('edit_delete_service_ads'),
                  onTap: () => context.push('/profile/my-gigs'),
                ),
                if ((_profile?['is_restaurant'] == true))
                  _buildSidebarAction(
                    context: context,
                    icon: Icons.restaurant_menu_outlined,
                    title: l10n.tr('my_foods'),
                    subtitle: l10n.tr('edit_delete_food_ads'),
                    onTap: () => context.push('/profile/my-foods'),
                  ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.share_outlined,
                  title: l10n.tr('share_app'),
                  subtitle: l10n.tr('share_app_subtitle'),
                  onTap: () => shareApp(context),
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.rate_review_outlined,
                  title: l10n.tr('give_feedback'),
                  subtitle: l10n.tr('feedback_subtitle'),
                  onTap: () => FeedbackScreen.showSheet(context),
                ),
              ] else ...[
                _buildSidebarAction(
                  context: context,
                  icon: Icons.groups_outlined,
                  title: l10n.tr('followers'),
                  subtitle: l10n.tr('visible_only_own_profile'),
                  onTap: null,
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.group_outlined,
                  title: l10n.tr('following'),
                  subtitle: l10n.tr('visible_only_own_profile'),
                  onTap: null,
                ),
                _buildSidebarAction(
                  context: context,
                  icon: Icons.hub_outlined,
                  title: l10n.tr('connections'),
                  subtitle: l10n.tr('visible_only_own_profile'),
                  onTap: null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildProfileMenuItems() {
    final l10n = context.l10n;
    if (_isMe) {
      return [
        PopupMenuItem(value: 'follow_requests', child: Text(l10n.tr('follow_requests'))),
        PopupMenuItem(value: 'edit_profile', child: Text(l10n.tr('edit_profile'))),
        PopupMenuItem(value: 'profile_settings', child: Text(l10n.tr('profile_settings'))),
        PopupMenuItem(value: 'followers', child: Text(l10n.tr('followers'))),
        PopupMenuItem(value: 'following', child: Text(l10n.tr('following'))),
        PopupMenuItem(value: 'connections', child: Text(l10n.tr('connections'))),
        PopupMenuItem(value: 'my_products', child: Text(l10n.tr('my_products'))),
        PopupMenuItem(value: 'saved_listings', child: Text(l10n.tr('saved_listings'))),
        PopupMenuItem(value: 'my_gigs', child: Text(l10n.tr('my_gigs'))),
        if ((_profile?['is_restaurant'] == true))
          PopupMenuItem(value: 'my_foods', child: Text(l10n.tr('my_foods'))),
        PopupMenuItem(value: 'share_app', child: Text(l10n.tr('share_app'))),
        PopupMenuItem(value: 'give_feedback', child: Text(l10n.tr('give_feedback'))),
      ];
    }

    return const [
      PopupMenuItem(value: 'report_user', child: Text('Report user')),
    ];
  }

  Future<void> _handleProfileMenuAction(String value) async {
    switch (value) {
      case 'follow_requests':
        await context.push('/follow-requests');
        return;
      case 'edit_profile':
        await context.push('/profile/edit');
        if (!mounted) return;
        await _loadAll();
        return;
      case 'followers':
        await context.push('/p/${widget.profileId}/followers');
        return;
      case 'profile_settings':
        await context.push('/profile/settings');
        return;
      case 'following':
        await context.push('/p/${widget.profileId}/following');
        return;
      case 'connections':
        await context.push('/p/${widget.profileId}/connections');
        return;
      case 'my_products':
        await context.push('/profile/my-products');
        return;
      case 'saved_listings':
        await context.push('/marketplace/saved');
        return;
      case 'my_gigs':
        await context.push('/profile/my-gigs');
        return;
      case 'my_foods':
        await context.push('/profile/my-foods');
        return;
      case 'share_app':
        await shareApp(context);
        return;
      case 'give_feedback':
        await FeedbackScreen.showSheet(context);
        return;
      case 'report_user':
        await _reportUser();
        return;
    }
  }

  Widget _buildProfileLeftSidebar({
    required BuildContext context,
    required String name,
    required String type,
    required String location,
  }) {
    final l10n = context.l10n;
    final entityName = _profileEntityName();
    final categoryLabel = _profileCategoryLabel();
    final roleTitle = _profileRoleTitle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6DDCE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('profile_overview'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (entityName != null) ...[
                const SizedBox(height: 8),
                Text(
                  entityName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              if (categoryLabel != null || roleTitle != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (categoryLabel != null) _ProfileMetaChip(label: categoryLabel),
                    if (roleTitle != null) _ProfileMetaChip(label: roleTitle),
                  ],
                ),
              ],
              if (type.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.tr('type', args: {'value': type}),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.tr('location', args: {'value': location}),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6DDCE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('connections'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              _clickableStat(
                enabled: _isMe,
                onTap: _isMe ? () => context.push('/p/${widget.profileId}/followers') : null,
                child: _StatTile(label: l10n.tr('followers'), value: _followersCount),
              ),
              const SizedBox(height: 10),
              _clickableStat(
                enabled: _isMe,
                onTap: _isMe ? () => context.push('/p/${widget.profileId}/following') : null,
                child: _StatTile(label: l10n.tr('following'), value: _followingCount),
              ),
              const SizedBox(height: 10),
              _clickableStat(
                enabled: _isMe,
                onTap: _isMe ? () => context.push('/p/${widget.profileId}/connections') : null,
                child: _StatTile(label: l10n.tr('connections'), value: _connectionsCount),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarAction({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMainContent({
    required BuildContext context,
    required String name,
    required String type,
    required String location,
    required String bio,
    required bool canOpenLists,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileHeader(
          context: context,
          name: name,
          type: type,
          location: location,
          bio: bio,
          canOpenLists: canOpenLists,
        ),
        if (_isMe) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.tr('this_is_your_profile'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6DDCE)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() => _showMyProfileActions = !_showMyProfileActions);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.tr('profile_actions'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(
                          _showMyProfileActions
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showMyProfileActions) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.person_add_alt_1_outlined,
                          title: l10n.tr('follow_requests'),
                          subtitle: _pendingRequests > 0
                              ? l10n.tr(
                                  'follow_requests_pending',
                                  args: {'count': '$_pendingRequests'},
                                )
                              : l10n.tr('review_incoming_requests'),
                          onTap: () => context.push('/follow-requests'),
                        ),
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.edit_outlined,
                          title: l10n.tr('edit_profile'),
                          subtitle: l10n.tr('update_details_location'),
                          onTap: () async {
                            await context.push('/profile/edit');
                            if (!mounted) return;
                            await _loadAll();
                          },
                        ),
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.settings_outlined,
                          title: l10n.tr('profile_settings'),
                          subtitle: l10n.tr('manage_app_preferences'),
                          onTap: () => context.push('/profile/settings'),
                        ),
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.groups_outlined,
                          title: l10n.tr('followers'),
                          subtitle: l10n.tr(
                            'followers_count_subtitle',
                            args: {'count': '$_followersCount'},
                          ),
                          onTap: () => context.push('/p/${widget.profileId}/followers'),
                        ),
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.group_outlined,
                          title: l10n.tr('following'),
                          subtitle: l10n.tr(
                            'following_count_subtitle',
                            args: {'count': '$_followingCount'},
                          ),
                          onTap: () => context.push('/p/${widget.profileId}/following'),
                        ),
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.inventory_2_outlined,
                          title: l10n.tr('my_products'),
                          subtitle: l10n.tr('edit_delete_marketplace_ads'),
                          onTap: () => context.push('/profile/my-products'),
                        ),
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.bookmark_outline,
                          title: l10n.tr('saved_listings'),
                          subtitle: l10n.tr('no_saved_listings_subtitle'),
                          onTap: () => context.push('/marketplace/saved'),
                        ),
                        _buildSidebarAction(
                          context: context,
                          icon: Icons.work_outline,
                          title: l10n.tr('my_gigs'),
                          subtitle: l10n.tr('edit_delete_service_ads'),
                          onTap: () => context.push('/profile/my-gigs'),
                        ),
                        if ((_profile?['is_restaurant'] == true))
                          _buildSidebarAction(
                            context: context,
                            icon: Icons.restaurant_menu_outlined,
                            title: l10n.tr('my_foods'),
                            subtitle: l10n.tr('edit_delete_food_ads'),
                            onTap: () => context.push('/profile/my-foods'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        _buildPortfolioSection(context),
        _buildProfileTabs(context),
        const SizedBox(height: 8),
        if (_selectedProfileTab == ProfileTab.posts)
          _buildPostsTabContent(context)
        else if (_selectedProfileTab == ProfileTab.marketplace)
          _buildMarketplaceTabContent(context)
        else
          _buildServicesTabContent(context),
      ],
    );
  }

  Widget _buildProfileTabs(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<ProfileTab>(
        segments: [
          ButtonSegment(
            value: ProfileTab.posts,
            label: Text('${l10n.tr('tab_posts')}${_posts.isNotEmpty ? ' (${_posts.length})' : ''}'),
            icon: const Icon(Icons.article_outlined, size: 18),
          ),
          ButtonSegment(
            value: ProfileTab.marketplace,
            label: Text('${l10n.tr('tab_marketplace')}${_marketPosts.isNotEmpty ? ' (${_marketPosts.length})' : ''}'),
            icon: const Icon(Icons.storefront_outlined, size: 18),
          ),
          ButtonSegment(
            value: ProfileTab.services,
            label: Text('${l10n.tr('tab_services')}${_servicePosts.isNotEmpty ? ' (${_servicePosts.length})' : ''}'),
            icon: const Icon(Icons.work_outline, size: 18),
          ),
        ],
        selected: {_selectedProfileTab},
        onSelectionChanged: (s) {
          setState(() => _selectedProfileTab = s.first);
        },
      ),
    );
  }

  Widget _buildPostsTabContent(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.tr('tab_posts'), style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Refresh posts',
              onPressed: _postsLoading ? null : _loadPosts,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_postsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_postsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Posts error:\n$_postsError'),
          )
        else if (_posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No posts yet.'),
          )
        else
          ..._posts.map(
            (p) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.authorName ?? (_isMe ? 'You' : 'Unknown'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_db.auth.currentUser?.id == p.userId)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (value == 'delete_post') {
                                await _deletePost(p);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete_post',
                                child: Text('Delete post'),
                              ),
                            ],
                          )
                        else if (_db.auth.currentUser?.id != p.userId)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (value == 'report_post') {
                                await _reportPost(p);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'report_post',
                                child: Text('Report post'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TaggedContent(content: p.content),
                    if ((p.imageUrl ?? '').isNotEmpty ||
                        (p.secondImageUrl ?? '').isNotEmpty ||
                        (p.videoUrl ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      PostMediaView(
                        imageUrl: p.imageUrl,
                        secondImageUrl: p.secondImageUrl,
                        videoUrl: p.videoUrl,
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (p.postType == 'market' ||
                        p.postType == 'service_offer' ||
                        p.postType == 'service_request' ||
                        p.postType == 'food_ad' ||
                        p.postType == 'food')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              if (p.postType == 'market') {
                                context.push('/marketplace/product/${p.id}');
                                return;
                              }
                              if (p.postType == 'service_offer' ||
                                  p.postType == 'service_request') {
                                context.push('/gigs/service/${p.id}');
                                return;
                              }
                              context.push('/foods/${p.id}');
                            },
                            icon: Icon(
                              p.postType == 'market'
                                  ? Icons.open_in_new
                                  : (p.postType == 'food_ad' || p.postType == 'food')
                                      ? Icons.restaurant
                                      : Icons.work_outline,
                              size: 18,
                            ),
                            label: Text(
                              p.postType == 'market'
                                  ? 'Open product'
                                  : (p.postType == 'food_ad' || p.postType == 'food')
                                      ? 'Open food'
                                      : 'Open gig',
                            ),
                          ),
                        ],
                      ),
                    if (_isMe && (p.postType == 'food_ad' || p.postType == 'food')) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: () => context.push('/profile/my-foods'),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Manage food ad'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _buildReactionsRow(p),
                    const SizedBox(height: 8),
                    if (p.locationName != null)
                      Text('Location: ${p.locationName}', style: const TextStyle(fontSize: 12)),
                    Text(
                      p.createdAt.toLocal().toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_postsHasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _postsLoadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _loadMorePosts,
                      child: const Text('Load more posts'),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildMarketplaceTabContent(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tr('tab_marketplace'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_isMe)
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/my-products'),
                icon: const Icon(Icons.tune, size: 16),
                label: Text(l10n.tr('manage')),
              ),
            IconButton(
              tooltip: 'Refresh listings',
              onPressed: _marketPostsLoading ? null : _loadMarketPosts,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_marketPostsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_marketPostsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Error: $_marketPostsError'),
          )
        else if (_marketPosts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.storefront_outlined, size: 48, color: Theme.of(context).hintColor),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tr('no_user_listings'),
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ..._marketPosts.map((p) {
            final isSold = p.itemStatus == 'sold';
            final isReserved = p.itemStatus == 'reserved';
            final conditionLabel = p.itemCondition != null
                ? itemConditionLabel(p.itemCondition, l10n)
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/marketplace/product/${p.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((p.imageUrl ?? '').isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Image.network(
                                p.imageUrl!,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 84,
                                  height: 84,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 28),
                                ),
                              ),
                              if (isSold || isReserved)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black45,
                                    alignment: Alignment.center,
                                    child: Text(
                                      isSold ? l10n.tr('status_sold') : l10n.tr('status_reserved'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront_outlined, size: 32),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.content.isEmpty ? l10n.tr('no_text') : p.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (p.marketPrice != null)
                                  Text(
                                    'EUR ${p.marketPrice!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: p.hasDiscount ? Colors.red[700] : const Color(0xFF0F766E),
                                      fontSize: 14,
                                    ),
                                  ),
                                if (p.hasDiscount && p.originalPrice != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'EUR ${p.originalPrice!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red[700],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '-${p.discountPercentage}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (conditionLabel != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      conditionLabel,
                                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                if ((p.locationName ?? '').isNotEmpty)
                                  Text(
                                    p.locationName!,
                                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildServicesTabContent(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tr('tab_services'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_isMe)
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/my-gigs'),
                icon: const Icon(Icons.tune, size: 16),
                label: Text(l10n.tr('manage')),
              ),
            IconButton(
              tooltip: 'Refresh services',
              onPressed: _servicePostsLoading ? null : _loadServicePosts,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_servicePostsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_servicePostsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Error: $_servicePostsError'),
          )
        else if (_servicePosts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.work_outline, size: 48, color: Theme.of(context).hintColor),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tr('no_user_services'),
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ..._servicePosts.map((p) {
            final isOffer = p.postType == 'service_offer';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/gigs/service/${p.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isOffer ? const Color(0xFF0F766E) : Colors.orange[800]!)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOffer ? l10n.tr('service_offer') : l10n.tr('service_request'),
                              style: TextStyle(
                                color: isOffer ? const Color(0xFF0F766E) : Colors.orange[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (p.marketPrice != null)
                            Text(
                              '€${p.marketPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F766E),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.3),
                      ),
                      if ((p.locationName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              p.locationName!,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  void dispose() {
    final ch = _reqChannel;
    _reqChannel = null;
    if (ch != null) {
      _db.removeChannel(ch);
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfileAndFollow(),
      _loadPosts(),
      _loadMarketPosts(),
      _loadServicePosts(),
    ]);

    // ✅ After profile loads (we need profile_type), load portfolio
    await _loadPortfolioIfEligible();
  }

  // =========================
  // ✅ REPORT USER
  // =========================
  Future<void> _reportUser() async {
    final reported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportUserSheet(reportedUserId: widget.profileId),
    );

    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — we’ll review it.')),
      );
    }
  }

  // =========================
  // ✅ REPORT POST
  // =========================
  Future<void> _reportPost(Post post) async {
    final reported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportPostSheet(postId: post.id),
    );

    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — we’ll review it.')),
      );
    }
  }

  // =========================
  // ✅ MESSAGING PERMISSION
  // =========================
  Future<void> _loadCanMessage() async {
    if (!mounted) return;
    setState(() {
      _canMessage = false;
      _canMessageLoading = true;
    });

    if (_isMe) {
      if (!mounted) return;
      setState(() {
        _canMessage = false;
        _canMessageLoading = false;
      });
      return;
    }

    if (_profile?['is_disabled'] == true) {
      if (!mounted) return;
      setState(() {
        _canMessage = false;
        _canMessageLoading = false;
      });
      return;
    }

    try {
      final res = await _db.rpc('can_message_me', params: {
        'p_other_user_id': widget.profileId,
      });

      if (!mounted) return;
      setState(() {
        _canMessage = (res as bool);
        _canMessageLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canMessage = false;
        _canMessageLoading = false;
      });
    }
  }

  // =========================
  // ✅ FOLLOW REQUESTS BADGE
  // =========================
  Future<void> _refreshPendingRequests() async {
    final me = _db.auth.currentUser?.id;
    if (me == null) return;

    final rows = await _db
        .from('follows')
        .select('follower_id')
        .eq('followed_profile_id', me)
        .eq('status', 'pending');

    if (!mounted) return;
    setState(() => _pendingRequests = (rows as List).length);
  }

  void _subscribeRequestsRealtime() {
    final me = _db.auth.currentUser?.id;
    if (me == null) return;
    if (_reqChannel != null) return;

    _reqChannel = _db.channel('follow-requests-$me')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'follows',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'followed_profile_id',
          value: me,
        ),
        callback: (_) => _refreshPendingRequests(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'follows',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'followed_profile_id',
          value: me,
        ),
        callback: (_) => _refreshPendingRequests(),
      )
      ..subscribe();
  }

  // =========================
  // ✅ LOAD PROFILE + FOLLOW
  // =========================
  Future<void> _loadProfileAndFollow() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final myUserId = _db.auth.currentUser!.id;

      final p = await _db
          .from('profiles')
          .select('*')
          .eq('id', widget.profileId)
          .maybeSingle();
      if (p == null || p['is_disabled'] == true) {
        throw Exception('Profile not available');
      }
      _profile = p;

      _isMe = (widget.profileId == myUserId);

      // ✅ Messaging permission (mutual follow)
      await _loadCanMessage();

      final follow = FollowService(_db);

      if (!_isMe) {
        _followStatus = await follow.getMyStatus(widget.profileId);
      } else {
        _followStatus = FollowStatus.none;
      }

      _followersCount = await follow.followersCount(widget.profileId);
      _followingCount = await follow.followingCount(widget.profileId);
      _connectionsCount = await follow.mutualConnectionsCount(widget.profileId);

      if (!_isMe && _isBusinessOrRestaurant) {
        _isFavorite = await _favService.isFavorite(widget.profileId);
      } else {
        _isFavorite = false;
      }

      if (_isMe) {
        await _refreshPendingRequests();
        _subscribeRequestsRealtime();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final l10n = context.l10n;
    final wasFav = _isFavorite;
    setState(() => _isFavorite = !wasFav);
    try {
      if (wasFav) {
        await _favService.removeFavorite(widget.profileId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('business_unfavorited')),
            action: SnackBarAction(
              label: l10n.tr('undo'),
              onPressed: _toggleFavorite,
            ),
          ),
        );
      } else {
        await _favService.addFavorite(widget.profileId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tr('business_favorited'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFavorite = wasFav);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // =========================
  // ✅ POSTS
  // =========================
  Future<void> _loadPosts() async {
    if (_profile?['is_disabled'] == true) {
      if (mounted) {
        setState(() {
          _posts = [];
          _postsError = null;
          _postsLoading = false;
        });
      }
      return;
    }

    setState(() {
      _postsLoading = true;
      _postsError = null;
      _postsPage = 0;
      _postsHasMore = true;
    });

    try {
      final rows = await _db
          .from('posts')
          .select('*, profiles(full_name, avatar_url)')
          .eq('user_id', widget.profileId)
          .order('created_at', ascending: false)
          .range(0, 19);

      final list = (rows as List)
          .map((e) => Post.fromMap(e as Map<String, dynamic>))
          .where((post) {
            final type = (post.postType ?? '').trim();
            // ONLY show general posts. Hide marketplace, gigs, food ads, lost/found.
            return type == 'post' || type == '';
          })
          .toList();
      if (mounted) {
        setState(() {
          _posts = list;
          _postsPage = 1;
          _postsHasMore = rows.length == 20;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _postsError = e.toString());
    } finally {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_postsLoadingMore || !_postsHasMore) return;
    setState(() => _postsLoadingMore = true);
    try {
      final from = _postsPage * 20;
      final to = from + 19;
      final rows = await _db
          .from('posts')
          .select('*, profiles(full_name, avatar_url)')
          .eq('user_id', widget.profileId)
          .order('created_at', ascending: false)
          .range(from, to);

      final newPosts = (rows as List)
          .map((e) => Post.fromMap(e as Map<String, dynamic>))
          .where((post) {
            final type = (post.postType ?? '').trim();
            return type == 'post' || type == '';
          })
          .toList();

      if (mounted) {
        setState(() {
          _posts = [..._posts, ...newPosts];
          _postsPage++;
          _postsHasMore = rows.length == 20;
        });
      }
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _postsLoadingMore = false);
    }
  }

  Future<void> _loadMarketPosts() async {
    if (_profile?['is_disabled'] == true) {
      if (mounted) {
        setState(() {
          _marketPosts = [];
          _marketPostsError = null;
          _marketPostsLoading = false;
        });
      }
      return;
    }

    setState(() {
      _marketPostsLoading = true;
      _marketPostsError = null;
    });

    try {
      final rows = await _db
          .from('posts')
          .select('*, profiles(full_name, avatar_url)')
          .eq('user_id', widget.profileId)
          .eq('type', 'market')
          .order('created_at', ascending: false)
          .limit(40);

      final list = (rows as List)
          .map((e) => Post.fromMap(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _marketPosts = list;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _marketPostsError = e.toString());
    } finally {
      if (mounted) setState(() => _marketPostsLoading = false);
    }
  }

  Future<void> _loadServicePosts() async {
    if (_profile?['is_disabled'] == true) {
      if (mounted) {
        setState(() {
          _servicePosts = [];
          _servicePostsError = null;
          _servicePostsLoading = false;
        });
      }
      return;
    }

    setState(() {
      _servicePostsLoading = true;
      _servicePostsError = null;
    });

    try {
      final rows = await _db
          .from('posts')
          .select('*, profiles(full_name, avatar_url)')
          .eq('user_id', widget.profileId)
          .inFilter('type', ['service_offer', 'service_request'])
          .order('created_at', ascending: false)
          .limit(40);

      final list = (rows as List)
          .map((e) => Post.fromMap(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _servicePosts = list;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _servicePostsError = e.toString());
    } finally {
      if (mounted) setState(() => _servicePostsLoading = false);
    }
  }

  Future<void> _deletePost(Post post) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.tr('delete_post')),
        content: Text(l10n.tr('delete_post_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await PostService(_db).deleteOwnPost(post.id);
      if (!mounted) return;

      setState(() {
        _posts.removeWhere((item) => item.id == post.id || item.sharedPostId == post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('post_deleted'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('delete_failed', args: {'error': '$e'})),
        ),
      );
    }
  }

  // =========================
  // ✅ FOLLOW TOGGLE
  // =========================
  Future<void> _toggleFollow() async {
    if (_isMe) return;

    setState(() => _loading = true);

    try {
      final follow = FollowService(_db);

      if (_followStatus == FollowStatus.accepted ||
          _followStatus == FollowStatus.pending ||
          _followStatus == FollowStatus.declined) {
        await follow.cancelOrUnfollow(widget.profileId);
        _followStatus = FollowStatus.none;
      } else {
        await follow.requestFollow(widget.profileId);
        _followStatus = FollowStatus.pending;
      }

      _followersCount = await follow.followersCount(widget.profileId);
      _followingCount = await follow.followingCount(widget.profileId);
      _connectionsCount = await follow.mutualConnectionsCount(widget.profileId);

      await _loadCanMessage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.tr('follow_error', args: {'error': '$e'})),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _followButtonText(BuildContext context) {
    final l10n = context.l10n;
    switch (_followStatus) {
      case FollowStatus.accepted:
        return l10n.tr('unfollow');
      case FollowStatus.pending:
        return l10n.tr('requested');
      case FollowStatus.declined:
        return l10n.tr('request_again');
      case FollowStatus.none:
        return l10n.tr('request_follow');
    }
  }

  // ✅ Likes + Comments row (for each post)
  Widget _buildReactionsRow(Post p) {
    final react = ReactionService(Supabase.instance.client);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        react.isLiked(p.id),
        react.likesCount(p.id),
        react.commentsCount(p.id),
      ]),
      builder: (context, snap) {
        final liked = snap.hasData ? snap.data![0] as bool : false;
        final likeCount = snap.hasData ? snap.data![1] as int : 0;
        final commentCount = snap.hasData ? snap.data![2] as int : 0;

        return Row(
          children: [
            TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  if (liked) {
                    await react.unlike(p.id);
                  } else {
                    await react.like(p.id);
                  }
                  if (!mounted) return;
                  setState(() {});
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Like error: $e')),
                  );
                }
              },
              icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
              label: Text('$likeCount'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => context.push('/post/${p.id}/comments'),
              icon: const Icon(Icons.comment_outlined),
              label: Text('$commentCount'),
            ),
          ],
        );
      },
    );
  }

  Widget _clickableStat({
    required bool enabled,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    if (!enabled) {
      return Opacity(opacity: 0.65, child: child);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }

  // =========================
  // ✅ PORTFOLIO
  // =========================
  bool _canHavePortfolio() {
    final type = (_profile?['profile_type'] ?? _profile?['account_type'] ?? '').toString();
    return type == 'business' || type == 'org';
  }

  Future<void> _loadPortfolioIfEligible() async {
    if (!_canHavePortfolio()) {
      if (!mounted) return;
      setState(() {
        _portfolioLoading = false;
        _portfolioError = null;
        _portfolio = [];
      });
      return;
    }
    await _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() {
      _portfolioLoading = true;
      _portfolioError = null;
    });

    try {
      final svc = PortfolioService(_db);
      final items = await svc.fetchPortfolio(widget.profileId);

      if (!mounted) return;
      setState(() {
        _portfolio = items;
        _portfolioLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _portfolioError = e.toString();
        _portfolioLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadPortfolioImage() async {
    if (!_isMe) return;
    if (_portfolioActionLoading) return;
    if (_portfolio.length >= 5) return;

    setState(() => _portfolioActionLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;

      final file = result.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        throw Exception('No image bytes. Try again.');
      }

      final ext = (file.extension ?? 'jpg').toLowerCase();

      final svc = PortfolioService(_db);
      await svc.addPortfolioImage(
        profileId: widget.profileId,
        bytes: bytes,
        fileExt: ext,
      );

      await _loadPortfolio();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tr('portfolio_upload_error', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _portfolioActionLoading = false);
    }
  }

  Future<(Uint8List, String)?> _pickPortfolioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('No image bytes. Try again.');
    }

    return (bytes, (file.extension ?? 'jpg').toLowerCase());
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePortfolio(String itemId) async {
    if (!_isMe) return;
    if (_portfolioActionLoading) return;

    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.tr('remove_photo')),
        content: Text(l10n.tr('remove_photo_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.tr('remove')),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _portfolioActionLoading = true);

    try {
      final svc = PortfolioService(_db);
      await svc.deletePortfolioItem(itemId: itemId);
      await _loadPortfolio();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tr('portfolio_delete_error', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _portfolioActionLoading = false);
    }
  }

  Future<void> _replacePortfolioImage(PortfolioItem item) async {
    if (!_isMe) return;
    if (_portfolioActionLoading) return;

    setState(() => _portfolioActionLoading = true);

    try {
      final picked = await _pickPortfolioFile();
      if (picked == null) return;

      final svc = PortfolioService(_db);
      await svc.replacePortfolioImage(
        itemId: item.id,
        profileId: widget.profileId,
        bytes: picked.$1,
        fileExt: picked.$2,
      );

      await _loadPortfolio();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tr('portfolio_update_error', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _portfolioActionLoading = false);
    }
  }

  Widget _buildPortfolioSection(BuildContext context) {
    final l10n = context.l10n;
    if (!_canHavePortfolio()) return const SizedBox.shrink();

    final canAdd = _isMe && _portfolio.length < 5;

    if (_portfolioLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_portfolioError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          l10n.tr('portfolio_error', args: {'error': '$_portfolioError'}),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.tr('portfolio'), style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('${_portfolio.length}/5',
                style: TextStyle(color: Theme.of(context).hintColor)),
            const SizedBox(width: 8),
            if (canAdd)
              ElevatedButton.icon(
                onPressed: _portfolioActionLoading ? null : _pickAndUploadPortfolioImage,
                icon: _portfolioActionLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(l10n.tr('add')),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_portfolio.isEmpty)
          Text(
            _isMe ? l10n.tr('add_portfolio_photos') : l10n.tr('no_portfolio_photos'),
            style: TextStyle(color: Theme.of(context).hintColor),
          )
        else
           GridView.builder(
             shrinkWrap: true,
             physics: const NeverScrollableScrollPhysics(),
             itemCount: _portfolio.length,
             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 3,
               crossAxisSpacing: 8,
               mainAxisSpacing: 8,
               childAspectRatio: 1.0,
             ),
             itemBuilder: (_, i) {
               final item = _portfolio[i];
               return GestureDetector(
                 onTap: () => _openImage(item.imageUrl),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(12),
                   child: Stack(
                     children: [
                       Container(
                         color: Colors.grey.shade200,
                         padding: const EdgeInsets.all(6),
                         width: double.infinity,
                         height: double.infinity,
                         child: Image.network(
                           item.imageUrl,
                           fit: BoxFit.contain,
                           alignment: Alignment.center,
                         ),
                       ),
                       if (_isMe)
                         Positioned(
                           top: 8,
                           right: 8,
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               _buildPortfolioActionButton(
                                 icon: Icons.edit_outlined,
                                 tooltip: context.l10n.tr('replace_photo'),
                                 onTap: _portfolioActionLoading
                                     ? null
                                     : () => _replacePortfolioImage(item),
                               ),
                               const SizedBox(width: 6),
                               _buildPortfolioActionButton(
                                 icon: Icons.delete_outline,
                                 tooltip: context.l10n.tr('remove_photo_tooltip'),
                                 onTap: _portfolioActionLoading
                                     ? null
                                     : () => _confirmDeletePortfolio(item.id),
                               ),
                             ],
                           ),
                         ),
                     ],
                   ),
                 ),
               );
             },
           ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: const GlobalAppBar(title: 'Allonssy!'),
        bottomNavigationBar: const GlobalBottomNav(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l10n.tr('profile_error', args: {'error': '$_error'})),
        ),
      );
    }

    final name = (_profile?['full_name'] ?? 'Profile').toString();
    final bio = (_profile?['bio'] ?? '').toString();
    final type = _profileTypeLabel(context);
    final city = (_profile?['city'] ?? '').toString();
    final zipcode = (_profile?['zipcode'] ?? '').toString();
    final location = city.isNotEmpty ? city : zipcode;

    final canOpenLists = _isMe;

    return Scaffold(
      appBar: GlobalAppBar(
        title: 'Allonssy!',
        showBackIfPossible: true,
        homeRoute: '/feed',
        actions: [
          if (!_isMe && _isBusinessOrRestaurant)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              tooltip: _isFavorite
                  ? context.l10n.tr('remove_favorite')
                  : context.l10n.tr('add_favorite'),
              onPressed: _toggleFavorite,
            ),
          if (!_isMe)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _handleProfileMenuAction,
              itemBuilder: (_) => _buildProfileMenuItems(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;

            if (!isWide) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileMainContent(
                    context: context,
                    name: name,
                    type: type,
                    location: location,
                    bio: bio,
                    canOpenLists: canOpenLists,
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 250,
                    child: _buildProfileLeftSidebar(
                      context: context,
                      name: name,
                      type: type,
                      location: location,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _buildProfileMainContent(
                        context: context,
                        name: name,
                        type: type,
                        location: location,
                        bio: bio,
                        canOpenLists: canOpenLists,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 320,
                    child: _buildProfileSidebar(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const GlobalBottomNav(),
    );
  }

  Widget _buildPortfolioActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _ProfileMetaChip extends StatelessWidget {
  final String label;

  const _ProfileMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6DDCE)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
