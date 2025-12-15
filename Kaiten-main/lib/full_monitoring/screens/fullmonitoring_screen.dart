import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kaitenapp/full_monitoring/services/detecting_edges_service.dart';
import '../Helpers/pose _contour_overlay.dart';
import '../Helpers/posemonitor.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isRecording = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  List<Pose> _poses = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  List<Offset> _contour = [];
  List<Offset> _corners = [];
  final ContourService _contourService =
  ContourService(baseUrl: "https://4e45a8ac949f.ngrok-free.app");

  late PostureMonitor _postureMonitor;

  int? _sensorOrientation;
  double _displayWidth = 0;
  double _displayHeight = 0;
  double _offsetX = 0;
  double _offsetY = 0;
  double _actualCameraWidth = 0;
  double _actualCameraHeight = 0;
  double _yAdjustment = 0;
  double _cameraImageWidth = 0;
  double _cameraImageHeight = 0;

  int _frameCount = 0;
  static const int _skipFrames = 1;
  DateTime? _lastProcessTime;
  static const int _minProcessIntervalMs = 50;

  bool _isWarmedUp = false;
  bool _isStreamActive = false; // ✅ تتبع حالة الـ stream

  String _currentWarning = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );

    _postureMonitor = PostureMonitor(
      onAlarmTriggered: () {
        _triggerAlarm();
      },
    );

    _warmUpPoseDetector();
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      debugPrint("✅ Audio Player configured successfully");
    } catch (e) {
      debugPrint("❌ Audio Player setup error: $e");
    }
  }

  Future<void> _warmUpPoseDetector() async {
    try {
      final dummyImage = InputImage.fromBytes(
        bytes: Uint8List(100),
        inputImageData: InputImageData(
          size: const Size(10, 10),
          imageRotation: InputImageRotation.rotation0deg,
          inputImageFormat: InputImageFormat.nv21,
          planeData: [],
        ),
      );

      await _poseDetector.processImage(dummyImage);
      _isWarmedUp = true;
      debugPrint("✅ Pose detector warmed up");
    } catch (e) {
      debugPrint("⚠️ Warm-up failed (non-critical): $e");
      _isWarmedUp = true;
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      _sensorOrientation = backCamera.sensorOrientation;

      _startImageStream();

      setState(() {
        _isInitializing = false;
      });

      debugPrint("📷 Camera initialized");
      debugPrint("📐 Preview size: ${_cameraController!.value.previewSize!.width} x ${_cameraController!.value.previewSize!.height}");
      debugPrint("🔄 Sensor orientation: $_sensorOrientation");
    } catch (e) {
      debugPrint("❌ Camera initialization error: $e");
    }
  }

  void _startImageStream() {
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_isStreamActive) { // ✅ تحقق من حالة الـ stream

      _isStreamActive = true;
      debugPrint("▶️ Starting image stream for pose detection");

      _cameraController!.startImageStream((CameraImage image) async {
        if (!_isWarmedUp) {
          return;
        }

        _frameCount++;
        if (_frameCount % (_skipFrames + 1) != 0) {
          return;
        }

        final now = DateTime.now();
        if (_lastProcessTime != null) {
          final diff = now.difference(_lastProcessTime!).inMilliseconds;
          if (diff < _minProcessIntervalMs) {
            return;
          }
        }

        if (_isBusy) return;
        _isBusy = true;
        _lastProcessTime = now;

        if (_cameraImageWidth == 0) {
          _cameraImageWidth = image.width.toDouble();
          _cameraImageHeight = image.height.toDouble();
          debugPrint("📸 Camera Image Size: $_cameraImageWidth x $_cameraImageHeight");
        }

        try {
          final inputImage = _convertCameraImageToInputImage(image);
          final poses = await _poseDetector.processImage(inputImage);

          if (mounted) {
            setState(() {
              _poses = poses;
            });
          }

          _checkPostures(poses);
        } catch (e) {
          debugPrint("⚠️ Pose detection error: $e");
        } finally {
          _isBusy = false;
        }
      });
    }
  }

  // ✅ دالة لإيقاف الـ stream بشكل آمن
  Future<void> _stopImageStream() async {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages &&
        _isStreamActive) {

      debugPrint("⏸️ Stopping image stream");
      await _cameraController!.stopImageStream();
      _isStreamActive = false;

      // انتظار صغير للتأكد من إيقاف الـ stream
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  InputImage _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;
    final planeData = image.planes.map(
          (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();
    final inputImageData = InputImageData(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    return InputImage.fromBytes(
      bytes: bytes,
      inputImageData: inputImageData,
    );
  }

  void _checkPostures(List<Pose> poses) {
    if (poses.isEmpty) {
      _stopAlarm();
      _postureMonitor.clearWarning();
      return;
    }

    for (final pose in poses) {
      _postureMonitor.checkWSitting(pose);
      _postureMonitor.checkHeadDown(pose);
      _postureMonitor.checkBackBending(pose);
    }

    if (_contour.isNotEmpty) {
      _postureMonitor.checkKeypointsNearContour(_contour, poses);
    }
  }

  Future<void> _triggerAlarm() async {
    if (!_isAlarmPlaying) {
      _isAlarmPlaying = true;
      debugPrint("🔊 Attempting to play alarm...");
      try {
        await _audioPlayer.stop();

        await _audioPlayer.play(
          AssetSource('scotland-eas-alarm-2024-loud-333886.mp3'),
          volume: 1.0,
        );

      } catch (e) {
        _isAlarmPlaying = false;
      }
    }
  }

  Future<void> _stopAlarm() async {
    if (_isAlarmPlaying) {
      try {
        await _audioPlayer.stop();
        _isAlarmPlaying = false;
        debugPrint("🔇 Alarm stopped");
      } catch (e) {
        debugPrint("❌ Error stopping alarm: $e");
      }
    }
  }

  Future<void> _startRecordingAndSend() async {
    if (_isRecording) return;

    setState(() => _isRecording = true);
    debugPrint("📹 Starting recording...");

    try {
      _isBusy = true;

      await _stopImageStream();

      await _cameraController!.startVideoRecording();
      await Future.delayed(const Duration(seconds: 3));
      final file = await _cameraController!.stopVideoRecording();
      final videoFile = File(file.path);

      debugPrint("🎥 Video recorded: ${videoFile.lengthSync()} bytes");

      if (_actualCameraWidth == 0 || _actualCameraHeight == 0) {
        final previewSize = _cameraController!.value.previewSize!;
        final isPortrait = _sensorOrientation == 90 || _sensorOrientation == 270;

        final cameraAspectRatio = isPortrait
            ? previewSize.height / previewSize.width
            : previewSize.width / previewSize.height;

        final screenAspectRatio = _displayWidth / _displayHeight;

        if (screenAspectRatio > cameraAspectRatio) {
          _actualCameraWidth = _displayHeight * cameraAspectRatio;
          _actualCameraHeight = _displayHeight;
          _offsetX = (_displayWidth - _actualCameraWidth) / 2;
          _offsetY = 0;
        } else {
          _actualCameraWidth = _displayWidth;
          _actualCameraHeight = _displayWidth / cameraAspectRatio;
          _offsetX = 0;
          _offsetY = (_displayHeight - _actualCameraHeight) / 2;
        }
      }

      final yAdjustment = (_displayHeight - _actualCameraHeight) / 2;

      debugPrint("=== RECORDING INFO ===");
      debugPrint("📱 Display size: $_displayWidth x $_displayHeight");
      debugPrint("📷 Actual camera size: $_actualCameraWidth x $_actualCameraHeight");
      debugPrint("📍 Offset: ($_offsetX, $_offsetY)");
      debugPrint("📐 Y Adjustment: $yAdjustment");

      final response = await _contourService.sendVideoWithOrientation(
        videoFile,
        (_sensorOrientation ?? 0),
        previewWidth: _actualCameraWidth,
        previewHeight: _actualCameraHeight,
      );

      if (response != null) {
        debugPrint("✅ API Response received");

        setState(() {
          final rawContour = _contourService.parseContour(
            response['contour'],
            _actualCameraWidth,
            _actualCameraHeight,
          );

          final rawCorners = _contourService.parseCorners(
            response['corners'],
            _actualCameraWidth,
            _actualCameraHeight,
          );

          _contour = rawContour.map((point) {
            return Offset(point.dx, point.dy - yAdjustment);
          }).toList();

          _corners = [];

          debugPrint("📍 Contour length: ${_contour.length}");
          if (_contour.isNotEmpty) {
            debugPrint("First contour point (adjusted): ${_contour.first}");
            debugPrint("Last contour point (adjusted): ${_contour.last}");
          }
          if (_corners.isNotEmpty) {
            debugPrint("🔲 Corners count: ${_corners.length}");
            debugPrint("First corner (adjusted): ${_corners.first}");
          }
        });
      } else {
        debugPrint("⚠️ No response from API");
      }
    } catch (e) {
      debugPrint("❌ Recording or upload failed: $e");
    } finally {
      _isBusy = false;
      setState(() => _isRecording = false);

      // ✅ إعادة تشغيل الـ image stream بعد انتهاء التسجيل
      _startImageStream();

      debugPrint("✅ Recording completed, stream restarted");
    }
  }

  @override
  void dispose() {
    _stopImageStream();
    _cameraController?.dispose();
    _poseDetector.close();
    _audioPlayer.dispose();
    _postureMonitor.dispose();
    debugPrint("🔚 CameraScreen disposed");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Posture Monitoring'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Camera Preview
                LayoutBuilder(
                  builder: (context, constraints) {
                    _displayWidth = constraints.maxWidth;
                    _displayHeight = constraints.maxHeight;

                    if (_cameraController != null &&
                        _cameraController!.value.isInitialized) {
                      final previewSize = _cameraController!.value.previewSize!;
                      final isPortrait =
                          _sensorOrientation == 90 || _sensorOrientation == 270;

                      final cameraAspectRatio = isPortrait
                          ? previewSize.height / previewSize.width
                          : previewSize.width / previewSize.height;

                      final screenAspectRatio = _displayWidth / _displayHeight;

                      if (screenAspectRatio > cameraAspectRatio) {
                        _actualCameraWidth = _displayHeight * cameraAspectRatio;
                        _actualCameraHeight = _displayHeight;
                        _offsetX = (_displayWidth - _actualCameraWidth) / 2;
                        _offsetY = 0;
                      } else {
                        _actualCameraWidth = _displayWidth;
                        _actualCameraHeight = _displayWidth / cameraAspectRatio;
                        _offsetX = 0;
                        _offsetY = (_displayHeight - _actualCameraHeight) / 2;
                      }

                      _yAdjustment = (_displayHeight - _actualCameraHeight) / 2;
                    }

                    return CameraPreview(_cameraController!);
                  },
                ),

                // Pose & Contour Overlay
                Positioned(
                  left: _offsetX,
                  top: _offsetY,
                  width: _actualCameraWidth,
                  height: _actualCameraHeight,
                  child: PoseContourOverlay(
                    poses: _poses,
                    contour: _contour,
                    corners: _corners,
                    cameraController: _cameraController!,
                    sensorOrientation: _sensorOrientation,
                    displayWidth: _actualCameraWidth,
                    displayHeight: _actualCameraHeight,
                    yAdjustment: _yAdjustment,
                    cameraImageWidth: _cameraImageWidth,
                    cameraImageHeight: _cameraImageHeight,
                  ),
                ),

                // Warning Banner
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _postureMonitor.warningText,
                    builder: (context, warning, child) {
                      if (warning.isEmpty) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                warning,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Info Box
                Positioned(
                  bottom: 50,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '👤 Poses: ${_poses.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 Contours: ${_contour.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '🔊 Alarm: ${_isAlarmPlaying ? "Playing" : "Silent"}',
                          style: TextStyle(
                            color: _isAlarmPlaying ? Colors.red : Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📹 Stream: ${_isStreamActive ? "Active" : "Stopped"}',
                          style: TextStyle(
                            color: _isStreamActive ? Colors.green : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startRecordingAndSend,
        icon: Icon(_isRecording ? Icons.stop : Icons.camera_alt),
        label: Text(_isRecording ? 'Processing...' : 'Detect Area'),
        backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
      ),
    );
  }
}