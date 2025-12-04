import 'dart:io';
import 'dart:math';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../firebase_options.dart';
import 'storage_service.dart';
import 'firestore_service.dart';

class FunctionsService {
  // Using Firebase AI (Gemini)

  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();

  Future<List<String>> generateImages(
    File imageFile,
    String userId,
    List<String> scenes,
  ) async {
    try {
      final int tStart = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[generateImages] start');
      // Ensure Firebase is initialized (it usually is in main, but good to be safe)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Already initialized
      }

      // 1. Compress input and upload Original Image to Firebase Storage
      String? originalImageUrl;
      Uint8List imageBytes;
      try {
        final int tComp0 = DateTime.now().millisecondsSinceEpoch;
        final List<int>? compressed =
            await FlutterImageCompress.compressWithFile(
              imageFile.path,
              minWidth: 1280,
              minHeight: 1280,
              quality: 80,
              format: CompressFormat.jpeg,
            );
        final int tComp1 = DateTime.now().millisecondsSinceEpoch;
        debugPrint(
          '[generateImages] compress ${tComp1 - tComp0}ms size=${compressed?.length ?? 0}',
        );
        imageBytes = Uint8List.fromList(
          compressed ?? await imageFile.readAsBytes(),
        );
        final int tUp0 = DateTime.now().millisecondsSinceEpoch;
        originalImageUrl = await _storageService.uploadOriginalImageBytes(
          imageBytes,
          userId,
        );
        final int tUp1 = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[generateImages] original upload ${tUp1 - tUp0}ms');
      } catch (e) {
        debugPrint("[generateImages] Error compress/upload original: $e");
        // Fallback to direct file upload
        try {
          final int tUp0 = DateTime.now().millisecondsSinceEpoch;
          originalImageUrl = await _storageService.uploadImage(
            imageFile,
            userId,
          );
          final int tUp1 = DateTime.now().millisecondsSinceEpoch;
          debugPrint(
            '[generateImages] original upload (fallback) ${tUp1 - tUp0}ms',
          );
          imageBytes = await imageFile.readAsBytes();
        } catch (e2) {
          debugPrint('[generateImages] fallback upload failed: $e2');
          imageBytes = await imageFile.readAsBytes();
        }
      }

      final scenePool = [
        'sunny beach vacation',
        'European city street',
        'scenic mountain lookout',
        'coastal cliffs at sunset',
        'cozy café interior',
        'snowy cabin retreat',
        'desert road trip',
        'rooftop skyline at night',
        'tropical waterfall',
        'forest trail',
        'museum or cultural landmark',
        'sailing boat',
        'lakeside pier at dawn',
        'modern art gallery',
        'country farmhouse',
      ];
      final rng = Random();
      final List<String> scenesToUse = List<String>.from(scenes);
      if (scenesToUse.length < 4) {
        final remaining =
            scenePool.where((e) => !scenesToUse.contains(e)).toList()
              ..shuffle(rng);
        scenesToUse.addAll(remaining.take(4 - scenesToUse.length));
      } else if (scenesToUse.length > 4) {
        scenesToUse.removeRange(4, scenesToUse.length);
      }
      final promptText =
          'Create 4 separate photorealistic images of this person in these scenes: '
          'Use these distinct scenes: (1) ${scenesToUse[0]}, (2) ${scenesToUse[1]}, (3) ${scenesToUse[2]}, (4) ${scenesToUse[3]}. '
          'Keep facial identity and hairstyle. Do not make collages or grids. Return 4 images.';

      debugPrint('[generateImages] input bytes ${imageBytes.length}');
      // Simple mime type detection
      final String mimeType = 'image/jpeg';

      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-image',
        generationConfig: GenerationConfig(
          responseModalities: [ResponseModalities.image],
        ),
      );

      List<String> firebaseUrls = [];

      // 3. Generate with a single request and collect up to 4 images
      final content = Content.multi([
        TextPart(promptText),
        InlineDataPart(mimeType, imageBytes),
      ]);

      final int tGen0 = DateTime.now().millisecondsSinceEpoch;
      final response = await model.generateContent([content]);
      final int tGen1 = DateTime.now().millisecondsSinceEpoch;
      debugPrint(
        '[generateImages] primary generateContent ${tGen1 - tGen0}ms parts=${response.inlineDataParts.length}',
      );

      if (response.inlineDataParts.isNotEmpty) {
        for (final part in response.inlineDataParts.take(4)) {
          final bytes = part.bytes;
          final int tUpI0 = DateTime.now().millisecondsSinceEpoch;
          final url = await _storageService.uploadImageBytes(bytes, userId);
          final int tUpI1 = DateTime.now().millisecondsSinceEpoch;
          debugPrint('[generateImages] image upload ${tUpI1 - tUpI0}ms');
          if (url != null) {
            firebaseUrls.add(url);
          }
        }
      }

      if (firebaseUrls.length < 4) {
        final used = <String>{...scenesToUse};
        int attempts = 0;
        while (firebaseUrls.length < 4 && attempts < 2) {
          final List<String> batch = List<String>.from(scenesToUse);
          final futures = batch.map((s) async {
            final c = Content.multi([
              TextPart(
                'Create a single photorealistic image of this person in this scene: $s. Keep identity and hairstyle. No collages.',
              ),
              InlineDataPart(mimeType, imageBytes),
            ]);
            final int tGenS0 = DateTime.now().millisecondsSinceEpoch;
            final r = await model.generateContent([c]);
            final int tGenS1 = DateTime.now().millisecondsSinceEpoch;
            debugPrint(
              '[generateImages] per-scene "$s" ${tGenS1 - tGenS0}ms parts=${r.inlineDataParts.length}',
            );
            if (r.inlineDataParts.isNotEmpty) {
              final bytes = r.inlineDataParts.first.bytes;
              final int tUpS0 = DateTime.now().millisecondsSinceEpoch;
              final url = await _storageService.uploadImageBytes(bytes, userId);
              final int tUpS1 = DateTime.now().millisecondsSinceEpoch;
              debugPrint(
                '[generateImages] per-scene upload ${tUpS1 - tUpS0}ms',
              );
              return url;
            }
            return null;
          });
          final results = await Future.wait(futures);
          for (final url in results) {
            if (url != null) {
              firebaseUrls.add(url);
              if (firebaseUrls.length >= 4) break;
            }
          }
          if (firebaseUrls.length < 4) {
            final remaining = scenePool.where((e) => !used.contains(e)).toList()
              ..shuffle(rng);
            final needed = 4 - firebaseUrls.length;
            final extra = remaining.take(needed).toList();
            scenesToUse
              ..clear()
              ..addAll(extra);
            used.addAll(extra);
            attempts++;
          }
        }
      }

      // 4. Store Metadata in Firestore
      if (firebaseUrls.isNotEmpty && originalImageUrl != null) {
        final int tFs0 = DateTime.now().millisecondsSinceEpoch;
        await _firestoreService.saveRemix(
          userId: userId,
          originalImageUrl: originalImageUrl,
          generatedImageUrls: firebaseUrls,
        );
        final int tFs1 = DateTime.now().millisecondsSinceEpoch;
        debugPrint('[generateImages] firestore save ${tFs1 - tFs0}ms');
      }

      if (firebaseUrls.isNotEmpty) {
        final int tEnd = DateTime.now().millisecondsSinceEpoch;
        debugPrint(
          '[generateImages] total ${tEnd - tStart}ms, returned ${firebaseUrls.length} images',
        );
        return firebaseUrls;
      }

      return _getMockImages();
    } catch (e) {
      debugPrint("[generateImages] Error calling Gemini: $e");
      return _getMockImages();
    }
  }

  List<String> _getMockImages() {
    return [
      'https://picsum.photos/seed/101/400/400',
      'https://picsum.photos/seed/102/400/400',
      'https://picsum.photos/seed/103/400/400',
      'https://picsum.photos/seed/104/400/400',
    ];
  }
}
