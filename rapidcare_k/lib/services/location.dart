import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Returns the freshest valid device fix available to the app.
///
/// Permission is requested automatically for explicit user actions. Background
/// polling can pass requestPermission=false so it never repeatedly opens a
/// permission prompt. Approximate Android permission is accepted because it is
/// still a valid coordinate and must not block emergency dispatch.
Future<Position> getFreshLocation({
  Duration timeout = const Duration(seconds: 20),
  double maxAccuracyMeters = kIsWeb ? 500 : 100,
  void Function(Position position)? onPosition,
  bool requestPermission = true,
}) async {
  await _ensureLocationAccess(requestPermission: requestPermission);

  final settings = _locationSettings();

  // Fast path: ask the platform for its best available current fix.
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    ).timeout(timeout);
    _validatePosition(position);
    onPosition?.call(position);
    return position;
  } catch (_) {
    // Fall through to a stream because providers often need extra startup time.
  }

  // Fallback: keep listening until a valid fix arrives. This helps when the
  // first current-position request races with Android/iOS provider startup.
  final result = Completer<Position>();
  final fixes = Geolocator.getPositionStream(locationSettings: settings);
  StreamSubscription<Position>? subscription;
  Timer? timeoutTimer;
  Position? best;

  void finish() {
    if (!result.isCompleted && best != null) result.complete(best);
  }

  subscription = fixes.listen(
    (position) {
      try {
        _validatePosition(position);
      } catch (_) {
        return;
      }
      onPosition?.call(position);
      if (best == null || position.accuracy < best!.accuracy) {
        best = position;
      }
      // Return promptly for emergency use, while preferring a reasonably
      // accurate reading when one is available.
      if (position.accuracy <= maxAccuracyMeters) finish();
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
          'No GPS fix arrived within ${timeout.inSeconds} seconds. '
          'Turn on device location and allow RapidCare location access, then retry.',
        ),
      );
    }
  });

  try {
    return await result.future;
  } finally {
    timeoutTimer.cancel();
    await subscription.cancel();
  }
}

Future<void> _ensureLocationAccess({required bool requestPermission}) async {
  final enabled = await Geolocator.isLocationServiceEnabled().timeout(
    const Duration(seconds: 5),
  );
  if (!enabled) {
    throw Exception('Turn on device location services and try again.');
  }

  var permission = await Geolocator.checkPermission().timeout(
    const Duration(seconds: 5),
  );
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.unableToDetermine) {
    if (!requestPermission) {
      throw Exception('Allow location access to use automatic live GPS.');
    }
    permission = await Geolocator.requestPermission().timeout(
      const Duration(seconds: 10),
    );
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception(
      'Location permission is blocked. Allow location access for RapidCare '
      'in app or browser settings.',
    );
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.unableToDetermine) {
    throw Exception('Allow location access to use automatic live GPS.');
  }
  // Do not reject reduced/approximate Android accuracy. It is still usable.
}

LocationSettings _locationSettings() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
      forceLocationManager: false,
    );
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      activityType: ActivityType.fitness,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );
}

void _validatePosition(Position position) {
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
    throw Exception('The device returned an invalid GPS fix.');
  }
}
