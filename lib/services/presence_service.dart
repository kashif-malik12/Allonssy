import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  static const Duration _heartbeatInterval = Duration(minutes: 1);

  Timer? _heartbeatTimer;
  AppLifecycleState? _lifecycleState;
  bool _started = false;
  bool _touchInFlight = false;

  void start() {
    if (_started) {
      _updateHeartbeatState();
      return;
    }

    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    _updateHeartbeatState();
    unawaited(_touchPresence());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _updateHeartbeatState();
    if (_isForeground) {
      unawaited(_touchPresence());
    }
  }

  bool get _isForeground {
    final state = _lifecycleState;
    return state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  void _updateHeartbeatState() {
    if (!_started || !_isForeground) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      return;
    }

    if (_heartbeatTimer != null && _heartbeatTimer!.isActive) return;

    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(_touchPresence()),
    );
  }

  Future<void> _touchPresence() async {
    if (_touchInFlight) return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    _touchInFlight = true;
    try {
      await Supabase.instance.client.rpc('touch_my_presence');
    } catch (_) {
      // Presence updates are non-blocking.
    } finally {
      _touchInFlight = false;
    }
  }
}
