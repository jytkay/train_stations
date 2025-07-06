import 'package:cloud_firestore/cloud_firestore.dart';

final _remindersCollection = FirebaseFirestore.instance.collection('savedRoutes');

Future<List<Map<String, dynamic>>> getRemindersByUser(String userID) async {
  final query = await _remindersCollection.where('userID', isEqualTo: userID).get();
  return query.docs.map((doc) {
    final data = doc.data();
    data['documentId'] = doc.id;
    return data;
  }).toList();
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

Future<void> updateAlarmDetails({
  required String documentId,
  required DateTime alarmTime,
  required String alarmMode,
  required bool isActive,
}) async {
  await _remindersCollection.doc(documentId).update({
    'alarmTime': alarmTime,
    'alarmMode': alarmMode,
    'notificationStatus': isActive,
  });
}
