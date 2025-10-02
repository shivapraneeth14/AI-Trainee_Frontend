//pose_service_web.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_util' as js_util;
import 'package:js/js.dart';
import 'pose_service.dart';

class WebPoseService implements PoseService {
  @override
  Future<void> dispose() async {}

  @override
  Future<List<Map<String, double>>> detectFromImagePath(
    String imagePath,
  ) async {
    // On web, imagePath may be an Object URL or data URL. We expect a file path
    // from our thumbnail logic on non-web only. For web, we will expose a
    // helper that accepts bytes and converts to a data URL before calling JS.
    throw UnimplementedError('Use detectFromImageBytes on web');
  }

  Future<List<Map<String, double>>> detectFromImageBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    // ignore: avoid_print
    print('[WebPoseService] detectFromImageBytes len=${bytes.length}');
    final promise = js_util.callMethod(
      js_util.getProperty(js_util.globalThis, 'PoseBridge') as Object,
      'detectFromDataUrl',
      [dataUrl],
    );
    final dynamic result = await js_util.promiseToFuture(promise);
    // result is expected to be a JS array of {x,y,z}
    final List<dynamic> list = result as List<dynamic>;
    return list
        .map(
          (e) => {
            'x': (e['x'] as num).toDouble(),
            'y': (e['y'] as num).toDouble(),
            'z': (e['z'] as num?)?.toDouble() ?? 0.0,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> detectFromVideoBytes(
    Uint8List bytes, {
    String mimeType = 'video/mp4',
    int intervalMs = 500,
  }) async {
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    // ignore: avoid_print
    print(
      '[WebPoseService] detectFromVideoBytes len=${bytes.length} intervalMs=$intervalMs',
    );
    final bridge =
        js_util.getProperty(js_util.globalThis, 'PoseBridge') as Object;
    final promise = js_util.callMethod(bridge, 'detectFromVideoDataUrl', [
      dataUrl,
      intervalMs,
    ]);
    final dynamic frames = await js_util.promiseToFuture(promise);
    final List<dynamic> framesList = frames as List<dynamic>;
    // ignore: avoid_print
    print('[WebPoseService] frames received=${framesList.length}');
    final List<Map<String, dynamic>> out = [];
    for (final fObj in framesList) {
      final numT = js_util.getProperty(fObj, 't') as num;
      final int t = numT.toInt();
      final List<dynamic> lmsList =
          js_util.getProperty(fObj, 'landmarks') as List<dynamic>;
      final lms = lmsList
          .map(
            (e) => {
              'x': (js_util.getProperty(e, 'x') as num).toDouble(),
              'y': (js_util.getProperty(e, 'y') as num).toDouble(),
              'z': (js_util.getProperty(e, 'z') as num?)?.toDouble() ?? 0.0,
            },
          )
          .toList();
      out.add({'t': t, 'landmarks': lms});
    }
    return out;
  }

  // Method to handle video URLs directly (for blob URLs from video controllers)
  Future<List<Map<String, dynamic>>> detectFromVideoUrl(
    String videoUrl, {
    int intervalMs = 500,
  }) async {
    // ignore: avoid_print
    print(
      '[WebPoseService] detectFromVideoUrl url=$videoUrl intervalMs=$intervalMs',
    );
    final bridge =
        js_util.getProperty(js_util.globalThis, 'PoseBridge') as Object;
    final promise = js_util.callMethod(bridge, 'detectFromVideoDataUrl', [
      videoUrl,
      intervalMs,
    ]);
    final dynamic frames = await js_util.promiseToFuture(promise);
    final List<dynamic> framesList = frames as List<dynamic>;
    // ignore: avoid_print
    print('[WebPoseService] frames received=${framesList.length}');
    final List<Map<String, dynamic>> out = [];
    for (final fObj in framesList) {
      final numT = js_util.getProperty(fObj, 't') as num;
      final int t = numT.toInt();
      final List<dynamic> lmsList =
          js_util.getProperty(fObj, 'landmarks') as List<dynamic>;
      final lms = lmsList
          .map(
            (e) => {
              'x': (js_util.getProperty(e, 'x') as num).toDouble(),
              'y': (js_util.getProperty(e, 'y') as num).toDouble(),
              'z': (js_util.getProperty(e, 'z') as num?)?.toDouble() ?? 0.0,
            },
          )
          .toList();
      out.add({'t': t, 'landmarks': lms});
    }
    return out;
  }
}
