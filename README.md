<div align="center">
  <img src="web/icons/Icon-192.png" alt="Ergodic AI Photo Remix logo" width="96" height="96" />
  <h1>Ergodic AI Photo Remix</h1>
  <p><strong>A Flutter photo remix prototype that turns one portrait into four AI-generated lifestyle and travel scenes using Firebase AI, Firebase Storage, and Firestore.</strong></p>
  <p>
    <a href="#-project-pitch">Project Pitch</a>
    ·
    <a href="#-features">Features</a>
    ·
    <a href="#-architecture--tech-stack">Architecture</a>
    ·
    <a href="#-getting-started">Getting Started</a>
  </p>
</div>

[![Contributors][contributors-shield]][contributors-url]
[![Stars][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![Flutter][flutter-shield]][flutter-url]
[![Standard Readme Style][readme-shield]][readme-url]

## 🎯 Project Pitch

Ergodic AI Photo Remix is a mobile-first Flutter application for generating scene-based portrait variations from a single uploaded photo. The app is designed to let a user pick one portrait, choose or customize a small set of target scenes, and receive four AI-generated remix results that preserve the subject while changing the setting and mood.

The current implementation signs users in anonymously with Firebase Auth, uploads the original image to Firebase Storage, generates remixed images through `firebase_ai`, stores generated outputs back in Firebase Storage, and saves remix metadata in Firestore. This repository is best understood as a polished prototype or coding-test submission rather than a fully productized public app, so the README reflects current realities and known limitations instead of aspirational architecture. The repository currently includes an app icon for branding, but no dedicated screenshots or demo GIFs are checked in yet, so this README intentionally omits a visual preview gallery.

## 🔗 Quick Links

- [Features](#-features)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [Getting Started](#-getting-started)
- [Configuration Notes](#-configuration-notes)
- [Recommended Development Commands](#-recommended-development-commands)
- [Usage Examples](#-usage-examples)
- [Roadmap](#-roadmap)
- [License](#-license)

## ✨ Features

- Upload a portrait from the camera or photo library.
- Select up to four remix scenes from a curated list of travel and lifestyle presets.
- Add one custom scene prompt when you want a more specific destination or mood.
- Generate four photorealistic remixes from the same source portrait with Firebase AI.
- Save the original upload and generated outputs to Firebase Storage under a user-scoped path.
- Persist remix metadata to Firestore for anonymous, session-based users.
- Save generated images to the device gallery after a successful run.
- Fall back to mock image URLs when generation fails, which helps keep the UI flow testable during development.

## 🏗️ Architecture & Tech Stack

<p align="left">
  <img src="https://skillicons.dev/icons?i=flutter,dart,firebase" alt="Flutter, Dart, Firebase" />
</p>

**Core stack**

- Flutter with Material 3 styling and `google_fonts` for the app shell and UI.
- Dart SDK `^3.9.2`.
- Firebase Core, Auth, Storage, and Cloud Firestore for app services and persistence.
- `firebase_ai` with Gemini image generation for scene remixing.
- `image_picker`, `flutter_image_compress`, and `gallery_saver_plus` for media handling.

**Runtime flow**

1. The app initializes Firebase in `main.dart`.
2. `AuthService` signs the user in anonymously.
3. `HomeScreen` collects the source image and chosen scenes.
4. `FunctionsService` compresses the image, uploads the original, generates remixed images, uploads the results, and writes a Firestore record.
5. The UI presents the returned image URLs and optionally saves them to the local gallery.

**Repository structure**

```text
lib/
  main.dart
  firebase_options.dart
  screens/
    home_screen.dart
  services/
    auth_service.dart
    functions_service.dart
    storage_service.dart
    firestore_service.dart
test/
  widget_test.dart
firebase.json
firestore.rules
storage.rules
```

**Important implementation notes**

- The checked-in implementation generates images from the Flutter client through `firebase_ai`; there is no `functions/` directory in the repository at the moment.
- `firebase.json` still contains Firebase Functions predeploy scaffolding, so backend deployment instructions must be treated carefully until the missing backend files exist.
- `firebase_options.dart` is currently configured only for Android. Web, iOS, macOS, Linux, and Windows will throw `UnsupportedError` until FlutterFire is configured for those platforms.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK compatible with Dart `^3.9.2`.
- A Firebase project with Authentication, Firestore, and Storage enabled.
- FlutterFire CLI installed if you want to connect this app to your own Firebase project.
- An Android target device or emulator for the smoothest out-of-the-box run, because Android is the only committed FlutterFire configuration right now.

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Firebase for your project

If you are using your own Firebase project, regenerate `lib/firebase_options.dart` and platform config files:

```bash
flutterfire configure
```

### 3. Review Firebase platform files

- Android already includes `android/app/google-services.json`.
- Non-Android platforms need their own FlutterFire setup before they can run successfully.

### 4. Start the app

```bash
flutter run -d android
```

If you target a different platform before re-running FlutterFire configuration, the app will show a Firebase initialization error screen.

## 🔧 Configuration Notes

- `lib/firebase_options.dart` currently points to the Firebase project `ergodic-ai-photo-test-project`.
- `lib/api_key.dart` contains a placeholder `GEMINI_API_KEY`, but the checked-in generation flow uses `firebase_ai` rather than reading that file directly.
- Firestore rules currently allow any authenticated user to read and write all documents.
- Storage rules currently allow any authenticated user to read and write all paths in the bucket.
- The app uses Firebase Anonymous Auth, so each session receives a unique user ID for namespacing uploads and generated images under `users/{uid}/...`.
- `firebase.json` references Functions and Firestore indexes files that are not fully present in the repository. Avoid copying old deploy commands blindly.

## 🛠️ Recommended Development Commands

Install packages:

```bash
flutter pub get
```

Analyze the codebase:

```bash
flutter analyze
```

Run widget tests:

```bash
flutter test
```

Launch on Android:

```bash
flutter run -d android
```

Regenerate Firebase configuration:

```bash
flutterfire configure
```

Check outdated packages:

```bash
flutter pub outdated
```

## 📸 Usage Examples

### Basic flow

1. Open the app and pick a portrait from the camera or gallery.
2. Select up to four preset scenes such as beach, rooftop skyline, forest trail, or cafe.
3. Optionally replace one slot with a custom text scene.
4. Tap the generate action and wait for compression, upload, AI generation, and persistence to complete.
5. Review the four generated remixes and save the ones you want to your device gallery.

### What gets stored

- Original uploads are stored in Firebase Storage under a user-scoped upload path.
- Generated outputs are stored in Firebase Storage under a user-scoped generated path.
- Firestore stores a remix document containing the anonymous user ID, the original image URL, generated image URLs, and a timestamp.

## 🗺️ Roadmap

- Add platform-complete FlutterFire configuration for iOS, web, macOS, Windows, and Linux.
- Decide whether generation should stay client-driven through Firebase AI or move to a dedicated backend service.
- Tighten Firestore and Storage security rules from broad authenticated access to path-aware ownership rules.
- Replace the default Flutter sample widget test with tests that reflect the actual photo remix workflow.
- Add real screenshots or a short demo GIF once the UI flow is stable enough for publish-ready documentation.
- Add explicit environment and deployment documentation once the backend story is finalized.
- Add a real public repository URL and release process if the project is published externally.

## 📄 License

- No `LICENSE` file is currently included in this repository.
- Until a license is added, you should assume the project is not licensed for public reuse.
- Badge links at the bottom use placeholder GitHub repository metadata and should be updated if this project gets a public remote.

## 🙏 Acknowledgments

- [Flutter][flutter-url] for the cross-platform app framework.
- [Firebase][firebase-url] for authentication, storage, database, and AI integration tooling.
- [Gemini][gemini-url] for image generation capabilities exposed through Firebase AI.
- [Best README Template][best-readme-url], [standard-readme][readme-url], and [Make a README][make-a-readme-url] for documentation structure inspiration.

[contributors-shield]: https://img.shields.io/github/contributors/github_username/repo_name.svg?style=for-the-badge
[contributors-url]: https://github.com/github_username/repo_name/graphs/contributors
[stars-shield]: https://img.shields.io/github/stars/github_username/repo_name.svg?style=for-the-badge
[stars-url]: https://github.com/github_username/repo_name/stargazers
[issues-shield]: https://img.shields.io/github/issues/github_username/repo_name.svg?style=for-the-badge
[issues-url]: https://github.com/github_username/repo_name/issues
[flutter-shield]: https://img.shields.io/badge/Flutter-Dart%203.9%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white
[flutter-url]: https://flutter.dev/
[readme-shield]: https://img.shields.io/badge/README%20style-standard--readme-1abc9c?style=for-the-badge
[readme-url]: https://github.com/RichardLitt/standard-readme
[firebase-url]: https://firebase.google.com/
[gemini-url]: https://ai.google.dev/gemini-api/docs
[best-readme-url]: https://github.com/othneildrew/Best-README-Template
[make-a-readme-url]: https://www.makeareadme.com/
