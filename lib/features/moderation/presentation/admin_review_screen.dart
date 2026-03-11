import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLiveScreen extends StatefulWidget {
  const AdminLiveScreen({super.key});

  @override
  State<AdminLiveScreen> createState() => _AdminLiveScreenState();
}

class _AdminLiveScreenState extends State<AdminLiveScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _userSearchCtrl = TextEditingController();

  late final TabController _tab;

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _adminLoginLoading = false;

  String _statusFilter = 'pending'; // pending | reviewed | dismissed

  bool _loadingStats = true;
  final Set<String> _busyUserIds = <String>{};
  final Set<String> _busyPostIds = <String>{};

  List<Map<String, dynamic>> _postReports = [];
  List<Map<String, dynamic>> _userReports = [];
  Map<String, int> _stats = const {};
  
  List<Map<String, dynamic>> _marketplacePosts = [];
  List<Map<String, dynamic>> _gigPosts = [];
  List<Map<String, dynamic>> _foodPosts = [];
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, Map<String, dynamic>> _userAuthStatus = const {};
  Map<String, int> _userReportCounts = const {};
  Map<String, int> _userBlockedByCounts = const {};
  Map<String, int> _userBlocksMadeCounts = const {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tab.dispose();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _checkAdmin();
    if (_isAdmin) {
      await _refreshAll();
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _loadingStats = true);
    try {
      await Future.wait([
        _loadStats(),
        _loadPostReports(),
        _loadUserReports(),
        _loadCategorizedPosts(),
        _loadUserModerationCounts(),
      ]);
      await _loadAllUsers();
      await _loadUserAuthStatuses();
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _adminLogin() async {
    setState(() {
      _adminLoginLoading = true;
    });

    try {
      await _db.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _init();
    } catch (e) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _adminLoginLoading = false);
    }
  }

  Future<void> _logoutAdmin() async {
    await _db.auth.signOut();
    if (!mounted) return;
    setState(() {
      _isAdmin = false;
      _checkingAdmin = false;
    });
  }

  Future<void> _checkAdmin() async {
    setState(() {
      _checkingAdmin = true;
      _isAdmin = false;
    });

    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _checkingAdmin = false;
          _isAdmin = false;
        });
        return;
      }

      final row = await _db
          .from('profiles')
          .select('is_admin')
          .eq('id', uid)
          .maybeSingle();

      setState(() {
        _isAdmin = (row?['is_admin'] == true);
        _checkingAdmin = false;
      });
    } catch (e) {
      setState(() {
        _checkingAdmin = false;
        _isAdmin = false;
      });
    }
  }

  Future<void> _loadPostReports() async {
    try {
      final rows = await _db
          .from('post_reports')
          .select('id, created_at, reporter_id, post_id, reason, details, status')
          .eq('status', _statusFilter)
          .order('created_at', ascending: false);
      _postReports = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('Post reports error: $e');
    }
  }

  Future<void> _loadUserReports() async {
    try {
      final rows = await _db
          .from('user_reports')
          .select('id, created_at, reporter_id, reported_user_id, reason, details, status')
          .eq('status', _statusFilter)
          .order('created_at', ascending: false);
      _userReports = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      print('User reports error: $e');
    }
  }

  Future<void> _loadCategorizedPosts() async {
    try {
      final results = await Future.wait([
        _db.from('posts').select('*, profiles(full_name, business_name, avatar_url)').eq('post_type', 'market').order('created_at', ascending: false).limit(50),
        _db.from('posts').select('*, profiles(full_name, business_name, avatar_url)').inFilter('post_type', ['service_offer', 'service_request']).order('created_at', ascending: false).limit(50),
        _db.from('posts').select('*, profiles(full_name, business_name, avatar_url)').inFilter('post_type', ['food_ad', 'food']).order('created_at', ascending: false).limit(50),
      ]);

      _marketplacePosts = (results[0] as List).cast<Map<String, dynamic>>();
      _gigPosts = (results[1] as List).cast<Map<String, dynamic>>();
      _foodPosts = (results[2] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Categorized posts error: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final rows = await _db
          .from('profiles')
          .select('id, full_name, business_name, job_title, profile_type, account_type, org_kind, is_disabled, avatar_url')
          .order('created_at', ascending: false)
          .limit(100);
      _allUsers = (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Load users error: $e');
    }
  }

  Future<void> _loadUserModerationCounts() async {
    try {
      final results = await Future.wait([
        _db.from('user_reports').select('reporter_id, reported_user_id'),
        _db.from('user_blocks').select('blocker_id, blocked_id'),
      ]);

      final reportCounts = <String, int>{};
      for (final row in (results[0] as List).cast<Map<String, dynamic>>()) {
        final reportedId = (row['reported_user_id'] ?? '').toString();
        if (reportedId.isEmpty) continue;
        reportCounts[reportedId] = (reportCounts[reportedId] ?? 0) + 1;
      }

      final blockedByCounts = <String, int>{};
      final blocksMadeCounts = <String, int>{};
      for (final row in (results[1] as List).cast<Map<String, dynamic>>()) {
        final blockerId = (row['blocker_id'] ?? '').toString();
        final blockedId = (row['blocked_id'] ?? '').toString();
        if (blockerId.isNotEmpty) {
          blocksMadeCounts[blockerId] = (blocksMadeCounts[blockerId] ?? 0) + 1;
        }
        if (blockedId.isNotEmpty) {
          blockedByCounts[blockedId] = (blockedByCounts[blockedId] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _userReportCounts = reportCounts;
        _userBlockedByCounts = blockedByCounts;
        _userBlocksMadeCounts = blocksMadeCounts;
      });
    } catch (e) {
      print('Load moderation counts error: $e');
    }
  }

  Future<void> _loadUserAuthStatuses() async {
    try {
      final accessToken = _db.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) return;

      final userIds = _allUsers
          .map((row) => (row['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      final response = await _db.functions.invoke(
        'admin-user-auth',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: {
          'action': 'list',
          'userIds': userIds,
          'accessToken': accessToken,
        },
      );

      if (response.status < 200 || response.status >= 300) return;
      final payload = response.data;
      if (payload is! Map || payload['users'] is! List) return;

      final statuses = <String, Map<String, dynamic>>{};
      for (final row in (payload['users'] as List)) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final id = (map['id'] ?? '').toString();
        if (id.isEmpty) continue;
        statuses[id] = map;
      }

      if (!mounted) return;
      setState(() => _userAuthStatus = statuses);
    } catch (e) {
      if (!mounted) return;
      _snack('User auth lookup failed: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final activeSince = now.subtract(const Duration(minutes: 5)).toIso8601String();

      final results = await Future.wait<dynamic>([
        _db.from('profiles').select('id, profile_type, account_type, is_restaurant, org_kind'),
        _db.from('profiles').select('id').gte('last_seen_at', activeSince),
        _db.from('posts').select('id, post_type, visibility'),
        _db.from('posts').select('id').gte('created_at', todayStart),
        _db.from('post_reports').select('id').eq('status', 'pending'),
        _db.from('user_reports').select('id').eq('status', 'pending'),
      ]);

      final profiles = (results[0] as List).cast<Map<String, dynamic>>();
      final posts = (results[1] as List).cast<Map<String, dynamic>>();
      
      _stats = {
        'profiles': profiles.length,
        'active_now': (results[1] as List).length,
        'posts': posts.length,
        'today_posts': (results[3] as List).length,
        'pending_post_reports': (results[4] as List).length,
        'pending_user_reports': (results[5] as List).length,
      };
    } catch (e) {
      // Handle or ignore error as before
    }
  }

  void _setFilter(String value) {
    setState(() => _statusFilter = value);
    _loadPostReports();
    _loadUserReports();
  }

  Future<void> _softDeletePost(String postId) async {
    final ok = await _confirm(
      title: 'Remove post?',
      message: 'This will hide the post from all users.',
      confirmText: 'Remove',
      danger: true,
    );
    if (!ok) return;

    setState(() => _busyPostIds.add(postId));
    try {
      await _db.rpc('admin_soft_delete_post', params: {'p_post_id': postId});
      await _refreshAll();
      _snack('Post removed');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busyPostIds.remove(postId));
    }
  }

  Future<void> _setUserDisabled(String userId, bool disabled) async {
    final myId = _db.auth.currentUser?.id;
    if (myId != null && userId == myId) {
      _snack('You cannot disable your own admin account');
      return;
    }

    final ok = await _confirm(
      title: disabled ? 'Disable user?' : 'Enable user?',
      message: disabled ? 'This will block login access.' : 'This will restore login access.',
      confirmText: disabled ? 'Disable' : 'Enable',
      danger: disabled,
    );
    if (!ok) return;

    setState(() => _busyUserIds.add(userId));
    try {
      await _db.rpc('admin_set_user_disabled', params: {'p_user_id': userId, 'p_disabled': disabled});
      await _refreshAll();
      _snack(disabled ? 'User disabled' : 'User enabled');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(userId));
    }
  }

  Future<void> _deleteUser(String userId) async {
    final myId = _db.auth.currentUser?.id;
    if (myId != null && userId == myId) {
      _snack('You cannot delete your own admin account');
      return;
    }

    final ok = await _confirm(
      title: 'Delete user?',
      message: 'This action is permanent and cannot be undone.',
      confirmText: 'Delete Forever',
      danger: true,
    );
    if (!ok) return;

    setState(() => _busyUserIds.add(userId));
    try {
      final accessToken = _db.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw 'Not authenticated';
      }

      final response = await _db.functions.invoke(
        'admin-delete-user',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: {
          'userId': userId,
          'accessToken': accessToken,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final payload = response.data;
        if (payload is Map && payload['error'] != null) {
          throw payload['error'].toString();
        }
        throw 'Delete failed';
      }
      if (mounted) {
        setState(() {
          _allUsers.removeWhere((row) => (row['id'] ?? '').toString() == userId);
          _userAuthStatus = Map<String, Map<String, dynamic>>.from(_userAuthStatus)
            ..remove(userId);
          _userReports.removeWhere((row) {
            final reportedUserId = (row['reported_user_id'] ?? '').toString();
            final reporterId = (row['reporter_id'] ?? '').toString();
            return reportedUserId == userId || reporterId == userId;
          });
          _stats = {
            ..._stats,
            'profiles': ((_stats['profiles'] ?? 1) - 1).clamp(0, 1 << 30),
          };
        });
      }
      await _refreshAll();
      _snack('User deleted permanently');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(userId));
    }
  }

  Future<void> _verifyUser(String userId) async {
    setState(() => _busyUserIds.add(userId));
    try {
      final accessToken = _db.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw 'Not authenticated';
      }

      final response = await _db.functions.invoke(
        'admin-user-auth',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: {
          'action': 'verify',
          'userId': userId,
          'accessToken': accessToken,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final payload = response.data;
        if (payload is Map && payload['error'] != null) {
          throw payload['error'].toString();
        }
        throw 'Verification failed';
      }

      if (!mounted) return;
      setState(() {
        _userAuthStatus = Map<String, Map<String, dynamic>>.from(_userAuthStatus)
          ..update(
            userId,
            (value) => {
              ...value,
              'verified': true,
            },
            ifAbsent: () => {'verified': true},
          );
      });
      _snack('User verified');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(userId));
    }
  }

  Future<void> _resendVerification(String userId) async {
    setState(() => _busyUserIds.add(userId));
    try {
      final accessToken = _db.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw 'Not authenticated';
      }

      final response = await _db.functions.invoke(
        'admin-user-auth',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: {
          'action': 'resend',
          'userId': userId,
          'accessToken': accessToken,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final payload = response.data;
        if (payload is Map && payload['error'] != null) {
          throw payload['error'].toString();
        }
        throw 'Resend failed';
      }
      _snack('Verification email sent');
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(userId));
    }
  }

  Future<void> _createUserFromAdmin({
    required String email,
    required String password,
    required String fullName,
    required bool autoVerify,
    required bool sendVerificationEmail,
  }) async {
    try {
      final accessToken = _db.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw 'Not authenticated';
      }

      final response = await _db.functions.invoke(
        'admin-user-auth',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: {
          'action': 'create',
          'email': email,
          'password': password,
          'fullName': fullName,
          'autoVerify': autoVerify,
          'sendVerificationEmail': sendVerificationEmail,
          'accessToken': accessToken,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final payload = response.data;
        if (payload is Map && payload['error'] != null) {
          throw payload['error'].toString();
        }
        throw 'User creation failed';
      }

      final payload = response.data;
      await _refreshAll();

      if (payload is Map && payload['warning'] != null) {
        _snack('User created. Verification email warning: ${payload['warning']}');
        return;
      }

      if (autoVerify) {
        _snack('User created and verified');
      } else if (sendVerificationEmail) {
        _snack('User created and verification email sent');
      } else {
        _snack('User created');
      }
    } catch (e) {
      _snack('Failed: $e');
      rethrow;
    }
  }

  Future<void> _showCreateUserDialog() async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final passwordFocus = FocusNode();
    var autoVerify = true;
    var sendVerificationEmail = false;
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final email = emailCtrl.text.trim();
              final password = passwordCtrl.text;
              final fullName = fullNameCtrl.text.trim();

              if (email.isEmpty || !email.contains('@')) {
                setModalState(() => error = 'Enter a valid email');
                return;
              }
              if (password.length < 6) {
                setModalState(() => error = 'Password must be at least 6 characters');
                return;
              }

              setModalState(() {
                saving = true;
                error = null;
              });

              try {
                await _createUserFromAdmin(
                  email: email,
                  password: password,
                  fullName: fullName,
                  autoVerify: autoVerify,
                  sendVerificationEmail: sendVerificationEmail,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                setModalState(() {
                  saving = false;
                  error = e.toString();
                });
              }
            }

            return AlertDialog(
              title: const Text('Create user'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: fullNameCtrl,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => passwordFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Name (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => passwordFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        focusNode: passwordFocus,
                        obscureText: true,
                        onSubmitted: (_) {
                          if (!saving) submit();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Temporary password',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Verify automatically'),
                        subtitle: const Text('User can log in immediately with this password'),
                        value: autoVerify,
                        onChanged: saving
                            ? null
                            : (value) {
                                setModalState(() {
                                  autoVerify = value;
                                  if (value) sendVerificationEmail = false;
                                });
                              },
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Send verification email'),
                        subtitle: const Text('Use when you do not want to auto-verify'),
                        value: sendVerificationEmail,
                        onChanged: saving || autoVerify
                            ? null
                            : (value) {
                                setModalState(() => sendVerificationEmail = value);
                              },
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: Text(saving ? 'Creating...' : 'Create user'),
                ),
              ],
            );
          },
        );
      },
    );

    emailCtrl.dispose();
    passwordCtrl.dispose();
    fullNameCtrl.dispose();
    passwordFocus.dispose();
  }

  Future<void> _setReportStatus({required String table, required String reportId, required String status}) async {
    try {
      await _db.from(table).update({'status': status}).eq('id', reportId);
      await _refreshAll();
      _snack('Report marked $status');
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({required String title, required String message, required String confirmText, bool danger = false}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: danger ? ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white) : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_db.auth.currentUser == null) return _buildAdminLoginScreen();
    if (!_isAdmin) return _buildAccessDeniedScreen();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Moderation Dashboard', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: () => context.go('/feed'), icon: const Icon(Icons.home_outlined), tooltip: 'Feed'),
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          IconButton(onPressed: _logoutAdmin, icon: const Icon(Icons.logout), tooltip: 'Logout'),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Users'),
            Tab(text: 'Marketplace'),
            Tab(text: 'Gigs'),
            Tab(text: 'Food Ads'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildDashboard(),
          _buildUserManagementTable(),
          _buildPostModerationTab(_marketplacePosts, 'market'),
          _buildPostModerationTab(_gigPosts, 'gig'),
          _buildPostModerationTab(_foodPosts, 'food'),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_loadingStats) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _ModernStatCard(title: 'Active Profiles', value: _stats['profiles']?.toString() ?? '0', icon: Icons.people, color: Colors.indigo),
              _ModernStatCard(title: 'Active Now', value: _stats['active_now']?.toString() ?? '0', icon: Icons.online_prediction, color: Colors.teal),
              _ModernStatCard(title: 'New Today', value: _stats['today_posts']?.toString() ?? '0', icon: Icons.bolt, color: Colors.amber),
              _ModernStatCard(title: 'Post Reports', value: _stats['pending_post_reports']?.toString() ?? '0', icon: Icons.flag, color: Colors.red, isAlert: (_stats['pending_post_reports'] ?? 0) > 0),
              _ModernStatCard(title: 'User Reports', value: _stats['pending_user_reports']?.toString() ?? '0', icon: Icons.person_off, color: Colors.redAccent, isAlert: (_stats['pending_user_reports'] ?? 0) > 0),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickNavCard(title: 'Manage Users', icon: Icons.people_alt_outlined, color: Colors.purple, onTap: () => _tab.animateTo(1)),
              _QuickNavCard(title: 'Marketplace', icon: Icons.storefront, color: Colors.blue, onTap: () => _tab.animateTo(2)),
              _QuickNavCard(title: 'Service Gigs', icon: Icons.work_outline, color: Colors.orange, onTap: () => _tab.animateTo(3)),
              _QuickNavCard(title: 'Food Ads', icon: Icons.restaurant, color: Colors.green, onTap: () => _tab.animateTo(4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostModerationTab(List<Map<String, dynamic>> posts, String category) {
    if (posts.isEmpty) return const Center(child: Text('No posts found.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final p = posts[i];
        final profile = p['profiles'] as Map<String, dynamic>?;
        final authorName = profile?['full_name'] ?? profile?['business_name'] ?? 'Unknown';
        final title = (p['market_title'] ?? p['content'] ?? '').toString();
        final postId = p['id'].toString();
        final isBusy = _busyPostIds.contains(postId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p['image_url'] != null)
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p['image_url'], width: 70, height: 70, fit: BoxFit.cover)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('By $authorName • ${p['created_at']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(p['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(onPressed: isBusy ? null : () => _softDeletePost(postId), icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserManagementTable() {
    final query = _userSearchCtrl.text.trim().toLowerCase();
    final visibleUsers = _allUsers.where((u) {
      final uid = (u['id'] ?? '').toString();
      final authInfo = _userAuthStatus[uid] ?? const <String, dynamic>{};
      final email = authInfo['email']?.toString().trim() ?? '';
      final rawName =
          (u['full_name'] ?? u['business_name'] ?? '').toString().trim();
      final name = rawName.isNotEmpty ? rawName : (email.isNotEmpty ? email : 'Unnamed');
      if (query.isEmpty) return true;
      return name.toLowerCase().contains(query) || email.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 700;
              final searchField = TextField(
                controller: _userSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (v) => setState(() {}),
              );
              final createButton = FilledButton.icon(
                onPressed: _showCreateUserDialog,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Create user'),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    createButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  createButton,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: visibleUsers.isEmpty
              ? const Center(child: Text('No users found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('User type')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Reports')),
                        DataColumn(label: Text('Blocked')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: visibleUsers.map((u) {
                        final uid = u['id'].toString();
                        final authInfo =
                            _userAuthStatus[uid] ?? const <String, dynamic>{};
                        final email = authInfo['email']?.toString().trim() ?? '';
                        final rawName =
                            (u['full_name'] ?? u['business_name'] ?? '').toString().trim();
                        final businessName =
                            (u['business_name'] ?? '').toString().trim();
                        final name = rawName.isNotEmpty
                            ? rawName
                            : (email.isNotEmpty ? email : 'Unnamed');
                        final myId = _db.auth.currentUser?.id;
                        final isMe = myId != null && uid == myId;
                        final disabled = u['is_disabled'] == true;
                        final verifiedValue = authInfo['verified'];
                        final isVerified = verifiedValue == true;
                        final isUnknownStatus = verifiedValue == null;
                        final accountType = (u['account_type'] ?? 'user').toString();
                        final jobTitle = (u['job_title'] ?? '').toString().trim();
                        final isBusy = _busyUserIds.contains(uid);
                        final reportCount = _userReportCounts[uid] ?? 0;
                        final blockedByCount = _userBlockedByCounts[uid] ?? 0;
                        final blocksMadeCount = _userBlocksMadeCounts[uid] ?? 0;

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: u['avatar_url'] != null
                                        ? NetworkImage(u['avatar_url'])
                                        : null,
                                    child: u['avatar_url'] == null
                                        ? const Icon(Icons.person, size: 18)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isMe ? '$name (You)' : name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (businessName.isNotEmpty)
                                          Text(
                                            businessName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  jobTitle.isNotEmpty
                                      ? '$accountType • $jobTitle'
                                      : accountType,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: SelectableText(
                                  email.isNotEmpty ? email : 'No email found',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                reportCount.toString(),
                                style: TextStyle(
                                  fontWeight: reportCount > 0 ? FontWeight.w800 : FontWeight.w500,
                                  color: reportCount > 0 ? Colors.red.shade700 : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                'By $blockedByCount / Made $blocksMadeCount',
                                style: TextStyle(
                                  fontWeight: (blockedByCount > 0 || blocksMadeCount > 0)
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: blockedByCount > 0 ? Colors.orange.shade800 : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isUnknownStatus
                                      ? Colors.grey.shade100
                                      : isVerified
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isUnknownStatus
                                        ? Colors.grey.shade300
                                        : isVerified
                                        ? Colors.green.shade200
                                        : Colors.orange.shade200,
                                  ),
                                ),
                                child: Text(
                                  isUnknownStatus
                                      ? 'Unknown'
                                      : (isVerified ? 'Verified' : 'Unverified'),
                                  style: TextStyle(
                                    color: isUnknownStatus
                                        ? Colors.grey.shade700
                                        : isVerified
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              isMe
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: const Text(
                                        'Protected',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: !disabled,
                                          onChanged: isBusy
                                              ? null
                                              : (v) => _setUserDisabled(uid, !v),
                                          activeTrackColor: Colors.green,
                                        ),
                                        if (!isVerified && !isUnknownStatus)
                                          IconButton(
                                            tooltip: 'Verify user',
                                            onPressed: isBusy ? null : () => _verifyUser(uid),
                                            icon: const Icon(
                                              Icons.verified_user_outlined,
                                              color: Colors.green,
                                            ),
                                          ),
                                        if (!isVerified && !isUnknownStatus)
                                          IconButton(
                                            tooltip: 'Resend verification email',
                                            onPressed: isBusy
                                                ? null
                                                : () => _resendVerification(uid),
                                            icon: const Icon(
                                              Icons.mark_email_unread_outlined,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        IconButton(
                                          onPressed: isBusy ? null : () => _deleteUser(uid),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        _StatusChips(value: _statusFilter, onChanged: _setFilter),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Post Reports', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._postReports.map((r) => _buildReportTile(r, 'post_reports')),
              const SizedBox(height: 20),
              const Text('User Reports', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._userReports.map((r) => _buildReportTile(r, 'user_reports')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportTile(Map<String, dynamic> r, String table) {
    return Card(
      child: ListTile(
        title: Text(r['reason'] ?? 'No reason'),
        subtitle: Text(r['details'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _setReportStatus(table: table, reportId: r['id'].toString(), status: 'reviewed')),
            IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => _setReportStatus(table: table, reportId: r['id'].toString(), status: 'dismissed')),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminLoginScreen() {
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 64, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text('Admin Access', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _password, focusNode: _passwordFocus, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: _adminLoginLoading ? null : _adminLogin, child: Text(_adminLoginLoading ? 'Entering...' : 'Sign In'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDeniedScreen() {
    return const Scaffold(body: Center(child: Text('Access Denied. Admins only.')));
  }
}

class _ModernStatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final bool isAlert;
  const _ModernStatCard({required this.title, required this.value, required this.icon, required this.color, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: isAlert ? Border.all(color: Colors.red, width: 2) : null, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      ),
    );
  }
}

class _QuickNavCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickNavCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [('pending', 'Pending'), ('reviewed', 'Reviewed'), ('dismissed', 'Dismissed')];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: items.map((e) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(e.$2), selected: value == e.$1, onSelected: (_) => onChanged(e.$1)),
        )).toList(),
      ),
    );
  }
}
