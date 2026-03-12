import 'dart:io';

/// API base URL.
/// - macOS app: localhost (same machine as server).
/// - iPhone/Android on same Wi‑Fi: your computer's LAN IP (see below).
/// Find your Mac's IP: System Settings → Network → Wi‑Fi → Details, or run: ipconfig getifaddr en0
const String _kLanHost = '192.0.0.2'; // ← Change to your Mac's IP when running app on iPhone

final String apiBaseUrl = Platform.isMacOS
    ? 'http://127.0.0.1:3000'
    : 'http://$_kLanHost:3000';
