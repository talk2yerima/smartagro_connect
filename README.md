# SmartAgro Connect

SmartAgro Connect is a **production-grade Flutter** template for an African agricultural marketplace connecting farmers, buyers, transporters, and agro dealers. It ships with **clean architecture**, **Riverpod**, **GoRouter**, **Dio**, **SQLite caching**, **Firebase-ready auth & messaging**, **Google Maps**, and a **premium UI** tuned for low-end Android devices and intermittent connectivity.

## Highlights

- **Offline-first reads**: bundled JSON fixtures + `sqflite` cache with automatic fallback when REST is unavailable.
- **Auth**: email/password, OTP UI, Google sign-in hooks, `flutter_secure_storage` for tokens, session hydration from `SharedPreferences`.
- **Market intelligence**: commodity board, detail charts (mock rhythm), editorial “trends” feed.
- **Marketplace**: listings, detail, farmer upload form (image picker), search & filter chips.
- **Chat**: thread list, conversation UI, attachment + voice-note affordances (wire to your realtime backend).
- **Maps**: `GoogleMap` centered on Lagos with sample marker (add your Maps SDK key).
- **Theming**: light/dark/system, Poppins + Inter via `google_fonts`, agricultural palette.
- **Admin module**: routed console stubs ready to bind to admin APIs.

## Architecture

```
lib/
  app.dart                 # MaterialApp.router + localization
  main.dart                # Firebase bootstrap (best-effort)
  firebase_options.dart    # Replace via flutterfire configure
  core/                    # theme, router, network, DI, services, utils
  data/                    # SQLite, datasources, repositories, mappers
  domain/                  # entities (pure models)
  features/                # UI grouped by feature (presentation layer)
  shared/widgets/          # reusable UI primitives
assets/mock/               # sample JSON “API” payloads
```

**Flow**: UI (features) → Riverpod providers → repositories → remote (Dio) / assets / SQLite. Repositories map JSON to domain entities and keep the cache warm for rural/slow links.

## Prerequisites

- Flutter **stable** (Dart **3.5+**)
- Android SDK + JDK **17**
- (Optional) Firebase project for Auth/FCM
- (Optional) Google Maps SDK key

## Setup

```bash
cd smartagro_connect
flutter pub get
```

If Android Gradle wrapper files are missing in your environment, regenerate scaffolding:

```bash
flutter create . --project-name smartagro_connect
```

### Firebase + FCM

1. Install [FlutterFire CLI](https://firebase.flutter.dev).
2. Run `flutterfire configure` and replace `lib/firebase_options.dart` + `android/app/google-services.json`.
3. Enable Email/Password + Google providers in Firebase console.
4. Add SHA-1/256 for Google Sign-In.

### Google Maps

Set `MAPS_API_KEY` when building:

```bash
flutter build apk --dart-define=MAPS_API_KEY=YOUR_KEY
```

Or add `MAPS_API_KEY=...` to `android/gradle.properties`.

### Backend base URL

```bash
flutter run --dart-define=API_BASE=https://api.yourdomain.com
```

Default is `https://api.smartagro.connect` (placeholder). Point it to your REST gateway; keep mock JSON for demos.

## Running

```bash
flutter run
```

Demo credentials (offline demo mode when Firebase is not configured):

- Email: `farmer@demo.ng`
- Password: any **6+** characters

## Building a release APK / App Bundle

```bash
flutter build apk --release
flutter build appbundle --release
```

For Play signing, configure a release keystore (replace temporary `signingConfig signingConfigs.debug` in `android/app/build.gradle`).

## Creating a ZIP of the source tree

### Windows (PowerShell)

```powershell
Compress-Archive -Path .\smartagro_connect\* -DestinationPath .\SmartAgroConnect-src.zip -Force
```

### macOS / Linux

```bash
zip -r SmartAgroConnect-src.zip smartagro_connect
```

## Troubleshooting

### Android Gradle wrapper missing

If `android/gradlew` (or wrapper JARs) are missing, regenerate Android scaffolding:

```bash
flutter create . --project-name smartagro_connect
```

Then re-check `AndroidManifest.xml` placeholders (Maps key) and Firebase config files.

## Performance notes

- Images use `cached_network_image` where applicable.
- Lists use skeleton + shimmer placeholders.
- SQLite stores last-known commodity/product payloads for instant cold start.

## License

Proprietary template — adapt for your product and attach your preferred license before publishing.
