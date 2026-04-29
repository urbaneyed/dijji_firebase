# Changelog

## 1.0.0-alpha · 2026-04-29

Initial alpha. One-line FCM/APNs integration for the Dijji Flutter SDK.

- `DijjiFirebase.instance.attach()` — fetch initial token, register on
  Dijji, subscribe to `onTokenRefresh`, wire `push_received` from
  foreground messages, wire `push_opened` from tap callbacks, surface
  deep links.
- `DijjiFirebase.instance.detach()` — tear down for tests.
- Customisable payload keys for `pushId` / `triggerId`.
- Optional skip of permission prompt for apps that prompt elsewhere.

Depends on `dijji >=1.0.0-alpha <2.0.0`.
