import 'package:dio/dio.dart';
import 'package:oralscan_ai/core/constants/api_config.dart';
import 'package:oralscan_ai/core/l10n/app_strings.dart';
import 'package:oralscan_ai/features/analysis/domain/job_status.dart';

class AnalysisApiClient {
  AnalysisApiClient() : _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  final Dio _dio;

  /// Uploads image bytes and starts analysis. Works on all platforms (including web).
  /// Returns jobId on success.
  Future<String?> uploadAndAnalyze(
    List<int> imageBytes, {
    String filename = 'capture.jpg',
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: filename,
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/analyze',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final jobId = response.data?['jobId'] as String?;
      return jobId;
    } on DioException catch (e) {
      final msg = _uploadErrorMessage(e);
      throw Exception(msg);
    } catch (e) {
      throw Exception(AppStrings.uploadFailedGeneric(e.toString()));
    }
  }

  static String _uploadErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return AppStrings.serverUnreachable;
      case DioExceptionType.connectionError:
        return AppStrings.cannotReachServer(apiBaseUrl);
      case DioExceptionType.badResponse:
        return AppStrings.uploadFailedStatus(e.response?.statusCode ?? 0);
      default:
        return AppStrings.uploadFailedGeneric(e.message ?? e.type.name);
    }
  }

  /// Polls job status and result.
  Future<JobStatusResponse?> getJobStatus(String jobId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/jobs/$jobId');
      return JobStatusResponse.fromJson(response.data!);
    } catch (_) {
      return null;
    }
  }

  /// Submits user info with jobId; stored on server with photo, score, report.
  Future<bool> submitForm({
    required String jobId,
    required String firstName,
    required String lastName,
    required String phone,
    required String dateOfBirth,
    String? gender,
    String? locationOfBirth,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/submit',
        data: {
          'jobId': jobId,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'dateOfBirth': dateOfBirth,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
          if (locationOfBirth != null && locationOfBirth.isNotEmpty) 'locationOfBirth': locationOfBirth,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return true;
    } on DioException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
