import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for the citizen app to reach the Node/PostgreSQL backend
/// (`lib/web/backend_server`).
///
/// `localhost` only ever means "this device" — on a physical phone or an
/// Android emulator it never points at the development machine. Two ways
/// to bridge that, toggled by [useAdbReverse]:
///
/// - USB + `adb reverse tcp:3000 tcp:3000` (run once per USB session):
///   the phone's own `localhost:3000` gets forwarded to the PC over the
///   cable, so `useAdbReverse = true` works regardless of WiFi — use this
///   when the phone and PC aren't on the same network.
/// - Same WiFi network: set `useAdbReverse = false` and keep [lanIp]
///   updated to the PC's current WiFi IPv4 (`ipconfig` on Windows) — needed
///   whenever that changes (new WiFi network, DHCP renewal, etc).
///
/// When the citizen app itself is run as a Flutter *web* build
/// (`flutter run -d chrome`), it's a browser tab on the same machine as the
/// backend — same situation as the web dashboard (`lib/web/*`) — so it
/// correctly uses `localhost` instead and is not affected by either setting.
class BackendConfig {
  static const bool useAdbReverse = false;
  static const String lanIp = '192.168.8.185';
  static const String baseUrl = kIsWeb || useAdbReverse ? 'http://localhost:3000' : 'http://$lanIp:3000';
}
