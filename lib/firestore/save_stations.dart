import 'package:cloud_firestore/cloud_firestore.dart';

final _stationsCollection = FirebaseFirestore.instance.collection('savedStations');

Future<void> saveStationToFirestore({
  required String userId,
  required String placeId,
  required String name,
  required String address,
  String? photoUrl,
  String? phoneNumber,
  String? websiteUrl,
  double? lat,
  double? lng,
  String? note,
}) async {
  final query = await _stationsCollection
      .where('userId', isEqualTo: userId)
      .where('placeId', isEqualTo: placeId)
      .limit(1)
      .get();

  final stationData = {
    'userId': userId,
    'placeId': placeId,
    'name': name,
    'address': address,
    'photoUrl': photoUrl ?? '',
    'phoneNumber': phoneNumber ?? '',
    'websiteUrl': websiteUrl ?? '',
    'lat': lat,
    'lng': lng,
    'note': note ?? '',
    'savedAt': Timestamp.now(),
  };

  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.update(stationData);
  } else {
    await _stationsCollection.add(stationData);
  }
}

Future<bool> isStationSaved(String userId, String placeId) async {
  final query = await _stationsCollection
      .where('userId', isEqualTo: userId)
      .where('placeId', isEqualTo: placeId)
      .limit(1)
      .get();
  return query.docs.isNotEmpty;
}

Future<Map<String, dynamic>?> getSavedStationByPlaceId(String userId, String placeId) async {
  final query = await _stationsCollection
      .where('userId', isEqualTo: userId)
      .where('placeId', isEqualTo: placeId)
      .limit(1)
      .get();
  if (query.docs.isNotEmpty) {
    return query.docs.first.data();
  }
  return null;
}

Future<void> removeStationByPlaceId(String userId, String placeId) async {
  final query = await _stationsCollection
      .where('userId', isEqualTo: userId)
      .where('placeId', isEqualTo: placeId)
      .limit(1)
      .get();
  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.delete();
  }
}

Future<void> updateNoteForStation({
  required String userId,
  required String placeId,
  required String note,
}) async {
  final query = await _stationsCollection
      .where('userId', isEqualTo: userId)
      .where('placeId', isEqualTo: placeId)
      .limit(1)
      .get();

  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.update({'note': note});
  }
}