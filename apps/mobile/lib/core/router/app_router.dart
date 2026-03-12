import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oralscan_ai/features/analysis/presentation/result_screen.dart';
import 'package:oralscan_ai/features/camera_assistant/presentation/camera_screen.dart';
import 'package:oralscan_ai/features/home/presentation/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/result/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId']!;
          return ResultScreen(jobId: jobId);
        },
      ),
    ],
  );
});
