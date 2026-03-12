import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oralscan_ai/core/constants/platform_check.dart';
import 'package:oralscan_ai/features/camera_assistant/presentation/camera_guidance_io.dart'
    if (dart.library.html) 'package:oralscan_ai/features/camera_assistant/presentation/camera_guidance_web.dart' as guidance;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oralscan_ai/core/constants/quality_thresholds.dart';
import 'package:oralscan_ai/core/l10n/app_strings.dart';
import 'package:oralscan_ai/features/camera_assistant/domain/quality_state.dart';
import 'package:oralscan_ai/features/camera_assistant/data/quality_scorer.dart';
import 'package:oralscan_ai/features/analysis/data/api_client.dart';
import 'package:permission_handler/permission_handler.dart';

/// Asset paths for the 8 demo steps. Put your images in: apps/mobile/assets/demo/
/// Names: step_1.png, step_2.png, ... step_8.png (or .jpg)
const List<String> _demoStepAssets = [
  'assets/demo/step_1.png',
  'assets/demo/step_2.png',
  'assets/demo/step_3.png',
  'assets/demo/step_4.png',
  'assets/demo/step_5.png',
  'assets/demo/step_6.png',
  'assets/demo/step_7.png',
  'assets/demo/step_8.png',
];

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  /// macOS: use camera_macos instead of camera package.
  bool _useMacOSCamera = false;
  CameraMacOSController? _macOSController;
  final GlobalKey _macOSCameraKey = GlobalKey();
  String? _error;
  QualityState _qualityState = const QualityState();
  bool _isCapturing = false;
  DateTime? _captureReadySince;
  QualityScorer? _scorer;
  Timer? _guidanceTimer;
  bool _disposed = false;
  bool _guidanceRunning = false;
  bool _showDemoOverlay = true;

  final _analysisApi = AnalysisApiClient();

  @override
  void initState() {
    super.initState();
    _scorer = QualityScorer();
    _initCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    _guidanceTimer?.cancel();
    _controller?.dispose();
    _scorer?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    // macOS: use camera_macos (native AVKit); skip the standard camera plugin.
    if (isMacOS) {
      if (!_disposed) setState(() => _useMacOSCamera = true);
      return;
    }

    // On other platforms, permission_handler may not be implemented (e.g. macOS); skip and let the camera plugin trigger the system prompt.
    if (!kIsWeb) {
      try {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (!_disposed) setState(() => _error = AppStrings.cameraPermissionDenied);
          return;
        }
      } on MissingPluginException {
        // e.g. macOS: proceed to open camera, system will prompt if needed
      }
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (!_disposed) setState(() => _error = AppStrings.noCamerasFound);
        return;
      }
      final camera = _cameras!.first;
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (!_disposed) {
        setState(() {});
        if (!kIsWeb) _startGuidanceLoop();
      }
    } on MissingPluginException catch (_) {
      if (!_disposed) {
        setState(() => _error = AppStrings.cameraNotAvailable);
      }
    } catch (e) {
      if (!_disposed) setState(() => _error = e.toString());
    }
  }

  void _startGuidanceLoop() {
    if (_useMacOSCamera) return; // No live guidance for camera_macos
    _guidanceTimer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) => _runGuidanceStep(),
    );
  }

  Future<void> _runGuidanceStep() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing || _guidanceRunning) return;
    _guidanceRunning = true;
    try {
      final xFile = await _controller!.takePicture();
      final state = await guidance.runGuidanceStepWithFile(xFile, _scorer!);
      if (!_disposed && state != null) {
        setState(() => _qualityState = state);
        _checkAutoCapture();
      }
    } catch (_) {
      if (!_disposed) setState(() {});
    } finally {
      _guidanceRunning = false;
    }
  }

  void _checkAutoCapture() {
    if (!_qualityState.captureReady) {
      _captureReadySince = null;
      return;
    }
    final now = DateTime.now();
    _captureReadySince ??= now;
    final elapsed = now.difference(_captureReadySince!).inMilliseconds;
    if (elapsed >= QualityThresholds.stableDurationMs && !_isCapturing) {
      _captureReadySince = null;
      _captureAndUpload();
    }
  }

  Future<void> _captureAndUpload() async {
    // macOS: use camera_macos controller
    if (_useMacOSCamera && _macOSController != null) {
      if (_isCapturing) return;
      setState(() => _isCapturing = true);
      try {
        final file = await _macOSController!.takePicture();
        final bytes = file?.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          final jobId = await _analysisApi.uploadAndAnalyze(bytes);
          if (!_disposed && jobId != null) {
            if (mounted) context.go('/result/$jobId');
          } else if (!_disposed) {
            setState(() => _error = AppStrings.uploadFailed);
          }
        } else if (!_disposed) {
          setState(() => _error = AppStrings.uploadFailed);
        }
      } catch (e) {
        if (!_disposed) setState(() => _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString());
      } finally {
        if (!_disposed) setState(() => _isCapturing = false);
      }
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    _guidanceTimer?.cancel();

    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      final jobId = await _analysisApi.uploadAndAnalyze(bytes);
      if (!_disposed && jobId != null) {
        if (mounted) context.go('/result/$jobId');
      } else if (!_disposed) {
        setState(() => _error = AppStrings.uploadFailed);
      }
    } catch (e) {
      if (!_disposed) setState(() => _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString());
    } finally {
      if (!_disposed) {
        setState(() => _isCapturing = false);
        _startGuidanceLoop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 24),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () {
                      if (_error == AppStrings.cameraNotAvailable) {
                        context.go('/');
                      } else {
                        setState(() => _error = null);
                        _initCamera();
                      }
                    },
                    icon: Icon(
                      _error == AppStrings.cameraNotAvailable ? Icons.home_rounded : Icons.refresh,
                      size: 20,
                    ),
                    label: Text(
                      _error == AppStrings.cameraNotAvailable ? AppStrings.backToHome : AppStrings.tryAgain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // macOS: use camera_macos view; show loading until controller is ready.
    if (_useMacOSCamera) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            CameraMacOSView(
              key: _macOSCameraKey,
              fit: BoxFit.cover,
              cameraMode: CameraMacOSMode.photo,
              onCameraInizialized: (CameraMacOSController controller) {
                if (!_disposed) setState(() => _macOSController = controller);
              },
            ),
            if (_macOSController == null)
              Container(
                color: Theme.of(context).colorScheme.primary,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.openingCamera,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _CameraOverlay(qualityState: _qualityState, isCapturing: _isCapturing),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Colors.white),
                    onPressed: _isCapturing ? null : () => context.go('/'),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Material(
                    color: Colors.transparent,
                    child: FilledButton.icon(
                      onPressed: _isCapturing ? null : () => _captureAndUpload(),
                      icon: const Icon(Icons.camera_alt_rounded, size: 24),
                      label: const Text(AppStrings.takePicture),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showDemoOverlay) _DemoOverlay(onSkip: () => setState(() => _showDemoOverlay = false)),
          ],
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.openingCamera,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          _CameraOverlay(qualityState: _qualityState, isCapturing: _isCapturing),
          // Back button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Colors.white),
                  onPressed: _isCapturing ? null : () => context.go('/'),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Take picture button (manual capture)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Material(
                  color: Colors.transparent,
                  child: FilledButton.icon(
                    onPressed: _isCapturing
                        ? null
                        : () => _captureAndUpload(),
                    icon: const Icon(Icons.camera_alt_rounded, size: 24),
                    label: const Text(AppStrings.takePicture),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showDemoOverlay) _DemoOverlay(onSkip: () => setState(() => _showDemoOverlay = false)),
        ],
      ),
    );
  }
}

/// Demo overlay: 8-step image carousel + Skip button. Put images in assets/demo/ (step_1.png … step_8.png).
class _DemoOverlay extends StatefulWidget {
  const _DemoOverlay({required this.onSkip});

  final VoidCallback onSkip;

  @override
  State<_DemoOverlay> createState() => _DemoOverlayState();
}

class _DemoOverlayState extends State<_DemoOverlay> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  '${_currentPage + 1} / ${_demoStepAssets.length}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const PageScrollPhysics(),
                    itemCount: _demoStepAssets.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                _demoStepAssets[index],
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.white12,
                                  alignment: Alignment.center,
                                  child: Text(
                                    AppStrings.demoPlaceholderHint,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            // Invisible "Ignorez" (bottom left) — inside page so swipe works
                            Positioned(
                              left: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: widget.onSkip,
                                behavior: HitTestBehavior.opaque,
                                child: const SizedBox(width: 80, height: 56),
                              ),
                            ),
                            // Invisible "Passez à l'étape suivante" (bottom right)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () {
                                  if (_currentPage < _demoStepAssets.length - 1) {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                    );
                                  } else {
                                    widget.onSkip();
                                  }
                                },
                                behavior: HitTestBehavior.opaque,
                                child: const SizedBox(width: 140, height: 56),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _demoStepAssets.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == i ? 10 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: TextButton.icon(
                onPressed: widget.onSkip,
                icon: const Icon(Icons.skip_next_rounded, size: 20, color: Colors.white),
                label: Text(
                  AppStrings.skipDemo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraOverlay extends StatelessWidget {
  const _CameraOverlay({required this.qualityState, required this.isCapturing});

  final QualityState qualityState;
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dark vignette (Face ID style)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
          // Oval face guide + scanning arc (Apple Face ID style)
          Center(
            child: _AnimatedFaceIdFrame(
              isReady: qualityState.captureReady,
              showScanning: !qualityState.captureReady && qualityState.faceDetected,
            ),
          ),
          // Single instruction below frame (Face ID style)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child:                 isCapturing
                    ? _AnalyzingBubble()
                    : _FaceIdInstruction(instruction: AppStrings.instructionFromScorer(qualityState.instruction)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated oval frame with scanning line (Apple Face ID style).
class _AnimatedFaceIdFrame extends StatefulWidget {
  const _AnimatedFaceIdFrame({required this.isReady, required this.showScanning});

  final bool isReady;
  final bool showScanning;

  @override
  State<_AnimatedFaceIdFrame> createState() => _AnimatedFaceIdFrameState();
}

class _AnimatedFaceIdFrameState extends State<_AnimatedFaceIdFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 220,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _FaceIdFramePainter(
              isReady: widget.isReady,
              showScanning: widget.showScanning,
              scanProgress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

/// Apple Face ID–style oval frame with optional scanning arc.
class _FaceIdFramePainter extends CustomPainter {
  _FaceIdFramePainter({
    required this.isReady,
    required this.showScanning,
    this.scanProgress = 0.0,
  });

  final bool isReady;
  final bool showScanning;
  final double scanProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(140));
    final stroke = Paint()
      ..color = (isReady ? const Color(0xFF34C759) : Colors.white).withValues(alpha: isReady ? 0.9 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rrect, stroke);
    if (showScanning && !isReady) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.shortestSide / 2 - 4;
      const arcExtent = 0.22;
      final startAngle = scanProgress * 2 * 3.141592;
      final sweepAngle = arcExtent * 2 * 3.141592;
      final path = Path()..addArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle);
      final scanPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawPath(path, scanPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceIdFramePainter old) =>
      old.isReady != isReady || old.showScanning != showScanning || old.scanProgress != scanProgress;
}

/// Single line instruction below frame (Apple Face ID style).
class _FaceIdInstruction extends StatelessWidget {
  const _FaceIdInstruction({required this.instruction});

  final String instruction;

  @override
  Widget build(BuildContext context) {
    return Text(
      instruction,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _AnalyzingBubble extends StatefulWidget {
  @override
  State<_AnalyzingBubble> createState() => _AnalyzingBubbleState();
}

class _AnalyzingBubbleState extends State<_AnalyzingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 16 + (_controller.value * 8),
                spreadRadius: _controller.value * 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                  value: null,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                AppStrings.analyzing,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
