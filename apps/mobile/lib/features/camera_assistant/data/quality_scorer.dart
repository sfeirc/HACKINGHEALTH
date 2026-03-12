import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:oralscan_ai/core/constants/quality_thresholds.dart';
import 'package:oralscan_ai/features/camera_assistant/domain/quality_state.dart';

/// Computes quality state from a captured image file.
/// Uses ML Kit face detection; brightness and blur are computed from image pixels.
class QualityScorer {
  QualityScorer() : _faceDetector = FaceDetector(options: _faceOptions);

  static final _faceOptions = FaceDetectorOptions(
    performanceMode: FaceDetectorMode.fast,
    enableLandmarks: false,
    enableContours: false,
    enableTracking: false,
    minFaceSize: 0.15,
  );

  final FaceDetector _faceDetector;

  /// Mean luminance 0..1. Good range roughly 0.3–0.9.
  double _computeBrightness(img.Image image) {
    double sum = 0;
    int count = 0;
    const step = 8;
    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final p = image.getPixel(x, y);
        sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        count++;
      }
    }
    if (count == 0) return 0.5;
    final mean = sum / count;
    return (mean / 255).clamp(0.0, 1.0);
  }

  /// Blur amount 0..1 (0 = sharp, 1 = very blurry). Uses Laplacian variance.
  double _computeBlur(img.Image image) {
    final w = image.width;
    final h = image.height;
    if (w < 3 || h < 3) return 0.0;
    double sum = 0;
    double sumSq = 0;
    int n = 0;
    const step = 6;
    for (int y = 1; y < h - 1; y += step) {
      for (int x = 1; x < w - 1; x += step) {
        final c = image.getPixel(x, y);
        final g = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        final gL = image.getPixel(x - 1, y);
        final gR = image.getPixel(x + 1, y);
        final gT = image.getPixel(x, y - 1);
        final gB = image.getPixel(x, y + 1);
        final lap = -4 * g + (0.299 * gL.r + 0.587 * gL.g + 0.114 * gL.b) +
            (0.299 * gR.r + 0.587 * gR.g + 0.114 * gR.b) +
            (0.299 * gT.r + 0.587 * gT.g + 0.114 * gT.b) +
            (0.299 * gB.r + 0.587 * gB.g + 0.114 * gB.b);
        sum += lap;
        sumSq += lap * lap;
        n++;
      }
    }
    if (n < 2) return 0.0;
    final variance = (sumSq / n) - (sum / n) * (sum / n);
    const maxVar = 800.0;
    final blurAmount = 1.0 - (variance / maxVar).clamp(0.0, 1.0);
    return blurAmount;
  }

  Future<QualityState> scoreFromFile(File imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final faces = await _faceDetector.processImage(inputImage);

    final faceDetected = faces.isNotEmpty;
    final face = faces.isNotEmpty ? faces.first : null;
    final boundingBox = face?.boundingBox;
    final mouthVisible = faceDetected &&
        boundingBox != null &&
        boundingBox.width > 80 &&
        boundingBox.height > 100;

    double brightnessScore = 0.5;
    double blurScore = 0.5;
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        brightnessScore = _computeBrightness(decoded);
        blurScore = _computeBlur(decoded);
      }
    } catch (_) {
      // Keep defaults if decode fails
    }

    // Stability: still stubbed (would need previous frame comparison)
    const stubStability = 0.9;
    final framingScore = faceDetected ? 0.85 : 0.0;
    final stabilityScore = stubStability;

    final framingOk = framingScore >= QualityThresholds.framingMin;
    final brightnessOk = brightnessScore >= QualityThresholds.brightnessMin;
    final blurOk = blurScore <= QualityThresholds.blurMax;
    final stabilityOk = stabilityScore >= QualityThresholds.stabilityMin;

    final captureReady = faceDetected &&
        mouthVisible &&
        framingOk &&
        brightnessOk &&
        blurOk &&
        stabilityOk;

    String instruction;
    if (!faceDetected) {
      instruction = 'Position your mouth in the frame';
    } else if (!mouthVisible) {
      instruction = 'Open your mouth more';
    } else if (!framingOk) {
      instruction = 'Move closer';
    } else if (!brightnessOk) {
      instruction = 'More light needed';
    } else if (!blurOk) {
      instruction = 'Hold still';
    } else if (!stabilityOk) {
      instruction = 'Hold still';
    } else if (captureReady) {
      instruction = 'Hold still';
    } else {
      instruction = 'Position your mouth in the frame';
    }

    return QualityState(
      faceDetected: faceDetected,
      mouthVisible: mouthVisible,
      framingScore: framingScore,
      brightnessScore: brightnessScore,
      blurScore: blurScore,
      stabilityScore: stabilityScore,
      captureReady: captureReady,
      instruction: instruction,
    );
  }

  /// Live check: score from a camera stream frame. Uses face detection + Y-plane brightness (no full decode).
  /// [rotationDegrees] from controller.value.deviceOrientation (0, 90, 180, 270).
  Future<QualityState> scoreFromCameraImage(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    final rotation = _rotationFromDegrees(rotationDegrees);
    final format = _imageFormatFromCamera(image);
    if (format == null) return _defaultState();

    if (image.width < 32 || image.height < 32) return _defaultState();

    final InputImage inputImage;
    try {
      final Uint8List bytes;
      final int bytesPerRow;
      if (image.planes.length == 1) {
        bytes = image.planes[0].bytes;
        bytesPerRow = image.planes[0].bytesPerRow;
      } else {
        final concat = <int>[];
        for (final p in image.planes) {
          concat.addAll(p.bytes);
        }
        bytes = Uint8List.fromList(concat);
        bytesPerRow = image.planes[0].bytesPerRow;
      }
      inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      );
    } catch (_) {
      return _defaultState();
    }

    List<Face> faces;
    try {
      faces = await _faceDetector.processImage(inputImage);
    } catch (_) {
      return _defaultState();
    }

    final faceDetected = faces.isNotEmpty;
    final face = faces.isNotEmpty ? faces.first : null;
    final boundingBox = face?.boundingBox;
    final mouthVisible = faceDetected &&
        boundingBox != null &&
        boundingBox.width > 80 &&
        boundingBox.height > 100;

    double brightnessScore = 0.5;
    if (image.planes.isNotEmpty) {
      final yPlane = image.planes.first.bytes;
      if (yPlane.isNotEmpty) {
        int sum = 0;
        const step = 16;
        for (int i = 0; i < yPlane.length; i += step) {
          sum += yPlane[i];
        }
        final mean = sum / (yPlane.length / step).clamp(1, 1 << 20);
        brightnessScore = (mean / 255).clamp(0.0, 1.0);
      }
    }

    const blurScore = 0.3;
    const stubStability = 0.9;
    final framingScore = faceDetected ? 0.85 : 0.0;
    final stabilityScore = stubStability;

    final framingOk = framingScore >= QualityThresholds.framingMin;
    final brightnessOk = brightnessScore >= QualityThresholds.brightnessMin;
    final blurOk = blurScore <= QualityThresholds.blurMax;
    final stabilityOk = stabilityScore >= QualityThresholds.stabilityMin;

    final captureReady = faceDetected &&
        mouthVisible &&
        framingOk &&
        brightnessOk &&
        blurOk &&
        stabilityOk;

    String instruction;
    if (!faceDetected) {
      instruction = 'Position your mouth in the frame';
    } else if (!mouthVisible) {
      instruction = 'Open your mouth more';
    } else if (!framingOk) {
      instruction = 'Move closer';
    } else if (!brightnessOk) {
      instruction = 'More light needed';
    } else if (!blurOk) {
      instruction = 'Hold still';
    } else if (!stabilityOk) {
      instruction = 'Hold still';
    } else if (captureReady) {
      instruction = 'Hold still';
    } else {
      instruction = 'Position your mouth in the frame';
    }

    return QualityState(
      faceDetected: faceDetected,
      mouthVisible: mouthVisible,
      framingScore: framingScore,
      brightnessScore: brightnessScore,
      blurScore: blurScore,
      stabilityScore: stabilityScore,
      captureReady: captureReady,
      instruction: instruction,
    );
  }

  InputImageRotation _rotationFromDegrees(int deg) {
    switch (deg) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat? _imageFormatFromCamera(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv420;
      case ImageFormatGroup.nv21:
        return InputImageFormat.nv21;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return kIsWeb ? null : (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);
    }
  }

  QualityState _defaultState() => const QualityState(
        instruction: 'Position your mouth in the frame',
      );

  void dispose() {
    _faceDetector.close();
  }
}
