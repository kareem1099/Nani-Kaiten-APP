import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PostureMonitor {
  final Function()? onAlarmTriggered;
  final ValueNotifier<String> warningText = ValueNotifier<String>('');

  DateTime? _wSitStartTime;
  bool _isWSitting = false;
  bool _wAlarmTriggered = false;

  DateTime? _headDownStartTime;
  bool _isHeadDown = false;
  bool _headDownAlarmTriggered = false;

  DateTime? _headDownSevereStartTime;
  bool _isHeadDownSevere = false;
  bool _headDownSevereAlarmTriggered = false;

  DateTime? _backBentStartTime;
  bool _isBackBent = false;
  bool _backAlarmTriggered = false;

  PostureMonitor({this.onAlarmTriggered});

  Future<void> playAlarm() async {
    if (onAlarmTriggered != null) {
      onAlarmTriggered!();
      debugPrint(" Alarm callback triggered");
    } else {
      debugPrint(" No alarm callback provided");
    }
  }

  void showWarning(String text) {
    warningText.value = text;
    debugPrint(" Warning: $text");
  }

  void clearWarning() {
    warningText.value = '';
  }

  double angleBetween(Offset a, Offset b, Offset c) {
    // b is the vertex point
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);

    final dotProduct = (ab.dx * cb.dx + ab.dy * cb.dy);
    final abLength = sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final cbLength = sqrt(cb.dx * cb.dx + cb.dy * cb.dy);

    if (abLength == 0 || cbLength == 0) return 180.0;

    final cosineAngle = (dotProduct / (abLength * cbLength)).clamp(-1.0, 1.0);
    final angleRad = acos(cosineAngle);
    return angleRad * (180 / pi);
  }

  double minDistance(PoseLandmark? p1, PoseLandmark? p2) {
    if (p1 == null || p2 == null) return double.infinity;
    final dx = (p1.x - p2.x).abs();
    final dy = (p1.y - p2.y).abs();
    return sqrt(dx * dx + dy * dy);
  }

  bool isSitting(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if ([leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle]
        .any((p) => p == null)) {
      return false;
    }

    final leftKneeAngle = angleBetween(
      Offset(leftHip!.x, leftHip.y),
      Offset(leftKnee!.x, leftKnee.y),
      Offset(leftAnkle!.x, leftAnkle.y),
    );

    final rightKneeAngle = angleBetween(
      Offset(rightHip!.x, rightHip.y),
      Offset(rightKnee!.x, rightKnee.y),
      Offset(rightAnkle!.x, rightAnkle.y),
    );

    final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;
    debugPrint(" Knee angles - L: ${leftKneeAngle.toStringAsFixed(1)}, R: ${rightKneeAngle.toStringAsFixed(1)}, Avg: ${avgKneeAngle.toStringAsFixed(1)}°");


    final sitting = avgKneeAngle < 140;
    debugPrint("   Position: ${sitting ? ' SITTING' : ' STANDING'}");

    return sitting;
  }

  bool isWSitting(Pose pose) {
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if ([leftKnee, rightKnee, leftAnkle, rightAnkle, leftHip, rightHip]
        .any((p) => p == null)) {
      debugPrint(" W-Sitting: Missing landmarks");
      return false;
    }

    int score = 0;

    final leftAngle = angleBetween(
        Offset(leftHip!.x, leftHip.y),
        Offset(leftKnee!.x, leftKnee.y),
        Offset(leftAnkle!.x, leftAnkle.y));
    final rightAngle = angleBetween(
        Offset(rightHip!.x, rightHip.y),
        Offset(rightKnee!.x, rightKnee.y),
        Offset(rightAnkle!.x, rightAnkle.y));

    if (leftAngle <= 100 && rightAngle <= 100) {
      score++;
      debugPrint(" Condition 1: Knee angles (L:${leftAngle.toStringAsFixed(1)}°, R:${rightAngle.toStringAsFixed(1)}°) <= 100°");
    } else {
      debugPrint(" Condition 1: Knee angles (L:${leftAngle.toStringAsFixed(1)}°, R:${rightAngle.toStringAsFixed(1)}°) > 100°");
    }

    final ankleDistance = minDistance(leftAnkle, rightAnkle);
    final kneeDistance = minDistance(leftKnee, rightKnee);
    final hipDistance = minDistance(leftHip, rightHip);
    final leftLegDist = minDistance(leftAnkle, leftHip);
    final rightLegDist = minDistance(rightAnkle, rightHip);

    if (ankleDistance > kneeDistance) {
      score++;
      debugPrint("Condition 2: Ankle dist (${ankleDistance.toStringAsFixed(1)}) > Knee dist (${kneeDistance.toStringAsFixed(1)})");
    } else {
      debugPrint("Condition 2: Ankle dist (${ankleDistance.toStringAsFixed(1)}) <= Knee dist (${kneeDistance.toStringAsFixed(1)})");
    }

    if (kneeDistance > hipDistance) {
      score++;
      debugPrint(" Condition 3: Knee dist (${kneeDistance.toStringAsFixed(1)}) > Hip dist (${hipDistance.toStringAsFixed(1)})");
    } else {
      debugPrint(" Condition 3: Knee dist (${kneeDistance.toStringAsFixed(1)}) <= Hip dist (${hipDistance.toStringAsFixed(1)})");
    }

    if (ankleDistance > leftLegDist && ankleDistance > rightLegDist) {
      score++;
      debugPrint("Condition 4: Ankle dist (${ankleDistance.toStringAsFixed(1)}) > Left leg (${leftLegDist.toStringAsFixed(1)}) & Right leg (${rightLegDist.toStringAsFixed(1)})");
    } else {
      debugPrint("Condition 4: Ankle dist (${ankleDistance.toStringAsFixed(1)}) <= Leg distances (L:${leftLegDist.toStringAsFixed(1)}, R:${rightLegDist.toStringAsFixed(1)})");
    }

    debugPrint(" W-Sitting Score: $score/4");
    return score >= 3;
  }
  bool isHeadDown(Pose pose, {bool severe = false}) {
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if ([nose, leftShoulder, rightShoulder, leftHip, rightHip]
        .any((p) => p == null)) {
      debugPrint("⚠️ Head Down: Missing landmarks");
      return false;
    }

    final midShoulder = Offset(
      (leftShoulder!.x + rightShoulder!.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );

    final midHip = Offset(
      (leftHip!.x + rightHip!.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );

    if (severe) {
      final angle = angleBetween(
        Offset(nose!.x, nose.y),
        midShoulder,
        midHip,
      );

      final threshold = 120.0;
      final isNoseBelowShoulder = angle< threshold;

      debugPrint("🚨 SEVERE Head Down Check:");
      debugPrint("   Nose Y: ${nose.y.toStringAsFixed(1)}");
      debugPrint("   Shoulder Y: ${midShoulder.dy.toStringAsFixed(1)}");
      debugPrint("   Nose below shoulder: $isNoseBelowShoulder");

      return isNoseBelowShoulder;
    }

    else {
      final angle = angleBetween(
        Offset(nose!.x, nose.y),
        midShoulder,
        midHip,
      );

      final threshold = 140.0;

      debugPrint("⚠️ Normal Head Down Check:");
      debugPrint("   Nose-Shoulder-Hip Angle: ${angle.toStringAsFixed(1)}°");
      debugPrint("   Threshold: < $threshold°");

      final result = angle < threshold;

      debugPrint("   Result: ${result ? '⚠️ HEAD FORWARD' : '✅ NORMAL'}");

      return result;
    }
  }

  bool isBackBent(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    if ([leftKnee, rightKnee, leftShoulder, rightShoulder, leftHip, rightHip]
        .any((p) => p == null)) {
      debugPrint("Back Bending: Missing landmarks");
      return false;
    }

    final midKnee = Offset(
      (leftKnee!.x + rightKnee!.x) / 2,
      (leftKnee.y + rightKnee.y) / 2,
    );

    final midShoulder = Offset(
      (leftShoulder!.x + rightShoulder!.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );

    final midHip = Offset(
      (leftHip!.x + rightHip!.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    final adjustedKnee = Offset(
      midKnee.dx,   // ← نفس X بتاع الركبة
      midHip.dy,    // ← نفس Y بتاع Hip (المستوى الأفقي)
    );
    final sitting = isSitting(pose);

    // ✅ حساب الزاوية بين الركبة-الكتف-الورك
    final kneeShoulderHipAngle =  angleBetween(

      adjustedKnee ,
      midHip,
      midShoulder
        );

    // ✅ Thresholds حسب الوضع
    final angleThreshold = sitting ? 155.0 : 165.0;

    debugPrint("🔍 Back Bending Analysis (${sitting ? '🪑 SITTING' : '🧍 STANDING'}):");
    debugPrint("   Knee-Shoulder-Hip Angle: ${kneeShoulderHipAngle.toStringAsFixed(1)}° (threshold: <$angleThreshold°)");

    final result = kneeShoulderHipAngle < angleThreshold;

    debugPrint("   Result: ${result ? '⚠️ BENT' : '✅ STRAIGHT'}");

    return result;
  }


  // === Continuous Monitoring ===
  void checkWSitting(Pose pose) {
    debugPrint("\n=== 🪑 W-SITTING CHECK ===");
    debugPrint("Available landmarks: ${pose.landmarks.keys.length} points");

    if (isWSitting(pose)) {
      if (!_isWSitting) {
        _isWSitting = true;
        _wSitStartTime = DateTime.now();
        debugPrint(" W-Sitting timer STARTED");
      } else {
        final duration = DateTime.now().difference(_wSitStartTime!);
        debugPrint("️ W-Sitting duration: ${duration.inSeconds}s / 40s");
        if (duration.inSeconds > 10 && !_wAlarmTriggered) {
          debugPrint(" W-Sitting ALARM TRIGGERED!");
          playAlarm();
          showWarning('W-Sitting Detected');
          _wAlarmTriggered = true;
        }
      }
    } else {
      if (_isWSitting) {
        debugPrint(" W-Sitting CLEARED");
        clearWarning();
      }
      _isWSitting = false;
      _wSitStartTime = null;
      _wAlarmTriggered = false;
    }
  }

  void checkHeadDown(Pose pose) {
    debugPrint("\n=== HEAD DOWN CHECK ===");

    final headDownSevere = isHeadDown(pose, severe: true);

    if (headDownSevere) {
      if (!_isHeadDownSevere) {
        _isHeadDownSevere = true;
        _headDownSevereStartTime = DateTime.now();
        debugPrint("️ Head Down SEVERE timer STARTED (grace period: 30s)");
      } else {
        final duration = DateTime.now().difference(_headDownSevereStartTime!);
        debugPrint(" Head Down SEVERE duration: ${duration.inSeconds}s / 30s");
        if (duration.inSeconds > 10 && !_headDownSevereAlarmTriggered) {
          debugPrint(" Head Down SEVERE ALARM TRIGGERED (after grace period)!");
          playAlarm();
          showWarning('Severe Head Down Detected');
          _headDownSevereAlarmTriggered = true;
        }
      }
    } else {
      if (_isHeadDownSevere) {
        debugPrint(" Head Down SEVERE CLEARED");
        clearWarning();
      }
      _isHeadDownSevere = false;
      _headDownSevereStartTime = null;
      _headDownSevereAlarmTriggered = false;
    }

    final headDown = isHeadDown(pose, severe: false);

    if (headDown && !_headDownSevereAlarmTriggered) {
      if (!_isHeadDown) {
        _isHeadDown = true;
        _headDownStartTime = DateTime.now();
        debugPrint("️ Head Down timer STARTED (grace period: 60s)");
      } else {
        final duration = DateTime.now().difference(_headDownStartTime!);
        debugPrint("️ Head Down duration: ${duration.inSeconds}s / 60s");
        if (duration.inSeconds > 6 && !_headDownAlarmTriggered) {
          debugPrint(" Head Down ALARM TRIGGERED (after grace period)!");
          playAlarm();
          showWarning('Head Down Detected');
          _headDownAlarmTriggered = true;
        }
      }
    } else {
      if (_isHeadDown && !_headDownSevereAlarmTriggered) {
        debugPrint(" Head Down CLEARED");
        clearWarning();
      }
      _isHeadDown = false;
      _headDownStartTime = null;
      _headDownAlarmTriggered = false;
    }
  }

  void checkBackBending(Pose pose) {
    debugPrint("\n===  BACK BENDING CHECK ===");

    final bent = isBackBent(pose);

    if (bent) {
      if (!_isBackBent) {
        _isBackBent = true;
        _backBentStartTime = DateTime.now();
        _backAlarmTriggered = false;
        debugPrint(" Back Bending timer STARTED");
      } else {
        final duration = DateTime.now().difference(_backBentStartTime!);
        debugPrint(" Back Bending duration: ${duration.inSeconds}s / 40s");
        if (duration.inSeconds > 0 && !_backAlarmTriggered) {
          debugPrint(" Back Bending ALARM TRIGGERED!");
          playAlarm();
          showWarning('Back Bending Detected');
          _backAlarmTriggered = true;
        }
      }
    } else {
      if (_isBackBent) {
        debugPrint(" Back Bending CLEARED");
        clearWarning();
      }
      _isBackBent = false;
      _backBentStartTime = null;
      _backAlarmTriggered = false;
    }
  }

  // === Keypoint Near Contour ===
  void checkKeypointsNearContour(List<Offset> contour, List<Pose> poses) {
    if (contour.isEmpty || poses.isEmpty) return;

    const threshold = 30.0;
    debugPrint("\n===  CONTOUR CHECK ===");
    debugPrint("Contour points: ${contour.length}");

    for (final pose in poses) {
      for (final landmark in pose.landmarks.values) {
        final point = Offset(landmark.x, landmark.y);
        for (final contourPoint in contour) {
          final distance = (point - contourPoint).distance;
          if (distance < threshold) {
            debugPrint(" Keypoint near contour! Distance: ${distance.toStringAsFixed(1)}");
            playAlarm();
            showWarning('Danger Zone!');
            return;
          }
        }
      }
    }
  }

  // === Dispose ===
  void dispose() {
    warningText.dispose();
    debugPrint("PostureMonitor disposed");
  }
}