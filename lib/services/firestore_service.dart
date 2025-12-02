import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveRemix({
    required String userId,
    required String originalImageUrl,
    required List<String> generatedImageUrls,
  }) async {
    try {
      await _firestore.collection('remixes').add({
        'userId': userId,
        'originalImageUrl': originalImageUrl,
        'generatedImageUrls': generatedImageUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving remix to Firestore: $e");
      throw e;
    }
  }
}
