import 'package:oralscan_ai/features/analysis/domain/analysis_result.dart';

enum JobStatus { queued, processing, completed, failed }

class JobStatusResponse {
  const JobStatusResponse({
    required this.status,
    this.result,
    this.explanation,
    this.error,
  });

  final JobStatus status;
  final AnalysisResult? result;
  final Explanation? explanation;
  final String? error;

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'queued';
    JobStatus status;
    try {
      status = JobStatus.values.byName(statusStr);
    } catch (_) {
      status = JobStatus.queued;
    }
    AnalysisResult? result;
    if (json['result'] != null) {
      result = AnalysisResult.fromJson(json['result'] as Map<String, dynamic>);
    }
    Explanation? explanation;
    if (json['explanation'] != null) {
      explanation = Explanation.fromJson(json['explanation'] as Map<String, dynamic>);
    }
    return JobStatusResponse(
      status: status,
      result: result,
      explanation: explanation,
      error: json['error'] as String?,
    );
  }
}
