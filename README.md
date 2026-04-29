# dijji_firebase

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

One-line Firebase Cloud Messaging glue for the
[Dijji Flutter SDK](https://github.com/urbaneyed/dijji-flutter).

```yaml
dependencies:
  dijji: ^1.1.0-alpha
  dijji_firebase: ^1.0.0-alpha
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.0
```

```dart
import 'package:dijji/dijji.dart';
import 'package:dijji_firebase/dijji_firebase.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Dijji.instance.initialize(siteKey: 'ws_abc123');
  await DijjiFirebase.instance.attach();

  runApp(const MyApp());
}
```

That's the integration. After `attach()`:

- FCM / APNs token is fetched and forwarded to `Dijji.instance.registerPushToken`.
- Token rotates are forwarded automatically via `onTokenRefresh`.
- `push_received` fires on every foreground message (so your dashboard's
  open-rate denominator stays accurate).
- `push_opened` fires when the user taps a notification, including the cold-
  start tap path via `getInitialMessage`.
- Deep links from `data.deep_link` / `data.url` are stamped onto the
  `push_opened` event for downstream handling.

## Custom payload keys

Default keys read from `RemoteMessage.data` are `dijji_push_id` and
`dijji_trigger_id` (matches what the Dijji backend stamps). Override:

```dart
await DijjiFirebase.instance.attach(
  pushIdKey: 'my_push_id',
  triggerIdKey: 'my_trigger_id',
);
```

## Permission prompting

`attach()` calls `FirebaseMessaging.instance.requestPermission()` by default.
If your app prompts the user later in the journey, skip it:

```dart
await DijjiFirebase.instance.attach(requestPermission: false);
```

## License

Apache 2.0.
