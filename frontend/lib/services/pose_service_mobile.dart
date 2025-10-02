//pose_service_mobile.dart
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_service.dart';

class MobilePoseService implements PoseService {
  late final PoseDetector _detector;

  MobilePoseService() {
    // Using default options for widest compatibility across plugin versions.
    _detector = PoseDetector(options: PoseDetectorOptions());
  }

  @override
  Future<List<Map<String, double>>> detectFromImagePath(
    String imagePath,
  ) async {
    // Note: InputImage.fromFilePath handles EXIF rotation; no manual rotation needed.
    final inputImage = InputImage.fromFilePath(imagePath);
    final poses = await _detector.processImage(inputImage);
    // Log size for debugging large images.
    // ignore: avoid_print
    print('[MobilePoseService] poses=${poses.length}');
    final result = <Map<String, double>>[];
    for (final pose in poses) {
      for (final l in pose.landmarks.values) {
        result.add({'x': l.x, 'y': l.y, 'z': l.z ?? 0.0});
      }
    }
    return result;
  }

  @override
  Future<void> dispose() async {
    await _detector.close();
  }
}
