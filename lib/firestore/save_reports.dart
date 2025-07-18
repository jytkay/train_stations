import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> saveUserReport(String feedbackMessage) async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    throw Exception('No user is currently signed in.');
  }

  final reportData = {
    'userId': currentUser.uid,
    'email': currentUser.email ?? '',
    'message': feedbackMessage.trim(),
    'timestamp': FieldValue.serverTimestamp(),
  };

  await FirebaseFirestore.instance.collection('savedReports').add(reportData);
}