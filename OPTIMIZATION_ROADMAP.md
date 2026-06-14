# SmartAgro Connect — Optimization Roadmap
> MVP → Enterprise readiness reference. Update this document as items are completed.

---

## Current State (Baseline)

| Area | Status |
|---|---|
| Clean Architecture (domain / data / features) | Done |
| Riverpod DI + GoRouter navigation | Done |
| Material 3 theming (light / dark) | Done |
| Offline-first reads (SQLite + asset bundle fallback) | Done |
| Offline write queue (sync on reconnect) | Done |
| Role-based route guards (farmer / buyer / transporter / admin) | Done |
| Const widgets, skeleton loaders, CachedNetworkImage | Done |
| SQLite indexes + query ordering | Done (Jun 2026) |
| Search debouncing (350 ms) | Done (Jun 2026) |
| ValueKey on sliver list items | Done (Jun 2026) |
| Image memory-cache size hints | Done (Jun 2026) |
| Real authentication | Done (Jun 2026) — Firebase + demo fallback |
| SecureTokenStore (flutter_secure_storage) | Done (Jun 2026) |
| DioClient auth interceptor + 401 retry | Done (Jun 2026) |
| Push notifications (FCM) | Done (Jun 2026) — wire `flutterfire configure` to activate |
| Real REST API | **Stub only** |
| Crash reporting / analytics | **Missing** |
| CI/CD pipeline | **Missing** |
| Accessibility | **Partial** |
| Payment integration | **Missing** |

---

## 1. MVP Requirements (Ship-Blockers)

These must be resolved before any public release.

### 1.1 Authentication — replace demo stubs ✅

**Files:** `lib/data/repositories/auth_repository.dart`, `lib/core/di/auth_providers.dart`, `lib/main.dart`

- [x] Bootstrap Firebase in `main()` (best-effort — falls back to demo mode when not configured).
- [x] Replace `_loginDemo` / `_registerDemo` with `FirebaseAuth` paths (`_loginFirebase`, `_registerFirebase`).
- [x] Replace `googleSignIn` stub with `google_sign_in` + Firebase credential.
- [x] Replace `sendPasswordReset` stub with `FirebaseAuth.instance.sendPasswordResetEmail`.
- [x] Rename `verifyOtpDemo` → `verifyOtp` (wire to Firebase phone auth / Termii when ready).
- [x] Token management via `getIdToken()` — Firebase refreshes automatically; custom token via `SecureTokenStore`.
- [x] `AuthSessionNotifier` listens to `FirebaseAuth.instance.authStateChanges()` stream.
- [ ] **Remaining:** run `flutterfire configure` and replace `lib/firebase_options.dart` with real values + add `google-services.json`.

### 1.2 Push Notifications — wire FCM ✅

**File:** `lib/core/services/push_messaging_service.dart`

- [x] `requestPermission()` wired in `PushMessagingService.register()`.
- [x] `onMessage` (foreground), `onMessageOpenedApp` (background tap), `getInitialMessage()` (terminated) all handled.
- [x] FCM token exposed via `PushMessagingService.instance.fcmToken`.
- [x] `PushMessagingService.instance.register()` called inside `initializationProvider`.
- [ ] **Remaining:** POST `fcmToken` to your backend endpoint (`PUT /api/users/me/device-token`) after login.
- [ ] **Remaining:** Wire `onNotificationTap` callback in `app.dart` to navigate via GoRouter.

### 1.3 REST API Integration ✅ (partial)

**Files:** `lib/core/network/dio_client.dart`, `lib/data/datasources/remote_api_datasource.dart`

- [x] Auth interceptor injects `Authorization: Bearer <token>` on every request via `getToken` callback.
- [x] 401 interceptor force-refreshes the Firebase ID token and retries once before calling `onUnauthorized` → `logout()`.
- [x] Exponential-backoff retry via `dio_smart_retry` (3 retries: 1 s / 2 s / 4 s) on connection/timeout errors.
- [x] `DioClient` reads `API_BASE` from `AppEnv` — pass `--dart-define=API_BASE=https://api.yourdomain.com` at build time.
- [ ] **Remaining:** Replace asset-bundle mock endpoints in `RemoteApiDataSource` with real API calls once backend is ready.

### 1.4 Form Validation ✅

**Files:** `lib/features/auth/login_screen.dart`, `register_screen.dart`, `add_product_screen.dart`, `forgot_password_screen.dart`

- [x] All form screens wrapped in `Form` with `GlobalKey<FormState>`.
- [x] `validator` callbacks: non-empty, email format, password ≥ 6 chars, price/quantity numeric checks, category + state required.
- [x] Double-submit prevention: buttons disabled while `_busy == true`.
- [x] Inline field errors shown beneath each field via Material `TextFormField` validator.

### 1.5 Image Upload (Add Product) ✅

**Files:** `lib/data/services/image_upload_service.dart`, `lib/core/di/upload_providers.dart`, `lib/features/marketplace/add_product_screen.dart`

- [x] `ImageUploadService` created: Firebase Storage path (`product_images/{uid}/{productId}.jpg`) for production; simulated 1.5 s progress for demo mode.
- [x] `imageUploadServiceProvider` wired via Riverpod.
- [x] Upload fires automatically when image is picked — user fills form while upload runs in parallel.
- [x] Live `LinearProgressIndicator` with percentage shown below the image picker card during upload.
- [x] "Image uploaded successfully" green confirmation row replaces the bar on completion.
- [x] Submit button label → "Uploading image…" and is disabled while upload is in progress.
- [x] `_uploadedImageUrl` stored; passed to submission payload (TODO: include in real API call).
- [ ] **Remaining:** Add `flutter_image_compress` for ≤ 500 KB JPEG compression before upload (production Android/iOS).

### 1.6 Error & Loading States — consistency pass

- [ ] All `async.when` data blocks must handle empty lists (not just the error branch).
- [ ] Replace the bare `Text('Error: $e')` in `commodity_market_screen.dart` with the shared styled error + retry card already used in `marketplace_screen.dart`.
- [ ] Add a network connectivity banner at the top of data-heavy screens (a `ConnectivityBuilder` that watches `connectivityWatcherProvider`) so users know they are in offline mode.

---

## 2. Enterprise Requirements

### 2.1 App Flavors (dev / staging / prod)

**Files:** `android/app/build.gradle`, `lib/core/config/app_env.dart`

- [ ] Create three Flutter flavors: `dev`, `staging`, `prod`.
- [ ] Each flavor gets its own `AppEnv`: API base URL, Firebase project, Maps key, log level.
- [ ] Dev and staging flavors show a colored environment ribbon in the app (a debug banner overlay).
- [ ] Never commit prod credentials; load them from CI secrets at build time.

### 2.2 Crash Reporting & Observability ✅ (partial)

- [x] `firebase_crashlytics ^4.1.0` + `firebase_analytics ^11.3.0` added to `pubspec.yaml`.
- [x] `main()` wrapped in `runZonedGuarded`; `FlutterError.onError` → `recordFlutterFatalError`; `PlatformDispatcher.instance.onError` captures Dart async errors.
- [x] Crash collection disabled in debug builds (`setCrashlyticsCollectionEnabled(!kDebugMode)`).
- [x] `AnalyticsService` (`lib/core/services/analytics_service.dart`) — no-op in demo mode; `logLogin`, `logSignUp`, `logScreenView`, `logProductView`, `logAddListing`, `logSearch`, `logCommodityView`.
- [x] `FirebaseAnalyticsObserver` wired into GoRouter via `analyticsServiceProvider`.
- [ ] **Remaining:** Add structured logging with `logger` package — replace raw `debugPrint` calls, set log level per flavor.
- [ ] **Remaining:** Add Dio response-time interceptor so slow API calls surface in analytics.

### 2.3 Security Hardening

- [ ] **Certificate pinning**: add `dio_certificate_pinner` (or native TrustKit) for prod builds to prevent MITM attacks on rural networks with untrusted proxies.
- [ ] **Root / jailbreak detection**: use `flutter_jailbreak_detection` and warn users on rooted devices (especially important for payment flows).
- [ ] **Obfuscation**: build release APK with `--obfuscate --split-debug-info=build/debug-info` to protect intellectual property.
- [ ] **Secure SharedPreferences**: move sensitive flags out of `SharedPreferences` into `SecureTokenStore` (flutter_secure_storage). Current code stores the user JSON in plain SharedPrefs.
- [ ] **SQL injection safety**: already safe (sqflite parameterized queries) — add a code review checklist item to keep it that way.
- [ ] **API key hygiene**: Maps API key, Firebase options, and backend base URL must come from dart-defines, never hardcoded strings.

### 2.4 Role-Based Access Control — full enforcement

**File:** `lib/core/router/app_router.dart`

- [ ] Move the role check out of the router redirect (UI-only) into a server-side middleware — the router guard is UX, not security.
- [ ] Add a `PermissionService` that any screen can call to check fine-grained capabilities (`canCreateListing`, `canViewAdminPanel`, `canApproveSellers`) independently of `UserRole`.
- [ ] Render disabled states (greyed-out buttons, locked cards) rather than hard-redirecting when a user is close to a permission boundary — better UX and less disorienting.

### 2.5 Admin Dashboard — feature-complete

**Files:** `lib/features/admin/`

All five admin screens are currently stubs. Wire them:

- [ ] **AdminHomeScreen**: real KPI tiles (DAU, GMV, active listings, pending disputes) from admin API endpoints.
- [ ] **AdminUsersScreen**: paginated user list, search, ability to suspend/verify/change role.
- [ ] **AdminModerationScreen**: pending listing queue, approve / reject with a reason, flag as spam.
- [ ] **AdminCommoditiesScreen**: CRUD for commodity prices (admin sets the benchmark price for the market board).
- [ ] **AdminAnalyticsScreen**: integrate a chart library (`fl_chart` already used) to show retention, GMV trend, top commodities.

### 2.6 Offline-First — complete the write queue

**File:** `lib/data/services/queue_sync_service.dart`

- [ ] Implement the actual `QueueSyncService.start()` and `stop()` methods (currently stubs) — listen to `connectivityWatcherProvider` and flush pending writes when the network is restored.
- [ ] Implement conflict resolution: if a queued product listing was deleted on the server while offline, surface the conflict to the user rather than silently failing.
- [ ] Add a visual "Pending sync" badge on listings that are queued but not yet synced.
- [ ] Cap the retry count at 5 (already in the schema); after that surface a "sync failed" notification.

### 2.7 Payments

- [ ] Integrate **Paystack** (preferred for Nigeria) via `paystack_flutter` or the Paystack inline charge endpoint through Dio.
- [ ] Or integrate **Flutterwave** for multi-currency support (NG, GH, KE markets).
- [ ] Never process card details in the app — always use hosted payment pages / SDKs.
- [ ] Store transaction references (not card details) in the write queue so interrupted payments can be reconciled.

### 2.8 Deep Linking & App Links

- [ ] Configure Android App Links (`assetlinks.json`) and iOS Universal Links for the production domain.
- [ ] Map product URLs (`https://smartagro.ng/product/:id`) directly to `GoRouter`'s `/marketplace/product/:id` route so shared product links open the app.
- [ ] Add dynamic links (Firebase Dynamic Links or Branch.io) to track referral sources (farmer sharing a listing with a buyer).

### 2.9 CI/CD Pipeline

- [ ] Use **GitHub Actions** (or Codemagic for Flutter-native support).
- [ ] Pipeline stages: `flutter analyze` → `flutter test` → `build apk --release` (dev) → optional `build appbundle --release` (prod on main branch merge).
- [ ] Sign releases in CI using a keystore stored as a GitHub secret — never commit `key.jks`.
- [ ] Auto-upload to Firebase App Distribution (internal QA) on every merge to `develop`; manual promotion to Google Play for production.

---

## 3. UI / UX Design Optimizations

### 3.1 Hero Transitions ✅

- [x] Product images wrapped with `Hero(tag: 'product-image-${product.id}')` in `marketplace_screen.dart` → `product_detail_screen.dart` (SliverAppBar FlexibleSpaceBar image).
- [x] Commodity icon bubble wrapped with `Hero(tag: 'commodity-icon-${c.id}')` in `commodity_market_screen.dart` → matching bubble added to `_HeroPriceCard` in `commodity_detail_screen.dart`.

### 3.2 Haptic Feedback ✅ (partial)

- [x] `HapticFeedback.mediumImpact()` on Publish Listing submit (`add_product_screen.dart`).
- [x] `HapticFeedback.selectionClick()` on category chip tap in `marketplace_screen.dart` and `commodity_market_screen.dart`.
- [ ] **Remaining:** `HapticFeedback.mediumImpact()` on pull-to-refresh completion and Confirm Payment CTA.

### 3.3 Micro-interactions

- [ ] **Bottom Nav**: animate the selected tab icon with a slight vertical bounce (`flutter_animate` `.scale()`) — 150 ms, `Curves.easeOutBack`.
- [ ] **Favourite button**: heart icon with a scale pop + colour fill animation.
- [ ] **Price change badges**: animate the ± percentage with a count-up using `AnimatedSwitcher` so users notice market moves.
- [ ] **Chat send button**: morph from `send` icon to a checkmark and back for sent confirmation.

### 3.4 Empty States — illustrated

- [ ] Replace the current icon-only `EmptyState` widget with illustrated SVGs (`flutter_svg`). Use agricultural illustrations (free at undraw.co — "no data", "farming", "delivery").
- [ ] Each empty state must have a contextual CTA: Marketplace empty → "List your first product"; Buyers empty → "Invite a buyer"; Chat empty → "Start a conversation".

### 3.5 Onboarding — visual polish

**File:** `lib/features/onboarding/onboarding_screen.dart`

- [ ] Replace plain card slides with full-bleed illustrated pages using `PageView` + a `SmoothPageIndicator`.
- [ ] Add a parallax effect between the illustration and the text layer on page swipe.
- [ ] Add a "Skip" button in the top-right corner that jumps to the login screen.
- [ ] The last page should have a prominent CTA ("Get Started") rather than an auto-advance.

### 3.6 Dashboard — widget personalization

**File:** `lib/features/home/dashboard_screen.dart`

- [ ] Show role-relevant sections only: farmers see "My Listings" and "Commodity Prices"; buyers see "Nearby Farmers" and "Recent Orders"; transporters see "Active Jobs" and "Map".
- [ ] Add a "Quick Actions" row (2–4 icon buttons) below the greeting card — role-specific shortcuts.
- [ ] Add a persistent offline banner at the top when connectivity is lost (amber strip, not a modal).

### 3.7 Marketplace — UX refinements

**File:** `lib/features/marketplace/marketplace_screen.dart`

- [ ] Add a **horizontal scroll for featured / promoted listings** above the grid (a "Spotlight" strip).
- [ ] Show a **price trend chip** on each product card (e.g., "↑ 12% this week") derived from commodity data.
- [ ] Add a **"Verified seller" badge** (blue tick) on cards where `product.verified == true`.
- [ ] Persist the last-selected category and sort in `SharedPreferences` so the user's preference survives restarts.

### 3.8 Chat — functional completeness

**File:** `lib/features/chat/chat_room_screen.dart`

- [ ] Wire to a real-time backend: Firebase Firestore or a WebSocket (socket_io_client).
- [ ] Show typing indicators.
- [ ] Show read receipts (single tick = sent, double tick = delivered, blue ticks = read).
- [ ] Support image attachments: open image picker → upload to storage → send the URL as a message.
- [ ] Add push notification for new messages (via FCM topic per thread).

### 3.9 Accessibility

- [ ] Audit every interactive widget for `Semantics` labels — screen-reader users need meaningful descriptions on icon-only buttons.
- [ ] Ensure all text satisfies **WCAG AA contrast** (4.5:1 for body, 3:1 for large text) — especially the `AppColors.gray` on `AppColors.surfaceLight` combination.
- [ ] Support **dynamic text scaling**: replace fixed `fontSize` values with `sp` units using `flutter_screenutil` or respect `MediaQuery.textScaleFactor` constraints (`maxLines` clamps, not overflow).
- [ ] Add `excludeFromSemantics: true` on purely decorative icons.
- [ ] Test with TalkBack (Android) before each release.

### 3.10 Responsive Layout (Tablet / Foldable)

- [ ] Use `LayoutBuilder` breakpoints: < 600 dp → phone layout (current); ≥ 600 dp → two-column layout (master–detail for marketplace and market screens).
- [ ] On tablets, the bottom nav should become a `NavigationRail` on the left side.
- [ ] The dashboard stat cards should switch from a 2-col grid to a 4-col grid on wide screens.

---

## 4. Performance Optimizations (Beyond Current Work)

### 4.1 Image Pipeline

- [ ] Configure a shared `CacheManager` (from `flutter_cache_manager`) with a 7-day max age and 200 MB disk cap — pass it to every `CachedNetworkImage` so all screens share one persistent disk cache.
- [ ] Use WebP format from the backend/CDN for 25–35% smaller payloads over JPEG.
- [ ] Add `placeholderFadeInDuration: Duration(milliseconds: 150)` for a smoother fade from shimmer to image.

### 4.2 List Virtualization

- [ ] The `search_screen.dart` "All" tab uses a plain `ListView` with `shrinkWrap: true` inside a scrollable — this defeats virtualization and lays out all children eagerly. Replace with a `CustomScrollView` containing `SliverList` sections.
- [ ] For the chat message list, use `ListView.builder` with `reverse: true` and scroll to bottom on mount to avoid measuring the full message history.

### 4.3 Provider Selectivity

- [ ] In widgets that only need one field from a large state object, use `ref.watch(provider.select((s) => s.field))` instead of watching the whole provider — prevents unnecessary rebuilds when unrelated fields change.
- [ ] Split `productsProvider` into a `rawProductsProvider` (cached list) and a `filteredProductsProvider(FilterParams)` family so the filter logic runs in a provider (background isolate-friendly) rather than in the widget's `build`.

### 4.4 Isolate Offloading

- [ ] JSON decoding in `AppDatabase.readProducts()` / `readCommodities()` runs on the main thread. For lists > 50 items, move the decode loop into a `compute()` call to avoid jank during cold-start.

### 4.5 App Bundle Size

- [ ] Enable R8 / ProGuard: add `minifyEnabled true` and `shrinkResources true` in the release build config.
- [ ] Run `flutter build appbundle --analyze-size` and trim unused packages from `pubspec.yaml`.
- [ ] Split ABI: generate separate APKs for `arm64-v8a` and `armeabi-v7a` — 30–40% smaller per-device download.

---

## 5. DevOps & Release Checklist

| Item | Done? |
|---|---|
| Release keystore generated and stored in password manager | |
| `signingConfig signingConfigs.release` in `build.gradle` (replace `debug`) | |
| `minifyEnabled true` + ProGuard rules | |
| `--obfuscate --split-debug-info` flags in release build script | |
| Google Play service account + Fastlane / Codemagic supply set up | |
| Firebase App Distribution for internal QA | |
| `flutterfire configure` run for prod Firebase project | |
| SHA-1 and SHA-256 fingerprints added to Firebase console (for Google Sign-In) | |
| Maps API key restricted to release package + certificate in GCP console | |
| Backend CORS allows only app domain + Firebase Auth domains | |
| Privacy policy URL wired into Play Store listing | |
| Target API level ≥ 35 (required by Google Play from August 2025) | |

---

## 6. Priority Matrix

| # | Item | Impact | Effort | Phase |
|---|---|---|---|---|
| 1 | Firebase auth wired (login/register/logout) | Critical | Medium | MVP |
| 2 | FCM push notifications | Critical | Low | MVP |
| 3 | DioClient auth interceptor + token refresh | Critical | Low | MVP |
| 4 | QueueSyncService fully implemented | High | Medium | MVP |
| 5 | Form validation on all inputs | High | Low | MVP |
| 6 | Image upload in Add Product | High | Medium | MVP |
| 7 | Hero transitions (product + commodity) | High | Low | UI |
| 8 | Role-specific dashboard sections | High | Low | UI |
| 9 | Illustrated empty states | Medium | Medium | UI |
| 10 | Paystack payment integration | High | High | Enterprise |
| 11 | App flavors (dev / staging / prod) | High | Medium | Enterprise |
| 12 | Crashlytics + Analytics | High | Low | Enterprise |
| 13 | Certificate pinning | Medium | Low | Enterprise |
| 14 | CI/CD pipeline (GitHub Actions) | High | Medium | Enterprise |
| 15 | Admin screens — feature-complete | Medium | High | Enterprise |
| 16 | Accessibility audit (TalkBack) | Medium | Medium | Enterprise |
| 17 | Tablet / responsive layout | Low | High | Enterprise |
| 18 | Compute-offloaded JSON decode | Medium | Low | Perf |
| 19 | Shared CacheManager for images | Medium | Low | Perf |
| 20 | Search provider family (filter off UI thread) | Medium | Medium | Perf |

---

## 7. Key Dependencies to Add

```yaml
# Authentication
firebase_core: ^3.x
firebase_auth: ^5.x
google_sign_in: ^6.x

# Notifications
firebase_messaging: ^15.x
flutter_local_notifications: ^18.x

# Crash + Analytics
firebase_crashlytics: ^4.x
firebase_analytics: ^11.x

# Payments
flutter_paystack: ^1.x           # or flutterwave_sdk

# Image
flutter_image_compress: ^2.x
flutter_svg: ^2.x               # for illustrated empty states

# Networking
dio_smart_retry: ^6.x           # exponential backoff

# Performance
flutter_screenutil: ^5.x        # responsive sp/dp
smooth_page_indicator: ^1.x     # onboarding dots

# Security
flutter_jailbreak_detection: ^2.x

# Logging
logger: ^2.x
```

---

> **Last updated:** 2026-06-12  
> **Updated by:** Claude Code optimization session  
> Tick completed items and add a date — this document is the single source of truth for the engineering backlog.
