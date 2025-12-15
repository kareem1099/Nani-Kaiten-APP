import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:kaitenapp/full_monitoring/Helpers/Painters.dart';

class PoseContourOverlay extends StatelessWidget {
  final List<Pose> poses;
  final List<Offset> contour;
  final List<Offset> corners;
  final CameraController cameraController;
  final int? sensorOrientation;
  final double displayWidth;
  final double displayHeight;
  final double yAdjustment;
  final double cameraImageWidth;
  final double cameraImageHeight;

  const PoseContourOverlay({
    required this.poses,
    required this.contour,
    required this.corners,
    required this.cameraController,
    required this.sensorOrientation,
    required this.displayWidth,
    required this.displayHeight,
    required this.yAdjustment,
    required this.cameraImageWidth,
    required this.cameraImageHeight,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = Size(displayWidth, displayHeight);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: ContourPainter(
              contour: contour,
              corners: corners,
              previewSize: previewSize,
              sensorOrientation: sensorOrientation,
            ),
          ),
        ),
        ..._buildPoses(previewSize),
      ],
    );
  }

  List<Widget> _buildPoses(Size previewSize) {
    if (poses.isEmpty || cameraImageWidth == 0) return [];
    final List<Widget> widgets = [];

    // تحديد إذا كانت الكاميرا portrait (rotated 90° or 270°)
    final isPortrait = sensorOrientation == 90 || sensorOrientation == 270;

    // ML Kit بيرجع coordinates في camera image space
    // لو الكاميرا portrait، الأبعاد بتبقى مقلوبة
    final imageWidth = isPortrait ? cameraImageHeight : cameraImageWidth;
    final imageHeight = isPortrait ? cameraImageWidth : cameraImageHeight;

    // Calculate scale factors
    final scaleX = previewSize.width / imageWidth;
    final scaleY = previewSize.height / imageHeight;

    debugPrint("Pose Scale - X: $scaleX, Y: $scaleY (ML Kit Image: $imageWidth x $imageHeight -> Display: ${previewSize.width} x ${previewSize.height})");

    for (final pose in poses) {
      for (final landmark in pose.landmarks.values) {
        // Scale from camera image space to display space
        final scaledX = landmark.x * scaleX;
        final scaledY = landmark.y * scaleY;

        // طرح yAdjustment عشان الـ letterbox
        final x = scaledX;
        final y = scaledY - yAdjustment;
        widgets.add(
          Positioned(
            left: x - 6,
            top: y - 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getLandmarkColor(landmark.type),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        );
      }
      _drawConnections(pose, widgets, scaleX, scaleY);
    }
    return widgets;
  }

  void _drawConnections(Pose pose, List<Widget> widgets, double scaleX, double scaleY) {
    final connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];
    for (final connection in connections) {
      final startLandmark = pose.landmarks[connection[0]];
      final endLandmark = pose.landmarks[connection[1]];
      if (startLandmark != null && endLandmark != null) {
        // Scale from camera image space to display space and adjust Y
        final startX = startLandmark.x * scaleX;
        final startY = (startLandmark.y * scaleY) - yAdjustment;
        final endX = endLandmark.x * scaleX;
        final endY = (endLandmark.y * scaleY) - yAdjustment;

        widgets.add(
          Positioned(
            left: 0,
            top: 0,
            child: CustomPaint(
              painter: LinePainter(
                start: Offset(startX, startY),
                end: Offset(endX, endY),
                color: Colors.blue,
                strokeWidth: 4.0,
              ),
              size: Size.infinite,
            ),
          ),
        );
      }
    }
  }

  Color _getLandmarkColor(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose:
        return Colors.red;
      case PoseLandmarkType.leftEye:
        return Colors.blue;
      case PoseLandmarkType.rightEye:
        return Colors.blue;
      case PoseLandmarkType.leftShoulder:
        return Colors.green;
      case PoseLandmarkType.rightShoulder:
        return Colors.green;
      case PoseLandmarkType.leftElbow:
        return Colors.orange;
      case PoseLandmarkType.rightElbow:
        return Colors.orange;
      case PoseLandmarkType.leftWrist:
        return Colors.yellow;
      case PoseLandmarkType.rightWrist:
        return Colors.yellow;
      case PoseLandmarkType.leftHip:
        return Colors.purple;
      case PoseLandmarkType.rightHip:
        return Colors.purple;
      case PoseLandmarkType.leftKnee:
        return Colors.cyan;
      case PoseLandmarkType.rightKnee:
        return Colors.cyan;
      case PoseLandmarkType.leftAnkle:
        return Colors.pink;
      case PoseLandmarkType.rightAnkle:
        return Colors.pink;
      default:
        return Colors.white;
    }
  }
}
