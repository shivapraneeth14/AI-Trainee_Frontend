// VideoUploadPage.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pose_service.dart';

class VideoUploadPage extends StatefulWidget {
  const VideoUploadPage({super.key});

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  VideoPlayerController? _controller;
  bool _loading = false;
  Map<String, dynamic>? _results;
  PoseService? _poseService;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    try {
      await _getUserId();
      debugPrint("[INIT] Fetched userId: $_userId");
      _poseService = PoseService.create();
      debugPrint("[INIT] PoseService initialized");
    } catch (e, st) {
      debugPrint("[INIT ERROR] $e\n$st");
    }
  }

  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    debugPrint("[USER ID] AccessToken: $token");

    if (token == null) {
      debugPrint("[USER ID] No token found");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("https://ai-trainee-5.onrender.com/api/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['user']['_id'];
        setState(() {
          _userId = userId;
        });
        debugPrint("[USER ID] Fetched userId: $userId");
      } else {
        debugPrint(
          "[USER ID] Failed - ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("[USER ID] Error: $e");
    }
  }

  bool _isPoseBridgeAvailable() => true;

  @override
  void dispose() {
    _controller?.dispose();
    _poseService?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      if (result == null) return;

      _controller?.dispose();

      if (kIsWeb) {
        Uint8List? bytes = result.files.single.bytes;
        if (bytes == null) return;
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        _controller = VideoPlayerController.network(url);
        await _controller!.initialize();
        _controller!.setLooping(true);
      } else {
        final path = result.files.single.path;
        if (path == null) return;
        _controller = VideoPlayerController.file(File(path));
        await _controller!.initialize();
        _controller!.setLooping(true);
      }

      setState(() {
        _results = null;
      });
      debugPrint("[PICK VIDEO] Video picked successfully");
    } catch (e, st) {
      debugPrint("[PICK VIDEO ERROR] $e\n$st");
    }
  }

  // Submit video for pose detection and send to backend
  Future<void> _submitVideo() async {
    if (_controller == null || _poseService == null) {
      debugPrint("[SUBMIT] Controller or PoseService is null, returning.");
      return;
    }

    if (_userId == null) {
      debugPrint("[SUBMIT] UserId is null, cannot submit.");
      return;
    }

    setState(() {
      _loading = true;
      _results = null;
    });

    try {
      debugPrint("[SUBMIT] Starting pose detection...");

      List<Map<String, dynamic>> allFrames = [];

      if (kIsWeb) {
        final videoUrl = _controller!.dataSource;
        allFrames = await (_poseService as dynamic).detectFromVideoUrl(
          videoUrl,
          intervalMs: 500,
        );
      } else {
        final videoPath = _controller!.dataSource.startsWith('file://')
            ? _controller!.dataSource.replaceFirst('file://', '')
            : _controller!.dataSource;
        final durationMs = _controller!.value.duration.inMilliseconds;
        final intervalMs = 500;

        for (var timeMs = 0; timeMs < durationMs; timeMs += intervalMs) {
          final thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: videoPath,
            imageFormat: ImageFormat.JPEG,
            timeMs: timeMs,
            quality: 75,
          );
          if (thumbnailPath == null) continue;

          final landmarks = await _poseService!.detectFromImagePath(
            thumbnailPath,
          );

          allFrames.add({
            't': timeMs,
            'landmarks': landmarks
                .map((l) => {'x': l['x'], 'y': l['y'], 'z': l['z']})
                .toList(),
          });
        }
      }

      debugPrint(
        "[SUBMIT] Pose detection complete. Total frames: ${allFrames.length}",
      );

      // Send to backend
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      debugPrint("[UPLOAD] Access token: $token");

      if (token == null) {
        debugPrint("[UPLOAD] Cannot send POST request. Token is null.");
        return;
      }

      debugPrint("[UPLOAD] Sending keypoints to backend...");

      final response = await http.post(
        Uri.parse("https://ai-trainee-5.onrender.com/api/upload"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"keypoints": allFrames, "userId": _userId}),
      );

      debugPrint("[UPLOAD] Status: ${response.statusCode}");
      debugPrint("[UPLOAD] Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _results = {
            "frames": allFrames,
            "totalFrames": allFrames.length,
            "analysis": data['result'], // backend AI Fitness Coach result
          };
        });
        debugPrint("[UPLOAD] Analysis saved to _results");
      } else {
        debugPrint("[UPLOAD] Failed to upload keypoints");
      }
    } catch (e, st) {
      debugPrint("[SUBMIT ERROR] $e\n$st");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _downloadJson() {
    if (_results == null) return;
    final jsonStr = jsonEncode(_results);
    final blob = html.Blob([jsonStr], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = 'pose_results.json'
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "Upload / Record Your Performance",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (_userId != null) Text("User ID: $_userId"),
              ElevatedButton(
                onPressed: _pickVideo,
                child: const Text("Choose Video"),
              ),
              const SizedBox(height: 20),
              if (_controller != null)
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              const SizedBox(height: 20),
              if (_controller != null)
                ElevatedButton(
                  onPressed: _loading ? null : _submitVideo,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Submit for Analysis"),
                ),
              const SizedBox(height: 20),
              if (_results != null) ...[
                Text("Total Frames: ${_results!['totalFrames']}"),
                const SizedBox(height: 10),
                if (_results!['analysis'] != null) ...[
                  Text("Exercise: ${_results!['analysis']['exercise']}"),
                  Text("Confidence: ${_results!['analysis']['confidence']}%"),
                  Text("Reps: ${_results!['analysis']['reps']}"),
                  Text("Sets: ${_results!['analysis']['sets']}"),
                  Text(
                    "Posture: ${_results!['analysis']['posture']?['status'] ?? 'Unknown'}",
                  ),
                  Text(
                    "Correction: ${_results!['analysis']['correction'] ?? ''}",
                  ),
                  Text(
                    "Motivation: ${_results!['analysis']['motivation'] ?? ''}",
                  ),
                  Text(
                    "Suggestion: ${_results!['analysis']['suggestion'] ?? ''}",
                  ),
                  Text("Badge: ${_results!['analysis']['badge'] ?? ''}"),
                  Text(
                    "Cheat Detected: ${_results!['analysis']['cheatDetected'] ?? false}",
                  ),
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _downloadJson,
                  child: const Text("Download JSON"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
