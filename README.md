# Ergodic AI Photo Remix

## Quick Start

1. **Configure Firebase:**
    - Run `flutterfire configure` to set up Firebase for your project.
2. **Install Dependencies:**
    - Run `flutter pub get` to install all required packages.
3. **Set Gemini API Key (Backend):**
    - Use `firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY"` to set your Gemini key for backend AI calls.
4. **Deploy Backend:**
    - Deploy Cloud Functions, Storage, and Firestore with `firebase deploy --only functions,storage,firestore`.
5. **Run the App:**
    - Use `flutter run` or `flutter run --dart-define=GEMINI_API_KEY="YOUR_ACTUAL_API_KEY"` to start the app locally.

## Architecture Overview

-   **Frontend:**
    -   Built with Flutter. Main UI in `HomeScreen`.
    -   Service layers: `FunctionsService`, `StorageService`, `FirestoreService`.
-   **Backend:**
    -   Cloud Function `Generate Remix Image` receives the uploaded image and selected scenes from the client, calls Gemini AI to generate 4 photorealistic images, uploads them to Firebase Storage, saves metadata to Firestore, and returns image URLs to the client.

## Backend Logic

-   **Cloud Function Implementation:**

    -   The main function is `Generate Remix Image`.
    -   It authenticates requests, receives the image and scene data, calls Gemini AI, uploads generated images to Storage, and writes a Firestore record.
    -   Example flow:
        1. Receive image and scenes from client.
        2. Call Gemini AI API to generate 4 images.
        3. Upload each image to `users/{uid}/generated/` in Firebase Storage.
        4. Save a Firestore document in `remixes` with user ID, original and generated image URLs, and timestamp.
        5. Return the generated image URLs to the client.

-   **Firebase Anonymous Auth Integration:**
    -   The app uses Firebase Anonymous Auth to create a unique user ID for each session.
    -   This user ID is used for organizing uploads and generated images in Storage, and for associating records in Firestore.
    -   Example:
        ```dart
        final userCredential = await _auth.signInAnonymously();
        final userId = userCredential.user?.uid;
        ```
    -   All uploads and generated images are stored under `users/{userId}/...`.

## Security Model

-   **No secrets in the client app.**
-   **AI requests are made only from the backend.**
    -   The client uploads the image; the backend handles AI and returns URLs.
-   **Storage and Firestore rules:**
    -   Images are stored under `users/{uid}/...`.
    -   Metadata is saved in the `remixes` collection.

## Firebase Usage

-   **Image Upload Example:**

    ```dart
    final Reference ref = _storage.ref().child('users/$userId/uploads/$fileName');
    // For generated images:
    final Reference ref = _storage.ref().child('users/$userId/generated/$fileName');
    ```

-   **Firestore Record Example:**
    ```dart
    await _firestore.collection('remixes').add({
      'userId': userId,
      'originalImageUrl': originalImageUrl,
      'generatedImageUrls': generatedImageUrls,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ```

## Features

-   Upload a portrait photo and select up to 4 scenes.
-   AI generates 4 photorealistic remixes.
-   Images are saved to Firebase Storage and metadata to Firestore.
-   Secure, user-specific storage and records.
