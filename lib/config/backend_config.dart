import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for the citizen app to reach the Node/PostgreSQL backend
/// (`lib/web/backend_server`).
///
/// `localhost` only ever means "this device" — on a physical phone or an
/// Android emulator it never points at the development machine, so every
/// citizen-side HTTP/Socket.IO call must use the PC's actual LAN IP instead.
/// Update [lanIp] whenever it changes (new WiFi network, DHCP renewal,
/// etc.) via `ipconfig` (Windows) — look for the WiFi adapter's IPv4
/// address. When the citizen app itself is run as a Flutter *web* build
/// (`flutter run -d chrome`), it's a browser tab on the same machine as the
/// backend — same situation as the web dashboard (`lib/web/*`) — so it
/// correctly uses `localhost` instead and is not affected by [lanIp].
class BackendConfig {
  static const String lanIp = '192.168.8.185';
  static const String baseUrl = kIsWeb ? 'http://localhost:3000' : 'http://$lanIp:3000';
}
