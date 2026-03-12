/// Mirrors shared-types analysis result and explanation for type-safe parsing.
class AnalysisResult {
  const AnalysisResult({
    required this.imageQuality,
    required this.screening,
    this.recommendation,
  });

  final ImageQualityResult imageQuality;
  final ScreeningResult screening;
  final RecommendationResult? recommendation;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      imageQuality: ImageQualityResult.fromJson(
        json['image_quality'] as Map<String, dynamic>,
      ),
      screening: ScreeningResult.fromJson(
        json['screening'] as Map<String, dynamic>,
      ),
      recommendation: json['recommendation'] != null
          ? RecommendationResult.fromJson(
              json['recommendation'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class ImageQualityResult {
  const ImageQualityResult({
    required this.usable,
    this.reasons = const [],
  });

  final bool usable;
  final List<String> reasons;

  factory ImageQualityResult.fromJson(Map<String, dynamic> json) {
    return ImageQualityResult(
      usable: json['usable'] as bool? ?? true,
      reasons: (json['reasons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class ScreeningResult {
  const ScreeningResult({
    required this.riskLevel,
    required this.confidence,
    this.findings = const [],
    this.hasCavity = false,
    this.cavityDangerScore = 0,
  });

  final String riskLevel;
  final double confidence;
  final List<FindingResult> findings;
  final bool hasCavity;
  final int cavityDangerScore;

  factory ScreeningResult.fromJson(Map<String, dynamic> json) {
    return ScreeningResult(
      riskLevel: json['risk_level'] as String? ?? 'low',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      findings: (json['findings'] as List<dynamic>?)
              ?.map((e) => FindingResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasCavity: json['has_cavity'] as bool? ?? false,
      cavityDangerScore: (json['cavity_danger_score'] as num?)?.toInt() ?? 0,
    );
  }
}

class FindingResult {
  const FindingResult({
    this.region = '',
    this.severity = 'low',
    this.confidence = 0,
  });

  final String region;
  final String severity;
  final double confidence;

  factory FindingResult.fromJson(Map<String, dynamic> json) {
    return FindingResult(
      region: json['region'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RecommendationResult {
  const RecommendationResult({
    required this.action,
    required this.message,
  });

  final String action;
  final String message;

  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    return RecommendationResult(
      action: json['action'] as String? ?? 'no_action',
      message: json['message'] as String? ?? '',
    );
  }
}

class Explanation {
  const Explanation({
    required this.summaryTitle,
    required this.summaryText,
    required this.nextAction,
    required this.retakeNeeded,
    this.reasoning,
  });

  final String summaryTitle;
  final String summaryText;
  final String nextAction;
  final bool retakeNeeded;
  /// Optional 2–4 sentence clinical reasoning (what was seen, why score/risk).
  final String? reasoning;

  factory Explanation.fromJson(Map<String, dynamic> json) {
    return Explanation(
      summaryTitle: json['summary_title'] as String? ?? '',
      summaryText: json['summary_text'] as String? ?? '',
      nextAction: json['next_action'] as String? ?? 'no_action',
      retakeNeeded: json['retake_needed'] as bool? ?? false,
      reasoning: json['reasoning'] as String?,
    );
  }
}
