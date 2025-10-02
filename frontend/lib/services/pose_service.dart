//pose_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

import 'pose_service_mobile.dart' show MobilePoseService;
import 'pose_service_web.dart' show WebPoseService;

abstract class PoseService {
  Future<List<Map<String, double>>> detectFromImagePath(String imagePath);
  Future<void> dispose();

  static PoseService create() {
    if (kIsWeb) {
      return WebPoseService();
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return MobilePoseService();
    }
    return _UnsupportedPoseService();
  }
}

class _UnsupportedPoseService implements PoseService {
  @override
  Future<void> dispose() async {}

  @override
  Future<List<Map<String, double>>> detectFromImagePath(
    String imagePath,
  ) async {
    throw UnsupportedError('Pose detection not supported on this platform.');
  }
}

// Implementations are provided in platform-specific files.
