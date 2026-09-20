# Project Summary: Allonssy (local_social)

> **Context Document for AI Assistants (Gemini / Claude / ChatGPT)**  
> *Upload or paste this file directly to provide complete architecture, tech stack, codebase structure, and development context.*

---

## 1. Project Overview
- **App Name**: **Allonssy** (Internal package name: `local_social`, Android bundle: `com.allonssy.app`)
- **Core Concept**: Hyperlocal community social media, local marketplace, and service directory for neighborhoods and towns.
- **Platforms**: **Android** (Play Store: internal/production), **Web** (`https://app.allonssy.com`), and **iOS** (prepared).
- **Languages / Locale**: Bilingual — **French (`fr`)** (default for non-logged-in users) and **English (`en`)**. Driven by `profiles.app_language` and `lib/core/localization/app_locale_controller.dart`.
- **Operating Entity**: Tradister SAS (France).

---

## 2. Tech Stack & Infrastructure
- **Frontend Framework**: **Flutter 3.x** / **Dart SDK ^3.10.3**
- **State Management**: **Flutter Riverpod** (`flutter_riverpod: ^2.5.1`)
- **Navigation**: **GoRouter** (`go_router: ^14.2.0`) with persistent tabs (`StatefulShellRoute.indexedStack`)
- **Primary Backend**: **Self-hosted Supabase** on Ubuntu VPS (`87.106.13.170`)
  - PostgreSQL with Row Level Security (RLS) policies
  - PostgREST API (schema refreshed via `NOTIFY pgrst, 'reload schema';`)
  - Realtime subscriptions (chat, comments, notifications)
  - Storage buckets: `avatars`, `post-images`
  - Deno Edge Functions: `push-dispatch` for FCM HTTP v1 dispatch
- **Push Notifications**:
  - **Firebase Cloud Messaging (FCM HTTP v1)**
  - Web service worker (`firebase-messaging-sw.js`) + Android background handler
  - Automated triggers via PostgreSQL `pg_net` invoking `push-dispatch` Edge Function
- **Media & Native Hardware**:
  - Android camera and gallery use custom native **`MethodChannel`** (`com.local_social/camera`) in `MainActivity.kt` to prevent plugin crashes in R8 release builds.
  - Video processing: `ffmpeg_kit_flutter_new`, `video_player`, lazy tap-to-play thumbnail previews.
- **Web Hosting**: Hosted on VPS reverse-proxied by **Caddy** at `https://app.allonssy.com`.

---

## 3. Key Features & Modules
1. **Hyperlocal Social Feed (`lib/screens/feed_screen.dart`)**:
   - Filter scopes: **Radius (Local km)**, **Following**, **Trending**, and **Public**.
   - TikTok-style vertical mobile video feed (`lib/widgets/mobile_video_feed.dart`) with visibility detectors and tap-to-play.
   - Multiple post formats: standard text/photo/video, announcements, questions, food ads.
2. **Marketplace & Gigs/Services**:
   - Buy & sell products and services (`market`, `service_offer`, `service_request`).
   - Single price or price range (`EUR X – EUR Y`).
   - Item condition and availability status (`available`, `reserved`, `sold`).
   - Saved posts / bookmarks (`saved_posts` table).
3. **2-Tier Business & Professional Directory**:
   - 7 main categories and 26 subcategories for local artisans and service providers.
   - User favorite businesses list (`favorite_businesses` table).
4. **Real-time Chat & Offer System (`lib/features/chat/`)**:
   - 1-on-1 direct messaging with real-time Supabase subscriptions.
   - Dedicated offer negotiations screen (`offer_chat_screen.dart`) with counter-offers, accept/reject states.
   - Delivery read receipts (single tick = sent, teal double tick = read).
5. **Categorized Unified Search (`lib/screens/search_screen.dart`)**:
   - Quick category chips: **People / Profiles**, **Posts**, **Marketplace**, **Gigs**, and **Directory**.
6. **Moderation & Security**:
   - User reporting (`reports` table) and admin review panel (`lib/features/moderation/`).
   - `banned_emails` table with database triggers preventing re-registration.
7. **Feedback & Deep Linking**:
   - In-app bug reporting & rating sheet (`user_feedback` table, `lib/screens/feedback_screen.dart`).
   - Deep linking with Android App Links and iOS Universal Links (`.well-known` configuration).

---

## 4. Codebase Directory Map
```text
lib/
├── main.dart               # Startup entry point, custom auth storage, Supabase & push init
├── app/
│   ├── app.dart            # MaterialApp setup, themes, and global builders
│   ├── router.dart         # GoRouter definitions (IndexedStack for bottom navigation)
│   └── chat_singletons.dart# Singleton chat services
├── core/
│   ├── auth/               # Custom file-backed PKCE & auth storage (bypasses SharedPreferences on Android release)
│   ├── config/             # env.dart (Supabase credentials - untracked), firebase_web_config.dart
│   ├── localization/       # AppLocalizations and AppLocaleController (FR / EN)
│   └── utils/              # Formatting, device info, platform helpers
├── features/
│   ├── auth/               # Login, Register, Forgot/Reset Password
│   ├── chat/               # Chat screens, offer negotiation, attachment handling
│   ├── moderation/         # Admin report reviews & moderation actions
│   ├── notifications/      # Notification feed & user preference toggles
│   └── profile/            # Profile detail, edit profile, follow list, settings
├── screens/                # Feed, Create Post, Search, Marketplace, Gigs, Directory, Feedback
├── services/               # PostService, ReactionService, PushNotificationService, FeedbackService
└── widgets/                # PostCard, MobileVideoFeed, GlobalBottomNav, ShareButton, MainShell
supabase/
└── migrations/             # Timestamped SQL database migrations
scripts/
├── build_web.sh            # Injects Firebase web key, compiles Flutter web, deploys to VPS
└── critical_server_alert.py# VPS monitoring script
```

---

## 5. Main Database Tables (Supabase PostgreSQL)
- **`profiles`**: User metadata, handle, location coords, `app_language`, `business_type`, `business_subtype`.
- **`posts`**: Core content (`post_type`: `post`, `market`, `food_ad`, `service_offer`, `service_request`; pricing, `item_status`, `media_urls`, coordinates).
- **`conversations` & `messages`**: Real-time chat messages, attachment URLs, `read_at` timestamps.
- **`saved_posts`**: User bookmarks for marketplace and feed posts.
- **`favorite_businesses`**: Saved business profiles.
- **`user_feedback`**: Feedback rating, message, category (`bug`, `feature`, `general`), app version.
- **`device_push_tokens`**: FCM registration tokens per user/platform.
- **`banned_emails`**: Denylist preventing registration via `auth.users` triggers.

---

## 6. Development & Deployment Guidelines

### 🚨 Never Commit Secrets
The following files are `.gitignore`d and must **NEVER** be committed or exposed:
- `lib/core/config/env.dart` (Contains Supabase URL + anon key)
- `.env.local` (Contains `FIREBASE_WEB_API_KEY`)
- `android/app/google-services.json` (Android Firebase config)
- `ios/Runner/GoogleService-Info.plist` (iOS Firebase config)
- `web/firebase-messaging-sw.js` (Generated during web build)

### 🚀 Web Build & Deployment
Never run raw `flutter build web` directly — it will miss the injected FCM web key. Always run:
```bash
# Build and deploy directly to production VPS:
bash scripts/build_web.sh --deploy

# Build locally only:
bash scripts/build_web.sh
```

### 📱 Android Release Workarounds
- **Camera/Gallery**: Must use native `MethodChannel` (`com.local_social/camera`) in `MainActivity.kt`. Do not revert to `image_picker` plugin calls directly on Android.
- **ProGuard / R8**: Rules in `android/app/proguard-rules.pro` preserve `ffmpeg_kit_flutter_new`, `file_picker`, and native activity classes.
- **Auth Storage**: Android release uses custom file storage in `lib/core/auth/release_auth_storage.dart` due to a plugin channel initialization race with `shared_preferences`.

### 🧭 Navigation & Tab Rules
- The 4 main bottom nav tabs (**Feed, Search, Chat, Notifications**) use `StatefulShellRoute.indexedStack`.
- Switch tabs with `context.go('/...')`, **never** `context.push()`, to keep state alive.
- All detail screens (Post detail, profile, marketplace product) push onto the root navigator.
