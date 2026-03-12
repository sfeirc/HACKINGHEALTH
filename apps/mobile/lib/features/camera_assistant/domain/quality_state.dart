import 'package:freezed_annotation/freezed_annotation.dart';

part 'quality_state.freezed.dart';

@freezed
class QualityState with _$QualityState {
  const factory QualityState({
    @Default(false) bool faceDetected,
    @Default(false) bool mouthVisible,
    @Default(0.0) double framingScore,
    @Default(0.0) double brightnessScore,
    @Default(1.0) double blurScore,
    @Default(0.0) double stabilityScore,
    @Default(false) bool captureReady,
    @Default('Position your mouth in the frame') String instruction,
  }) = _QualityState;
}
