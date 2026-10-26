import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:guin_app/config/supabase_config.dart';
import 'package:guin_app/providers/notification_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Push notifications (Firebase Cloud Messaging) — Android only today.
///
/// Design rules, matching the rest of this codebase:
///
///  * **Never block, never throw.** Every entry point is best-effort and
///    swallows errors with a `debugPrint`. A missing Firebase project, an
///    offline device or a denied permission can only mean "no push", never a
///    broken app.
///  * **Additive.** The in-app notification row is still written by
///    `NotificationService` exactly as before; push is a side-channel on top of
///    it, so the notification bell and realtime feed keep working untouched.
///  * **Opt-in config.** Firebase only initializes when
///    `android/app/google-services.json` exists (see PUSH_NOTIFICATIONS.md), so
///    a checkout without a Firebase project runs unchanged.
///  * **Tokens are device-scoped.** The app does not use Supabase Auth, so a
///    token row is keyed by `users_profile.id` + the FCM token. Sign-out deletes
///    this device's rows.
///
/// The server half lives in `supabase/functions/push/`.
class PushService {
  PushService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  /// Read-lookups handed over by `main()` so a foreground push can refresh the
  /// bell without a BuildContext (this service is not a widget and cannot read
  /// providers itself). Both are null in tests and before the first build, in
  /// which case the foreground reaction is simply skipped.
  static Future<NotificationProvider?> Function()? _readNotificationProvider;
  static Future<String?> Function()? _readUserId;

  /// Bind the app's provider accessors. Called from the root widget's builder.
  static void bindProviderAccess({
    required Future<NotificationProvider?> Function() readNotificationProvider,
    required Future<String?> Function() readUserId,
  }) {
    _readNotificationProvider = readNotificationProvider;
    _readUserId = readUserId;
  }

  // ── Configuration ───────────────────────────────────────────────────────

  /// Table holding one row per (user, device) FCM token. Additive schema lives
  /// in supabase/migrations/20261025_device_push_tokens.sql.
  static const String table = 'device_push_tokens';

  /// Android notification channel the app creates and the manifest points FCM
  /// at (`default_notification_channel_id`).
  static const String channelId = 'citeease_default';
  static const String channelName = 'Barangay CiteEase';
  static const String channelDescription =
      'Document updates, approvals, payments and barangay announcements.';

  // ── State ───────────────────────────────────────────────────────────────

  /// True once Firebase initialized AND a device token is in hand. False means
  /// "this build/device has no push" — never an error.
  static bool _ready = false;
  static String? _token;
  static String? _registeredUserId;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedSub;
  static void Function()? _notifyHandler;

  static bool get isReady => _ready;
  static String? get token => _token;

  /// Last user the device token was registered for (null after sign-out).
  static String? get registeredUserId => _registeredUserId;

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Called once from `main()` after Supabase is up and before `runApp`.
  ///
  /// Does everything that does NOT require a signed-in user: initializes
  /// Firebase (if configured), sets up the notification channel and the
  /// foreground/opened handlers, and requests notification permission.
  /// The token is registered later by [registerForUser] once login is known.
  static Future<void> initialize() async {
    // Android only for now: iOS/macOS need GoogleService-Info.plist plus an
    // APNs key, and web needs a service worker + VAPID keys. Guarding here
    // keeps desktop/web/CI builds completely inert.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('PushService: push is Android-only in this build — skipping.');
      return;
    }
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Expected when android/app/google-services.json is absent.
      debugPrint(
        'PushService: Firebase not configured, push disabled. '
        'See PUSH_NOTIFICATIONS.md. ($e)',
      );
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ shows a runtime prompt; below that this resolves as
      // authorized without asking. Either answer is fine — in-app
      // notifications keep working regardless.
      try {
        final settings = await messaging.requestPermission();
        debugPrint(
          'PushService: notification permission = '
          '${settings.authorizationStatus.name}',
        );
      } catch (e) {
        debugPrint('PushService: permission request failed: $e');
      }

      // The notification channel itself is declared in AndroidManifest.xml.
      try {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        debugPrint('PushService: presentation options failed: $e');
      }

      _listenOpened(messaging);

      _token = await messaging.getToken();
      _ready = _token != null;
      if (_ready) {
        attachPushListener();
      }
      debugPrint(
        _ready
            ? 'PushService: ready (token acquired)'
            : 'PushService: no device token (push inactive)',
      );
    } catch (e) {
      // getToken can fail on a misconfigured project; stay disabled and quiet.
      debugPrint('PushService: FCM setup failed, push disabled. ($e)');
      _ready = false;
    }
  }

  // ── Registration ────────────────────────────────────────────────────────

  /// Upsert this device's token for [userId] and keep it fresh.
  ///
  /// Safe to call on every login and on every session restore — it is an
  /// idempotent upsert keyed by the token. Never throws.
  static Future<void> registerForUser(String userId) async {
    if (!_ready || userId.isEmpty) return;
    try {
      final service = PushService();
      await service.upsertToken(userId: userId);
      _registeredUserId = userId;

      // Token rotation: FCM can hand out a new token at any time. Re-point the
      // stored row at the same user so pushes keep arriving.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          _token = newToken;
          try {
            await service.upsertToken(userId: userId);
            debugPrint('PushService: refreshed token re-registered.');
          } catch (e) {
            debugPrint('PushService: token refresh registration failed: $e');
          }
        },
        onError: (Object e) =>
            debugPrint('PushService: token refresh stream error: $e'),
      );
    } catch (e) {
      debugPrint('PushService: registerForUser failed: $e');
    }
  }

  /// Forget this device on sign-out so the next account on this phone does not
  /// keep receiving the previous user's pushes. Never throws.
  static Future<void> unregisterForUser([String? userId]) async {
    try {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      final target = userId ?? _registeredUserId;
      if (target != null && target.isNotEmpty && _token != null) {
        await PushService().deleteTokenRow(userId: target, token: _token!);
      }
      _registeredUserId = null;
      debugPrint('PushService: device unregistered for push.');
    } catch (e) {
      debugPrint('PushService: unregister failed: $e');
    }
  }

  /// Drop the Firebase-side token too (used when an account is deleted or the
  /// device is handed over). The row deletion is done by [unregisterForUser].
  static Future<void> deleteDeviceToken() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      _token = null;
      _ready = false;
    } catch (e) {
      debugPrint('PushService: deleteToken failed: $e');
    }
  }

  // ── Supabase row operations ─────────────────────────────────────────────

  /// Insert-or-update this device's token row for [userId]. Concrete
  /// (instance) method so it can be unit-tested against a fake client.
  Future<void> upsertToken({required String userId, String? token}) async {
    final value = token ?? _token;
    if (value == null || value.isEmpty) return;
    await _client.from(table).upsert({
      'user_id': userId,
      'token': value,
      'platform': _platform,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  /// Remove this device's token row for [userId].
  Future<void> deleteTokenRow({
    required String userId,
    required String token,
  }) async {
    await _client.from(table).delete().eq('user_id', userId).eq('token', token);
  }

  /// Remove every token for [userId] (e.g. the account was rejected/deleted).
  Future<void> deleteAllForUser(String userId) async {
    await _client.from(table).delete().eq('user_id', userId);
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /// Hook the app's live notification feed to FCM so a push that arrives while
  /// the app is foregrounded is applied immediately.
  ///
  /// Without this, a foreground push is silently dropped by Android (it only
  /// auto-displays when the app is backgrounded) and the bell badge waits for
  /// the Supabase realtime event. Both paths produce the same row, so this is
  /// additive: it never writes to the database, it only asks the provider to
  /// reload, which is idempotent. Safe to call repeatedly — only the first call
  /// has an effect.
  static void attachPushListener() {
    if (!_ready) return;
    _notifyHandler ??= _defaultNotifyHandler;
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'PushService: foreground push "${message.notification?.title ?? ''}"',
      );
      _notifyHandler?.call();
    }, onError: (Object e) => debugPrint('PushService: foreground error: $e'));
  }

  /// Override the foreground reaction (tests, or a screen that wants to show an
  /// in-app banner instead of just refreshing the bell).
  static void setNotifyHandler(void Function()? handler) {
    _notifyHandler = handler;
  }

  static void _defaultNotifyHandler() {
    final readProvider = _readNotificationProvider;
    final readUser = _readUserId;
    if (readProvider == null || readUser == null) return;
    unawaited(() async {
      try {
        final userId = await readUser();
        if (userId == null) return;
        final provider = await readProvider();
        await provider?.refresh(userId);
      } catch (e) {
        debugPrint('PushService: foreground refresh failed: $e');
      }
    }());
  }

  static String get _platform => 'android'; // this feature is Android-only

  /// While the app is foregrounded Android does not draw the notification
  /// itself; the row is inserted by `NotificationService` and the bell badge
  /// updates over the existing realtime subscription. [attachPushListener]
  /// additionally refreshes the bell as soon as the push arrives.
  ///
  /// Tap on a push that launched or resumed the app. Deep-linking into the
  /// right screen (request detail, announcements...) is deliberately NOT wired
  /// yet: it needs navigator plumbing that is out of scope for the first cut,
  /// and the tap already opens the app whose bell is up to date.
  static void _listenOpened(FirebaseMessaging messaging) {
    _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        'PushService: push tapped (data=${message.data}) — opening app as-is.',
      );
    }, onError: (Object e) => debugPrint('PushService: opened error: $e'));
  }
}
