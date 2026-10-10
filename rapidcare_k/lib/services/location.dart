import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Returns a recent, usable device fix. Throws a readable error if location
/// services, permission, GPS accuracy, or the fix itself is unavailable.
Future<Position> getFreshLocation({
  Duration timeout = const Duration(seconds: 20),
  double maxAccuracyMeters = kIsWeb ? 500 : 100,
  void Function(Position position)? onPosition,
}) async {
  if (!await Geolocator.isLocationServiceEnabled().timeout(
    const Duration(seconds: 5),
  )) {
    throw Exception('Turn on device location services and try again.');
  }
  var permission = await Geolocator.checkPermission().timeout(
    const Duration(seconds: 5),
  );
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission().timeout(
      const Duration(seconds: 10),
    );
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception(
      'Location permission is blocked. Allow it in app or browser settings.',
    );
  }
  if (permission == LocationPermission.denied) {
    throw Exception('Allow location access to use live location.');
  }
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    final accuracy = await Geolocator.getLocationAccuracy().timeout(
      const Duration(seconds: 5),
    );
    if (accuracy == LocationAccuracyStatus.reduced) {
      throw Exception(
        'Precise location is turned off for RapidCare. Enable Precise location '
        'in the app permissions, then retry.',
      );
    }
  }

  LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
  );
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: Duration(seconds: 1),
    );
  }
  final fixes = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  );
  final result = Completer<Position>();
  final stopwatch = Stopwatch()..start();
  Position? best;
  StreamSubscription<Position>? subscription;
  Timer? timeoutTimer;
  Timer? refinementTimer;

  void finish() {
    if (!result.isCompleted && best != null) result.complete(best);
  }

  subscription = fixes.listen(
    (position) {
      final age = DateTime.now().difference(position.timestamp);
      if (age > const Duration(minutes: 2) ||
          age < const Duration(seconds: -30) ||
          !position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude < -90 ||
          position.latitude > 90 ||
          position.longitude < -180 ||
          position.longitude > 180 ||
          !position.accuracy.isFinite ||
          position.accuracy < 0) {
        return;
      }

      onPosition?.call(position);
      if (best == null || position.accuracy < best!.accuracy) {
        best = position;
      }

      // Keep sampling briefly after a usable fix so a later reading can be more precise.
      if (stopwatch.elapsed >= const Duration(seconds: 4) &&
          best!.accuracy <= maxAccuracyMeters) {
        finish();
      } else if (best!.accuracy <= maxAccuracyMeters &&
          refinementTimer == null) {
        refinementTimer = Timer(const Duration(seconds: 4), finish);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    },
  );

  timeoutTimer = Timer(timeout, () {
    if (result.isCompleted) return;
    if (best != null) {
      finish();
    } else {
      result.completeError(
        Exception(
          'No fresh GPS fix arrived within ${timeout.inSeconds} seconds. '
          'Check location permission and precise-location settings, then move outdoors or near a window and retry.',
        ),
      );
    }
  });

  try {
    return await result.future;
  } finally {
    timeoutTimer.cancel();
    refinementTimer?.cancel();
    await subscription.cancel();
  }
}
