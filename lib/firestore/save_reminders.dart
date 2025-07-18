import 'package:cloud_firestore/cloud_firestore.dart';

final _remindersCollection = FirebaseFirestore.instance.collection('savedReminders');

Future<List<Map<String, dynamic>>> getRemindersByUser(String userId) async {
  final query = await _remindersCollection.where('userId', isEqualTo: userId).get();
  return query.docs.map((doc) {
    final data = doc.data();
    data['documentId'] = doc.id;
    return data;
  }).toList();
}

Future<void> saveReminderToFirestore({
  required String userId,
  required String routeId,
  required String fromStation,
  required String toStation,
  required String departureTime,
  required String arrivalTime,
  required DateTime alarmTime,
  required String alarmMode,
  required bool isActive,
  List<String>? selectedDays,
  List<Map<String, dynamic>>? routeSteps,
}) async {
  await _remindersCollection.add({
    'userId': userId,
    'routeId': routeId,
    'fromStation': fromStation,
    'toStation': toStation,
    'departureTime': departureTime,
    'arrivalTime': arrivalTime,
    'alarmTime': Timestamp.fromDate(alarmTime),
    'alarmMode': alarmMode,
    'notificationStatus': isActive,
    'selectedDays': selectedDays ?? [],
    'routeSteps': routeSteps ?? [], // Store the route steps
    'createdAt': Timestamp.now(),
  });
}

Future<void> updateAlarmDetails({
  required String documentId,
  required DateTime alarmTime,
  required String alarmMode,
  required bool isActive,
  List<String>? selectedDays,
}) async {
  await _remindersCollection.doc(documentId).update({
    'alarmTime': Timestamp.fromDate(alarmTime),
    'alarmMode': alarmMode,
    'notificationStatus': isActive,
    'selectedDays': selectedDays ?? [],
  });
}

Future<void> updateReminderTime({
  required String documentId,
  required DateTime newTime,
}) async {
  await _remindersCollection.doc(documentId).update({
    'alarmTime': Timestamp.fromDate(newTime),
  });
}

Future<void> setReminderStatus({
  required String documentId,
  required bool isActive,
}) async {
  await _remindersCollection.doc(documentId).update({
    'notificationStatus': isActive,
  });
}

Future<void> deleteReminder(String documentId) async {
  await _remindersCollection.doc(documentId).delete();
}

Future<bool> hasReminderForRoute({
  required String userId,
  required String fromStation,
  required String toStation,
}) async {
  final query = await _remindersCollection
      .where('userId', isEqualTo: userId)
      .where('fromStation', isEqualTo: fromStation)
      .where('toStation', isEqualTo: toStation)
      .get();

  return query.docs.isNotEmpty;
}

Future<Map<String, dynamic>?> getReminderForRoute({
  required String userId,
  required String fromStation,
  required String toStation,
}) async {
  final query = await _remindersCollection
      .where('userId', isEqualTo: userId)
      .where('fromStation', isEqualTo: fromStation)
      .where('toStation', isEqualTo: toStation)
      .limit(1)
      .get();

  if (query.docs.isEmpty) return null;

  final doc = query.docs.first;
  final data = doc.data();
  data['documentId'] = doc.id;
  return data;
}