import 'package:cloud_firestore/cloud_firestore.dart';

final _routesCollection = FirebaseFirestore.instance.collection('savedRoutes');

Future<void> saveRouteToFirestore({
  required String routeId,
  required String fromStation,
  required String toStation,
  required DateTime? selectedDepartureDay,
  required String selectedTimeRange,
  required List<Map<String, dynamic>> routeSteps,
  required Map<String, dynamic> routeDetailsRaw,
  String? note,
}) async {
  // Current user ID (or fallback)
  final uid = '1000';

  // Save the detail fields
  final legs = routeDetailsRaw['legs'] as List?;
  final leg = legs?.isNotEmpty == true ? legs!.first : null;

  final routeDetails = {
    'arrivalTime' : leg?['arrival_time']?['text'] ?? '',
    'departureTime' : leg?['departure_time']?['text'] ?? '',
    'distance' : leg?['distance']?['text'] ?? '',
    'duration' : leg?['duration']?['text'] ?? '',
    'selectedDepartureDay': selectedDepartureDay,
    'selectedTimeRange'    : selectedTimeRange,
  };

  final query =
  await _routesCollection
      .where('routeId', isEqualTo: routeId)
      .limit(1)
      .get();

  if (query.docs.isNotEmpty) {
    // For updates, only update specific fields that can change
    final updateData = {
      'fromStation': fromStation,
      'toStation': toStation,
      'routeSteps': routeSteps,
      'routeDetails': routeDetails,
      'routeDetailsRaw': routeDetailsRaw,
      'note': note ?? '',
    };

    await query.docs.first.reference.update(updateData);
  } else {
    // For new routes, include all fields
    final routeData = {
      // Core metadata
      'routeId': routeId,
      'fromStation': fromStation,
      'toStation': toStation,
      'routeSteps': routeSteps,
      'routeDetails': routeDetails,
      'note': note ?? '',

      // Tracking
      'savedAt': Timestamp.now(),
      'userID': uid,
    };

    // Also store the raw route data for editing purposes
    routeData['routeDetailsRaw'] = routeDetailsRaw;

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