import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';

class ContourService {
  final String baseUrl;
  static const double API_SIZE = 512.0;

  ContourService({required this.baseUrl});

  Future<Map<String, dynamic>?> sendVideoWithOrientation(
      File videoFile, int rotationDegrees,
      {double? previewWidth, double? previewHeight}) async {
    if (!await videoFile.exists()) {
      debugPrint("Video file doesn't exist.");
      return null;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/process-video'),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        videoFile.path,
        contentType: MediaType('video', 'mp4'),
      ),
    );

    request.fields['rotation'] = rotationDegrees.toString();
    if (previewWidth != null && previewHeight != null) {
      request.fields['preview_width'] = previewWidth.toString();
      request.fields['preview_height'] = previewHeight.toString();
      debugPrint("Sending preview size: $previewWidth x $previewHeight");
    }

    try {
      var response = await request.send();
      var responseString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(responseString);
        debugPrint(" Video processed successfully");
        debugPrint("Response: $data");
        return data;
      } else {
        debugPrint(' Server error: ${response.statusCode}');
        debugPrint('Response body: $responseString');
        return null;
      }
    } catch (e) {
      debugPrint(' Error sending video: $e');
      return null;
    }
  }

  List<Offset> parseContour(
      dynamic contoursJson,
      double displayWidth,
      double displayHeight,
      {List<dynamic>? frameSize, List<dynamic>? maskSize}
      ) {
    if (contoursJson is! List || contoursJson.isEmpty) {
      debugPrint("Contour is empty or invalid");
      return [];
    }

    debugPrint("=== PARSING CONTOUR ===");

    double maskW = maskSize != null && maskSize.length >= 2
        ? (maskSize[0] as num).toDouble()
        : API_SIZE;
    double maskH = maskSize != null && maskSize.length >= 2
        ? (maskSize[1] as num).toDouble()
        : API_SIZE;

    double frameW = frameSize != null && frameSize.length >= 2
        ? (frameSize[0] as num).toDouble()
        : maskW;
    double frameH = frameSize != null && frameSize.length >= 2
        ? (frameSize[1] as num).toDouble()
        : maskH;

    debugPrint("Mask size: ${maskW}x$maskH");
    debugPrint("Frame size: ${frameW}x$frameH");
    debugPrint("Display size: ${displayWidth}x$displayHeight");

    final maskToFrameScaleX = frameW / maskW;
    final maskToFrameScaleY = frameH / maskH;

    final frameToDisplayScaleX = displayWidth / frameW;
    final frameToDisplayScaleY = displayHeight / frameH;

    final totalScaleX = maskToFrameScaleX * frameToDisplayScaleX;
    final totalScaleY = maskToFrameScaleY * frameToDisplayScaleY;

    debugPrint("Mask→Frame: X=$maskToFrameScaleX, Y=$maskToFrameScaleY");
    debugPrint("Frame→Display: X=$frameToDisplayScaleX, Y=$frameToDisplayScaleY");
    debugPrint("Total scale: X=$totalScaleX, Y=$totalScaleY");
    debugPrint("Raw points: ${contoursJson.length}");

    final points = contoursJson.map<Offset>((point) {
      final maskX = (point[0] as num).toDouble();
      final maskY = (point[1] as num).toDouble();

      final scaledX = maskX * totalScaleX;
      final scaledY = maskY * totalScaleY;

      return Offset(scaledX, scaledY);
    }).toList();

    if (points.isNotEmpty) {
      final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

      debugPrint("Result range X: ${minX.toStringAsFixed(1)} to ${maxX.toStringAsFixed(1)} (display: 0-$displayWidth)");
      debugPrint("Result range Y: ${minY.toStringAsFixed(1)} to ${maxY.toStringAsFixed(1)} (display: 0-$displayHeight)");

      if (minX < -10 || maxX > displayWidth + 10 || minY < -10 || maxY > displayHeight + 10) {
        debugPrint(" WARNING: Points outside display bounds!");
      } else {
        debugPrint("Points within bounds");
      }
    }

    return points;
  }

  List<Offset> parseCorners(
      dynamic cornersJson,
      double displayWidth,
      double displayHeight,
      {List<dynamic>? frameSize, List<dynamic>? maskSize}
      ) {
    if (cornersJson is! List || cornersJson.isEmpty) {
      debugPrint(" Corners is empty or invalid");
      return [];
    }

    debugPrint("=== PARSING CORNERS ===");

    double maskW = maskSize != null && maskSize.length >= 2
        ? (maskSize[0] as num).toDouble()
        : API_SIZE;
    double maskH = maskSize != null && maskSize.length >= 2
        ? (maskSize[1] as num).toDouble()
        : API_SIZE;

    double frameW = frameSize != null && frameSize.length >= 2
        ? (frameSize[0] as num).toDouble()
        : maskW;
    double frameH = frameSize != null && frameSize.length >= 2
        ? (frameSize[1] as num).toDouble()
        : maskH;

    final maskToFrameScaleX = frameW / maskW;
    final maskToFrameScaleY = frameH / maskH;
    final frameToDisplayScaleX = displayWidth / frameW;
    final frameToDisplayScaleY = displayHeight / frameH;
    final totalScaleX = maskToFrameScaleX * frameToDisplayScaleX;
    final totalScaleY = maskToFrameScaleY * frameToDisplayScaleY;

    debugPrint("Total scale: X=$totalScaleX, Y=$totalScaleY");

    final corners = cornersJson.map<Offset>((point) {
      final maskX = (point[0] as num).toDouble();
      final maskY = (point[1] as num).toDouble();

      final scaledX = maskX * totalScaleX;
      final scaledY = maskY * totalScaleY;

      debugPrint("Corner: Mask($maskX, $maskY) → Display(${scaledX.toStringAsFixed(1)}, ${scaledY.toStringAsFixed(1)})");
      return Offset(scaledX, scaledY);
    }).toList();

    return corners;
  }
}