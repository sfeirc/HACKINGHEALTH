/// Point d'entrée de l'application Dent ta Maison (Flutter).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oralscan_ai/app/app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: OralScanApp(),
    ),
  );
}
