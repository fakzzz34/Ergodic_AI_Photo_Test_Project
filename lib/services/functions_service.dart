import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
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
      // Ensure Firebase is initialized (it usually is in main, but good to be safe)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Already initialized
      }

      // 1. Upload Original Image to Firebase Storage
      String? originalImageUrl;
      try {
        originalImageUrl = await _storageService.uploadImage(imageFile, userId);
      } catch (e) {
        print("Error uploading original image: $e");
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
          'Generate exactly 4 separate, standalone photorealistic images from this portrait. '
          'Use these distinct scenes: (1) ${scenesToUse[0]}, (2) ${scenesToUse[1]}, (3) ${scenesToUse[2]}, (4) ${scenesToUse[3]}. '
          'Maintain the person’s facial identity and hairstyle. High quality, Instagram-ready composition. '
          'Do NOT combine multiple scenes into a single collage, grid, split-screen, or multi-panel image. '
          'Return 4 image outputs only.';

      final Uint8List imageBytes = await imageFile.readAsBytes();
      // Simple mime type detection
      final String mimeType = imageFile.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

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

      final response = await model.generateContent([content]);

      if (response.inlineDataParts.isNotEmpty) {
        for (final part in response.inlineDataParts.take(4)) {
          final bytes = part.bytes;
          final url = await _storageService.uploadImageBytes(bytes, userId);
          if (url != null) {
            firebaseUrls.add(url);
          }
        }
      }

      if (firebaseUrls.length < 4) {
        final used = <String>{...scenesToUse};
        int attempts = 0;
        while (firebaseUrls.length < 4 && attempts < 6) {
          for (final s in scenesToUse) {
            if (firebaseUrls.length >= 4) break;
            final c = Content.multi([
              TextPart(
                'Generate a standalone photorealistic image from this portrait in the following scene: $s. Maintain the person’s facial identity and hairstyle. High quality, Instagram-ready composition. Do NOT combine multiple scenes into a collage, grid, split-screen, or multi-panel image. Return image outputs only.',
              ),
              InlineDataPart(mimeType, imageBytes),
            ]);
            final r = await model.generateContent([c]);
            if (r.inlineDataParts.isNotEmpty) {
              final bytes = r.inlineDataParts.first.bytes;
              final url = await _storageService.uploadImageBytes(bytes, userId);
              if (url != null) {
                firebaseUrls.add(url);
              }
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
        await _firestoreService.saveRemix(
          userId: userId,
          originalImageUrl: originalImageUrl,
          generatedImageUrls: firebaseUrls,
        );
      }

      if (firebaseUrls.isNotEmpty) {
        return firebaseUrls;
      }

      return _getMockImages();
    } catch (e) {
      print("Error calling Gemini: $e");
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
