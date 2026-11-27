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

Or add `MAPS_API_KEY=...` to `android/local.properties` (not committed). CI reads the `MAPS_API_KEY` secret.

### Backend base URL

```bash
flutter run --dart-define=API_BASE=https://api.yourdomain.com
```

Default is `https://api.smartagro.connect` (placeholder). Point it to your REST gateway; keep mock JSON for demos.

## Payments (Paystack) — secure setup

Payments run through the Cloud Functions backend in `functions/`. **The Paystack
secret key is never put in the app** (it can be extracted from any APK).

- The app sends only the product id. The server prices the order from Firestore,
  starts the Paystack checkout, and confirms it with Paystack.
- A payment counts as paid only when Paystack confirms it **and** the amount and
  currency match. Underpayments are flagged `amount_mismatch`.
- `payments/` and `orders/` can only be written by the backend (see `firestore.rules`).
- The `paystackWebhook` function checks Paystack's HMAC signature, so payments
  complete even if the buyer never returns to the app.

Deploy once:

```bash
firebase functions:secrets:set PAYSTACK_SECRET_KEY
firebase deploy --only functions,firestore:rules,firestore:indexes
```

Then in the Paystack dashboard (Settings → API Keys & Webhooks) set the webhook
URL to `https://us-central1-<project-id>.cloudfunctions.net/paystackWebhook`.

Tests:

```bash
cd functions && npm ci && npm test        # payment logic
npm run test:rules                        # Firestore rules (needs Java 21 + firebase-tools)
```

## Running

```bash
flutter run
```

Demo credentials (offline demo mode when Firebase is not configured — dev and
staging builds only; production builds with `--dart-define=FLAVOR=prod` never
fall back to demo login):

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
