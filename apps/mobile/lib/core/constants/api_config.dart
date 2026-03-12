// Base URL for the analysis API.
// macOS app (same machine): http://127.0.0.1:3000
// Android emulator: http://10.0.2.2:3000 (change in api_config_io.dart if needed)
// Physical phone: http://YOUR_COMPUTER_LAN_IP:3000 (phone and computer on same Wi‑Fi)
import 'api_config_io.dart' if (dart.library.html) 'api_config_stub.dart' as api_config_impl;

String get apiBaseUrl => api_config_impl.apiBaseUrl;
