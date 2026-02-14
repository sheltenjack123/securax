import 'dart:io';

import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import 'backend_config.dart';
import 'local_evidence_store.dart';

class EvidenceService {
  static final EvidenceService _instance = EvidenceService._internal();
  factory EvidenceService() => _instance;
  EvidenceService._internal();

  CameraController? _controller;
  bool _isInitializing = false;
  Future<void> _captureQueue = Future.value();

  Future<void> initCamera() async {
    if (_controller != null || _isInitializing) return;
    _isInitializing = true;
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
    } finally {
      _isInitializing = false;
    }
  }

  /// Captures a photo and uploads it to the local Flask backend.
  ///
  /// Note: This should only be called when the user has explicitly enabled
  /// evidence capture in-app, since it uses the camera.
  Future<void> captureAndUpload({
    required String reason,
    String location = "Unknown Location",
    String device = "Unknown Device",
  }) async {
    final task = _captureQueue.then((_) {
      return _captureAndUploadInternal(
        reason: reason,
        location: location,
        device: device,
      );
    });
    _captureQueue = task.catchError((_) {});
    return task;
  }

  Future<void> _captureAndUploadInternal({
    required String reason,
    required String location,
    required String device,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      await initCamera();
    }
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile photo = await _controller!.takePicture();
      final file = File(photo.path);

      // Always persist locally first so the app works fully offline.
      //
      // This also covers the common "backend on PC over USB/Wi-Fi" setup: if the server
      // is unreachable, the evidence is still saved on-device.
      await LocalEvidenceStore().saveFromFile(file, reason: reason);

      // Best-effort upload to remote backend (LAN/cloud). Keep timeout short so it
      // does not block the lock screen UX when offline.
      try {
        final uri = Uri.parse("${BackendConfig.baseUrl}/upload_evidence");
        final request = http.MultipartRequest("POST", uri)
          ..fields["location"] = location
          ..fields["device"] = device
          ..fields["reason"] = reason
          ..files.add(await http.MultipartFile.fromPath("photo", file.path));

        final resp = await request.send().timeout(const Duration(seconds: 3));
        // Drain the response to avoid leaked connections.
        await resp.stream.drain();
      } catch (_) {
        // Ignore: offline or server not reachable. Evidence is already saved locally.
      }
    } catch (_) {
      // Swallow errors: capture should never crash the lock screen UX.
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
