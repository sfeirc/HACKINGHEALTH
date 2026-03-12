/// Application principale Dent ta Maison : thème, routeur, demande de permissions au démarrage.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:oralscan_ai/core/router/app_router.dart';
import 'package:oralscan_ai/core/theme/app_theme.dart';

class OralScanApp extends ConsumerStatefulWidget {
  const OralScanApp({super.key});

  @override
  ConsumerState<OralScanApp> createState() => _OralScanAppState();
}

class _OralScanAppState extends ConsumerState<OralScanApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissionsEarly());
  }

  /// Demande caméra et photothèque dès l'affichage pour éviter un écran bloqué « Ouverture de l'appareil photo… ».
  Future<void> _requestPermissionsEarly() async {
    try {
      await Permission.camera.request();
      await Permission.photos.request();
    } catch (_) {
      // Ignoré (ex. macOS ou web où permission_handler peut être absent)
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Dent ta Maison',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
