import 'dart:async';

import 'package:dijji/dijji.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Optional thin glue between `firebase_messaging` and the Dijji SDK.
/// The Dijji core SDK never pulls Firebase as a dependency; you opt in by
/// adding this package separately.
///
/// Lifecycle note: `attach` is idempotent — calling it twice is a no-op.
/// Detach is provided primarily for tests; production apps don't need it.
class DijjiFirebase {
  DijjiFirebase._();

  static final DijjiFirebase _instance = DijjiFirebase._();
  static DijjiFirebase get instance => _instance;

  bool _attached = false;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  /// Wire Firebase Cloud Messaging into Dijji.
  ///
  /// - `requestPermission`: defaults to true. Set false if your app already
  ///   prompts the user for notification permission via its own UX, or if
  ///   you're requesting permission later in the journey.
  /// - `pushIdKey`: the key in `RemoteMessage.data` that carries Dijji's
  ///   push id. Default `dijji_push_id` matches what the Dijji backend stamps
  ///   in `dijji_pushes`.
  /// - `triggerIdKey`: similar, for `trigger_id`. Default `dijji_trigger_id`.
  Future<DijjiFirebaseAttachResult> attach({
    bool requestPermission = true,
    String pushIdKey = 'dijji_push_id',
    String triggerIdKey = 'dijji_trigger_id',
  }) async {
    if (_attached) return DijjiFirebaseAttachResult._already();
    _attached = true;

    if (!Dijji.instance.isInitialized) {
      // Don't throw — the SDK contract everywhere else is "log a warning,
      // no-op". A misordered DijjiFirebase.attach() shouldn't crash the app.
      debugPrint('[dijji_firebase] attach() called before Dijji.initialize() — skipping');
      return DijjiFirebaseAttachResult._notReady();
    }

    final fcm = FirebaseMessaging.instance;

    // Permission. On Android the call is a no-op pre-13 and a system prompt
    // on 13+. On iOS this prompts the user once per install.
    if (requestPermission) {
      try {
        await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      } catch (e) {
        debugPrint('[dijji_firebase] requestPermission failed: $e');
      }
    }

    // Initial token. Best-effort — APNs sandbox tokens can take a few seconds
    // to materialize on first launch; the onTokenRefresh stream catches us
    // up afterwards.
    try {
      final token = await fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await Dijji.instance.registerPushToken(token);
      }
    } catch (e) {
      debugPrint('[dijji_firebase] initial getToken failed: $e');
    }

    _onTokenRefreshSub = fcm.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      try {
        await Dijji.instance.registerPushToken(token);
      } catch (e) {
        debugPrint('[dijji_firebase] onTokenRefresh forward failed: $e');
      }
    });

    // Foreground messages — Dijji fires push_received even when the OS
    // doesn't render a banner (because the app is foregrounded). Helps the
    // open-rate denominator stay accurate.
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
      _firePushEvent('push_received', msg, pushIdKey, triggerIdKey);
    });

    // App launched / brought back from a tap. Equivalent to Android's
    // `dijji_from_push` PendingIntent extras.
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _firePushEvent('push_opened', msg, pushIdKey, triggerIdKey);
    });

    // Cold-start tap — getInitialMessage returns the message that launched
    // the app, exactly once per launch. Ignored if the app started normally.
    try {
      final initial = await fcm.getInitialMessage();
      if (initial != null) {
        _firePushEvent('push_opened', initial, pushIdKey, triggerIdKey);
      }
    } catch (e) {
      debugPrint('[dijji_firebase] getInitialMessage failed: $e');
    }

    return DijjiFirebaseAttachResult._ok();
  }

  /// Tear down stream subscriptions. Mostly useful for tests; production apps
  /// don't need to call this.
  Future<void> detach() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedSub = null;
    _onTokenRefreshSub = null;
    _attached = false;
  }

  void _firePushEvent(
    String event,
    RemoteMessage msg,
    String pushIdKey,
    String triggerIdKey,
  ) {
    final data = msg.data;
    final pushId = data[pushIdKey] as String?;
    final triggerId = data[triggerIdKey] as String?;
    final extra = <String, Object?>{};
    if (msg.notification?.title != null) {
      extra['notification_title'] = msg.notification!.title;
    }
    if (msg.notification?.body != null) {
      extra['notification_body'] = msg.notification!.body;
    }
    final deepLink = data['deep_link'] ?? data['url'];
    if (deepLink is String && deepLink.isNotEmpty) {
      extra['deep_link'] = deepLink;
    }
    Dijji.instance.trackPushEvent(
      event,
      pushId: pushId,
      triggerId: triggerId,
      extra: extra.isEmpty ? null : extra,
    );
  }
}

/// Result of [DijjiFirebase.attach]. Tells you whether the attach was a
/// fresh wire-up, a duplicate, or skipped because Dijji wasn't ready.
class DijjiFirebaseAttachResult {
  DijjiFirebaseAttachResult._(this.state);
  factory DijjiFirebaseAttachResult._ok() =>
      DijjiFirebaseAttachResult._(DijjiFirebaseAttachState.attached);
  factory DijjiFirebaseAttachResult._already() =>
      DijjiFirebaseAttachResult._(DijjiFirebaseAttachState.alreadyAttached);
  factory DijjiFirebaseAttachResult._notReady() =>
      DijjiFirebaseAttachResult._(DijjiFirebaseAttachState.dijjiNotInitialized);

  final DijjiFirebaseAttachState state;

  bool get ok => state == DijjiFirebaseAttachState.attached;
}

enum DijjiFirebaseAttachState { attached, alreadyAttached, dijjiNotInitialized }
