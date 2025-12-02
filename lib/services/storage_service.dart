import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String?> uploadImage(File file, String userId) async {
    try {
      final String fileName = '${_uuid.v4()}.jpg';
      final Reference ref = _storage.ref().child(
        'users/$userId/uploads/$fileName',
      );

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading image: $e");
      throw e;
    }
  }

  Future<String?> uploadImageBytes(Uint8List data, String userId) async {
    try {
      final bool isPng =
          data.length > 8 &&
          data[0] == 0x89 &&
          data[1] == 0x50 &&
          data[2] == 0x4E &&
          data[3] == 0x47 &&
          data[4] == 0x0D &&
          data[5] == 0x0A &&
          data[6] == 0x1A &&
          data[7] == 0x0A;

      final String ext = isPng ? 'png' : 'jpg';
      final String contentType = isPng ? 'image/png' : 'image/jpeg';
      final String fileName = '${_uuid.v4()}.$ext';
      final Reference ref = _storage.ref().child(
        'users/$userId/generated/$fileName',
      );

      final UploadTask uploadTask = ref.putData(
        data,
        SettableMetadata(contentType: contentType),
      );
      final TaskSnapshot snapshot = await uploadTask;

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading image bytes: $e");
      throw e;
    }
  }
}
