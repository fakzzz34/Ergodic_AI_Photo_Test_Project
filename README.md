# Ergodic AI Photo Remix

## Setup Instructions

-   Configure Firebase: `flutterfire configure`
-   Install deps: `flutter pub get`
-   Set Gemini key (Functions): `firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY"`
-   Deploy: `firebase deploy --only functions,storage,firestore`
-   Run: `flutter run` or `flutter run --dart-define=GEMINI_API_KEY="YOUR_ACTUAL_API_KEY"`

## Architecture

-   Client: Flutter UI (`HomeScreen`) + services (`FunctionsService`, `StorageService`, `FirestoreService`)
-   Backend: Callable Cloud Function `generateRemixImages` generates 4 images, uploads to Storage, saves Firestore, returns URLs

## Security

-   No secrets in client; use Functions config
-   AI calls only via backend; client sends bytes, gets URLs
-   Owner‑only rules for Storage (`users/{uid}/...`) and Firestore (`remixes`)
