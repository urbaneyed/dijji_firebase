/// Optional Firebase Cloud Messaging glue for `package:dijji`.
///
/// Wires `firebase_messaging` callbacks into Dijji's existing push surface
/// so a typical app only needs:
///
/// ```dart
/// await Firebase.initializeApp();
/// await Dijji.instance.initialize(siteKey: 'ws_abc123');
/// await DijjiFirebase.attach();
/// ```
///
/// What `attach()` does on your behalf:
///   • requests notification permission (iOS) or registers the channel
///     (Android default channel)
///   • calls `FirebaseMessaging.instance.getToken()` and forwards via
///     `Dijji.instance.registerPushToken`
///   • re-registers on `onTokenRefresh`
///   • fires `push_received` from the foreground / background message
///     listeners, stamped with `dijji_push_id` if present in the payload
///   • fires `push_opened` when the app launches from a notification tap
///   • exposes a getter for the deep-link URL (if any) attached to the push
///
/// The package depends only on `dijji` ^1.1.0-alpha + `firebase_messaging`
/// ^15.x; no platform-specific scaffolding of its own.
library dijji_firebase;

export 'src/dijji_firebase.dart' show DijjiFirebase;
