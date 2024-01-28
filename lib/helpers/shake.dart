import 'dart:async';
import 'dart:math';
import '../enums.dart';

import 'package:sensors_plus/sensors_plus.dart';

/// Callback for phone shakes
typedef PhoneShakeCallback = void Function(ShakeAxis axis);

/// ShakeDetector class for phone shake functionality
class ShakeDetector {
  /// User callback for phone shake
  final PhoneShakeCallback onPhoneShake;

  /// Shake detection threshold
  final double shakeThresholdGravity;

  /// Minimum time between shake
  final int shakeSlopTimeMS;

  /// Time before shake count resets
  final int shakeCountResetTime;

  /// Number of shakes required before shake is triggered
  final int minimumShakeCount;

  int mShakeTimestamp = DateTime.now().millisecondsSinceEpoch;
  int mShakeCount = 0;

  /// StreamSubscription for events
  StreamSubscription? accelerometerSS;
  StreamSubscription? gyroscopeSS;

  List<double> accelerometerData = [];
  List<double> gyroscopeData = [];

  /// This constructor waits until [startListening] is called
  ShakeDetector.waitForStart({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 1.3,
    this.shakeSlopTimeMS = 300,
    this.shakeCountResetTime = 3000,
    this.minimumShakeCount = 0,
  });

  /// This constructor automatically calls [startListening] and starts detection and callbacks.
  ShakeDetector.autoStart({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 1.3,
    this.shakeSlopTimeMS = 300,
    this.shakeCountResetTime = 3000,
    this.minimumShakeCount = 0,
  }) {
    startListening();
  }

  double prevX = 0;
  double lowestX = 100000;
  List<double> xShakes = [];
  double prevY = 0;
  double lowestY = 100000;
  List<double> yShakes = [];
  double prevZ = 0;
  double lowestZ = 100000;
  List<double> zShakes = [];
  double prevGForce = 0;
  double prevGRate = 0;
  bool gRateMatch = false;

  /// Starts listening to accelerometer events
  void startListening() {
    accelerometerSS =
        accelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen(
      (AccelerometerEvent event) {
        double x = event.x;
        if (lowestX == 100000) {
          lowestX = x;
        } else if (x < lowestX) {
          lowestX = x;
        }
        double y = event.y;
        if (lowestY == 100000) {
          lowestY = y;
        } else if (y < lowestY) {
          lowestY = y;
        }
        double z = event.z;
        if (lowestZ == 100000) {
          lowestZ = z;
        } else if (z < lowestZ) {
          lowestZ = z;
        }

        double timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;

        double gX = x / 9.80665;
        double gY = y / 9.80665;
        double gZ = z / 9.80665;

        // derivative
        double dx = gX - prevX;
        double dy = gY - prevY;
        double dz = gZ - prevZ;

        prevX = gX;
        prevY = gY;
        prevZ = gZ;

        // gForce will be close to 1 when there is no movement.
        double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

        // Add the current gForce to the list
        accelerometerData.add(gForce);

        // Keep only the last 8 values in the list
        if (accelerometerData.length > 8) {
          accelerometerData.removeAt(0);
        }

        double gForceMA = accelerometerData.reduce((a, b) => a + b) /
            accelerometerData.length;

        double gRate = gForceMA - prevGForce;

        if (gRate == 0 ||
            (prevGRate > 0 && gRate < 0) ||
            (prevGRate < 0 && gRate > 0)) {
          gRateMatch = true;
        }

        prevGForce = gForceMA;
        prevGRate = gRate;

        // print("timestamp: $timestamp");
        // print("x: $x");
        // print("y: $y");
        // print("z: $z");

        if (gRateMatch && gForceMA > shakeThresholdGravity) {
          gRateMatch = false;
          // print("gForce: $gForce, prevGForce: $prevGForce, gRate: $gRate, prevGRate: $prevGRate");
          // print("gRate: $gRate, prevGRate: $prevGRate");
          var now = DateTime.now().millisecondsSinceEpoch;
          // ignore shake events too close to each other (100ms)
          if (mShakeTimestamp + shakeSlopTimeMS > now) {
            return;
          }

          mShakeTimestamp = now;

          double xDiff = (lowestX - x).abs();
          double yDiff = (lowestY - y).abs();
          double zDiff = (lowestZ - z).abs();

          if (xDiff > yDiff && xDiff > zDiff) {
            // xShakes.add(xDiff);
            onPhoneShake(ShakeAxis.lr);
          } else if (yDiff > xDiff && yDiff > zDiff) {
            // yShakes.add(yDiff);
            onPhoneShake(ShakeAxis.ud);
          } else if (zDiff > xDiff && zDiff > yDiff) {
            // zShakes.add(zDiff);
            onPhoneShake(ShakeAxis.fb);
          }

          // reset lowest values
          lowestX = 100000;
          lowestY = 100000;
          lowestZ = 100000;
          // onPhoneShake();
        }
      },
    );

    // gyroscopeEventStream(samplingPeriod: SensorInterval.fastestInterval).listen((GyroscopeEvent event) {
    //   double x = event.x;
    //   double y = event.y;
    //   double z = event.z;

    //   double velocity = sqrt(x * x + y * y + z * z);
    // });
  }

  /// Stops listening to accelerometer events
  void stopListening() {
    accelerometerSS?.cancel();
    gyroscopeSS?.cancel();
  }
}
