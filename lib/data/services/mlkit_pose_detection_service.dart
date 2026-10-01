import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;

import '../../core/filters/one_euro_filter.dart';
import '../../domain/models/pose_models.dart' as rehab;
import '../../domain/services/movement_features.dart';
import 'camera_service.dart';
import 'pose_detection_service.dart';

class MlKitPoseDetectionService implements PoseDetectionService {
  static const _measurableJoints = {
    'nose',
    'leftEyeInner',
    'leftEye',
    'leftEyeOuter',
    'rightEyeInner',
    'rightEye',
    'rightEyeOuter',
    'leftEar',
    'rightEar',
    'leftMouth',
    'rightMouth',
    'leftShoulder',
    'rightShoulder',
    'shoulder',
    'leftElbow',
    'rightElbow',
    'leftWrist',
    'rightWrist',
    'leftThumb',
    'rightThumb',
    'leftIndex',
    'rightIndex',
    'leftPinky',
    'rightPinky',
    'leftHip',
    'rightHip',
    'hip',
    'leftKnee',
    'rightKnee',
    'knee',
    'leftAnkle',
    'rightAnkle',
    'ankle',
    'leftHeel',
    'rightHeel',
    'leftFootIndex',
    'rightFootIndex',
  };

  final mlkit.PoseDetector _detector = mlkit.PoseDetector(
    options: mlkit.PoseDetectorOptions(
      mode: mlkit.PoseDetectionMode.stream,
      model: mlkit.PoseDetectionModel.base,
    ),
  );

  final LandmarkTemporalFilter _temporalFilter = LandmarkTemporalFilter();

  bool _initialized = false;
  bool _busy = false;
  bool _disposed = false;
  DateTime? _lastProcessed;

  @override
  bool get isConfigured => _initialized && !_disposed;

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    _temporalFilter.reset();
    _initialized = true;
  }

  @override
  Future<rehab.PoseFrame?> processFrame(Object frame) async {
    if (!isConfigured || _busy || frame is! CameraFrame) return null;
    final now = DateTime.now();

    // Responsive processing interval (up to ~25-30 fps, min 33ms)
    if (_lastProcessed != null && now.difference(_lastProcessed!).inMilliseconds < 33) {
      return null;
    }

    final input = _inputImage(frame);
    if (input == null) return null;

    _busy = true;
    _lastProcessed = now;

    try {
      final poses = await _detector.processImage(input);
      if (poses.isEmpty || _disposed) return null;

      // Multi-person protection (Requirements 23 & 59)
      if (poses.length > 1) {
        return rehab.PoseFrame(
          timestamp: now,
          landmarks: const {},
          imageWidth: frame.image.width,
          imageHeight: frame.image.height,
          personCount: poses.length,
          isMultiPerson: true,
        );
      }

      final rotation = _computeRotation(frame);
      final isRotated90or270 = rotation == mlkit.InputImageRotation.rotation90deg ||
          rotation == mlkit.InputImageRotation.rotation270deg;
      final analyzedWidth = isRotated90or270 ? frame.image.height : frame.image.width;
      final analyzedHeight = isRotated90or270 ? frame.image.width : frame.image.height;

      final rawLandmarks = <String, rehab.PoseLandmark>{};
      for (final entry in poses.first.landmarks.entries) {
        if (!_measurableJoints.contains(entry.key.name)) continue;
        final landmark = entry.value;
        final rawX = landmark.x.toDouble();
        final rawY = landmark.y.toDouble();

        final converted = rehab.PoseLandmark(
          name: entry.key.name,
          x: rawX,
          y: rawY,
          z: landmark.z.toDouble(),
          confidence: landmark.likelihood,
          rawX: rawX,
          rawY: rawY,
          isFiltered: false,
        );

        if (converted.isValid) {
          rawLandmarks[converted.name] = converted;
        }
      }

      _addCenterLandmarks(rawLandmarks, 'leftHip', 'rightHip', 'hip');
      _addCenterLandmarks(rawLandmarks, 'leftKnee', 'rightKnee', 'knee');
      _addCenterLandmarks(rawLandmarks, 'leftAnkle', 'rightAnkle', 'ankle');
      _addCenterLandmarks(rawLandmarks, 'leftShoulder', 'rightShoulder', 'shoulder');
      _addCenterLandmarks(rawLandmarks, 'leftElbow', 'rightElbow', 'elbow');
      _addCenterLandmarks(rawLandmarks, 'leftWrist', 'rightWrist', 'wrist');
      _addFootLandmark(rawLandmarks);

      if (rawLandmarks.isEmpty) return null;

      final rawFrame = rehab.PoseFrame(
        timestamp: now,
        landmarks: rawLandmarks,
        imageWidth: analyzedWidth,
        imageHeight: analyzedHeight,
        personCount: 1,
        isMultiPerson: false,
      );

      // Apply One Euro temporal filter to smooth jitter while preserving real movement
      final filteredFrame = _temporalFilter.filterFrame(rawFrame);
      return filteredFrame;
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  mlkit.InputImageRotation _computeRotation(CameraFrame frame) {
    final sensorOrientation = frame.sensorOrientation;
    if (!Platform.isAndroid) {
      return mlkit.InputImageRotationValue.fromRawValue(sensorOrientation) ??
          mlkit.InputImageRotation.rotation0deg;
    }

    int deviceDegrees = 0;
    switch (frame.deviceOrientation) {
      case DeviceOrientation.portraitUp:
        deviceDegrees = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        deviceDegrees = 90;
        break;
      case DeviceOrientation.portraitDown:
        deviceDegrees = 180;
        break;
      case DeviceOrientation.landscapeRight:
        deviceDegrees = 270;
        break;
    }

    int rotationCompensation;
    if (frame.isFrontFacing) {
      rotationCompensation = (sensorOrientation + deviceDegrees) % 360;
    } else {
      rotationCompensation = (sensorOrientation - deviceDegrees + 360) % 360;
    }

    return mlkit.InputImageRotationValue.fromRawValue(rotationCompensation) ??
        mlkit.InputImageRotation.rotation0deg;
  }

  mlkit.InputImage? _inputImage(CameraFrame frame) {
    final image = frame.image;
    if (image.planes.isEmpty) return null;

    final rotation = _computeRotation(frame);

    if (Platform.isAndroid) {
      final Uint8List bytes;
      if (image.planes.length == 3) {
        bytes = _convertYuv420ToNv21(image);
      } else {
        bytes = image.planes.first.bytes;
      }

      final metadata = mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: mlkit.InputImageFormat.nv21,
        bytesPerRow: image.width,
      );

      return mlkit.InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } else {
      final format = mlkit.InputImageFormatValue.fromRawValue(image.format.raw) ??
          mlkit.InputImageFormat.bgra8888;
      final bytes = WriteBuffer();
      for (final plane in image.planes) {
        bytes.putUint8List(plane.bytes);
      }
      final metadata = mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );
      return mlkit.InputImage.fromBytes(
        bytes: bytes.done().buffer.asUint8List(),
        metadata: metadata,
      );
    }
  }

  /// Converts Android CameraImage (typically YUV_420_888) into NV21 Uint8List.
  /// ML Kit Android natively requires NV21 byte buffer for byte-array inputs.
  static Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final totalBytes = width * height + 2 * (width ~/ 2) * (height ~/ 2);
    final nv21 = Uint8List(totalBytes);

    // 1. Copy Y Plane (Luminance)
    final yRowStride = yPlane.bytesPerRow;
    if (yRowStride == width) {
      nv21.setRange(0, width * height, yBuffer);
    } else {
      for (var row = 0; row < height; row++) {
        final srcOffset = row * yRowStride;
        final dstOffset = row * width;
        nv21.setRange(dstOffset, dstOffset + width, yBuffer, srcOffset);
      }
    }

    // 2. Copy and interleave UV Planes (NV21 expects V, then U)
    var uvIndex = width * height;
    final halfWidth = width ~/ 2;
    final halfHeight = height ~/ 2;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < halfHeight; row++) {
      for (var col = 0; col < halfWidth; col++) {
        final vOffset = row * vRowStride + col * vPixelStride;
        final uOffset = row * uRowStride + col * uPixelStride;

        if (vOffset < vBuffer.length && uOffset < uBuffer.length) {
          nv21[uvIndex++] = vBuffer[vOffset];
          nv21[uvIndex++] = uBuffer[uOffset];
        }
      }
    }

    return nv21;
  }

  void _addCenterLandmarks(
    Map<String, rehab.PoseLandmark> landmarks,
    String leftName,
    String rightName,
    String centerName,
  ) {
    final left = landmarks[leftName];
    final right = landmarks[rightName];
    if (left != null && right != null) {
      landmarks[centerName] = midpoint(left, right);
    } else if (left != null) {
      landmarks[centerName] = left;
    } else if (right != null) {
      landmarks[centerName] = right;
    }
  }

  void _addFootLandmark(Map<String, rehab.PoseLandmark> landmarks) {
    final left = landmarks['leftFootIndex'] ?? landmarks['leftHeel'];
    final right = landmarks['rightFootIndex'] ?? landmarks['rightHeel'];
    if (left != null && right != null) {
      landmarks['foot'] = midpoint(left, right);
    } else {
      final foot = left ?? right;
      if (foot != null) landmarks['foot'] = foot;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _initialized = false;
    _temporalFilter.reset();
    await _detector.close();
  }
}