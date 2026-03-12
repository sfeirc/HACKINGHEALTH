import 'package:camera/camera.dart';
import 'package:oralscan_ai/features/camera_assistant/data/quality_scorer.dart';
import 'package:oralscan_ai/features/camera_assistant/domain/quality_state.dart';

/// No-op on web (dart:io not available). Live guidance only on mobile/desktop.
Future<QualityState?> runGuidanceStepWithFile(XFile xFile, QualityScorer scorer) async =>
    null;
