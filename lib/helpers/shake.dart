library shake;

import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Callback for phone shakes
typedef void PhoneShakeCallback(ShakeDirection direction);

// Enum to represent the shake direction
enum ShakeDirection { Up, Down, None }

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

  ShakeDirection currentDirection = ShakeDirection.None;

  /// This constructor waits until [startListening] is called
  ShakeDetector.waitForStart({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 1.3, //2.7,
    this.shakeSlopTimeMS = 100, //500,
    this.shakeCountResetTime = 3000,
    this.minimumShakeCount = 1,
  });

  /// This constructor automatically calls [startListening] and starts detection and callbacks.
  ShakeDetector.autoStart({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 1.3, //2.7,
    this.shakeSlopTimeMS = 100, //500,
    this.shakeCountResetTime = 3000,
    this.minimumShakeCount = 0, //1,
  }) {
    startListening();
  }

  /// Starts listening to accelerometer events
  void startListening() {
    accelerometerSS = accelerometerEvents.listen(
      (AccelerometerEvent event) {
        double x = event.x;
        double y = event.y;
        double z = event.z;

        double gX = x / 9.80665;
        double gY = y / 9.80665;
        double gZ = z / 9.80665;

        // gForce will be close to 1 when there is no movement.
        double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

        if (gForce > shakeThresholdGravity) {
          var now = DateTime.now().millisecondsSinceEpoch;
          // ignore shake events too close to each other (500ms)
          if (mShakeTimestamp + shakeSlopTimeMS > now) {
            return;
          }

          // reset the shake count after 3 seconds of no shakes
          if (mShakeTimestamp + shakeCountResetTime < now) {
            mShakeCount = 0;
            accelerometerData.clear();
          }

          mShakeTimestamp = now;
          mShakeCount++;
          accelerometerData.add(gForce);

          if (gForce > 2) {
            currentDirection = ShakeDirection.Down;
          } else {
            currentDirection = ShakeDirection.Up;
          }
        
        } else {
          // User is stationary
          if (currentDirection != ShakeDirection.None) {
            onPhoneShake(
                currentDirection); // Notify with the direction
            currentDirection = ShakeDirection.None;
          }
        }
      },
    );

    gyroscopeEvents.listen((GyroscopeEvent event) {
      double x = event.x;
      double y = event.y;
      double z = event.z;

      double velocity = sqrt(x * x + y * y + z * z);
    });
  }

  /// Stops listening to accelerometer events
  void stopListening() {
    accelerometerSS?.cancel();
    gyroscopeSS?.cancel();
  }

  // Function to calculate the shake direction
  ShakeDirection calculateShakeDirection() {
    if (accelerometerData.isNotEmpty) {
      double maxGForce = accelerometerData.reduce(max);
      double minGForce = accelerometerData.reduce(min);

      // Adjust these thresholds as needed
      if (maxGForce - minGForce > 0.2) {
        return ShakeDirection.Up;
      } else {
        return ShakeDirection.Down;
      }
    } else {
      return ShakeDirection.None;
    }
  }
}
