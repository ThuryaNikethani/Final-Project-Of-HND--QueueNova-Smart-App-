/// Base URL for the citizen mobile app to reach the Node/PostgreSQL backend
/// (`lib/web/backend_server`).
///
/// `localhost` only ever means "this device" — on a physical phone or an
/// Android emulator it never points at the development machine, so every
/// citizen-side HTTP/Socket.IO call must use the PC's actual LAN IP instead.
/// Update [lanIp] whenever it changes (new WiFi network, DHCP renewal,
/// etc.) via `ipconfig` (Windows) — look for the WiFi adapter's IPv4
/// address. The web dashboard (`lib/web/*`) runs in a browser on the same
/// machine as the backend, so it correctly keeps using `localhost` and is
/// not affected by this.
class BackendConfig {
  static const String lanIp = '192.168.1.103';
  static const String baseUrl = 'http://$lanIp:3000';
}
