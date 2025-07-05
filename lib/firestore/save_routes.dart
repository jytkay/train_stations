import 'package:cloud_firestore/cloud_firestore.dart';

final _routesCollection = FirebaseFirestore.instance.collection('savedRoutes');

Future<void> saveRouteToFirestore({
  required String routeId,
  required String fromStation,
  required String toStation,
  required List<Map<String, dynamic>> routeSteps,
  required Map<String, dynamic> routeDetailsRaw,
  String? note,
}) async {
  // Current user ID (or fallback)
  final uid = 'anonymous';

  // Only the required detail fields
  final routeDetails = {
    'arrivalTime': routeDetailsRaw['arrivalTime'],
    'departureTime': routeDetailsRaw['departureTime'],
    'distance': routeDetailsRaw['distance'],
    'duration': routeDetailsRaw['duration'],
    'selectedDepartureTime': null,
    'selectedTimeRange':
        routeDetailsRaw['selectedTimeRange'] ?? 'Any depart time',
  };

  final routeData = {
    // Alarm placeholders
    'alarmMode': null,
    'alarmTime': null,

    // Core metadata
    'routeId': routeId,
    'fromStation': fromStation,
    'toStation': toStation,
    'routeSteps': routeSteps,
    'routeDetails': routeDetails,
    'note': note ?? '',

    // Notification & tracking
    'notificationStatus': null,
    'savedAt': Timestamp.now(),
    'userID': uid,
  };

  final query =
      await _routesCollection
          .where('routeId', isEqualTo: routeId)
          .limit(1)
          .get();

  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.update(routeData);
  } else {
    await _routesCollection.add(routeData);
  }
}

Future<bool> isRouteSaved(String routeId) async {
  final query =
      await _routesCollection
          .where('routeId', isEqualTo: routeId)
          .limit(1)
          .get();
  return query.docs.isNotEmpty;
}

Future<Map<String, dynamic>?> getSavedRouteById(String routeId) async {
  final query =
      await _routesCollection
          .where('routeId', isEqualTo: routeId)
          .limit(1)
          .get();
  if (query.docs.isNotEmpty) return query.docs.first.data();
  return null;
}

Future<void> removeRouteById(String routeId) async {
  final query =
      await _routesCollection
          .where('routeId', isEqualTo: routeId)
          .limit(1)
          .get();
  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.delete();
  }
}
