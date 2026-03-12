/// Thresholds for auto-capture. Adjust for UX.
abstract class QualityThresholds {
  static const double framingMin = 0.7;
  static const double brightnessMin = 0.5;
  static const double blurMax = 0.3;
  static const double stabilityMin = 0.8;
  static const int stableDurationMs = 500;
}