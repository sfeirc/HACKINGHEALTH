import 'dart:io';

import 'package:camera/camera.dart';
import 'package:oralscan_ai/features/camera_assistant/data/quality_scorer.dart';
import 'package:oralscan_ai/features/camera_assistant/domain/quality_state.dart';

/// Runs guidance step using File (mobile/desktop only).
Future<QualityState?> runGuidanceStepWithFile(XFile xFile, QualityScorer scorer) async {
  final file = File(xFile.path);
  try {
    final state = await scorer.scoreFromFile(file);
    try {
      await file.delete();
    } catch (_) {}
    return state;
  } catch (_) {
    return null;
  }
}
