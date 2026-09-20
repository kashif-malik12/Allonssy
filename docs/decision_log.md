# Decision Log & Project Memory

This file is the single source of truth for all project decisions, technical context, and memory across sessions.
Update this file after every significant change — do not wait to be asked.

---

## Project Summary

Flutter social media app for local communities. Supabase backend. Originally built with Codex CLI, migrated to Claude Code on 2026-03-11.
- Tech: Flutter + Riverpod + GoRouter + Supabase. Dart SDK ^3.10.3
- Secrets: `lib/core/config/env.dart` — never commit
- Routes: `lib/app/router.dart`
- Main feed: `lib/screens/feed_screen.dart` (~3471 lines — careful with bulk edits)

---

## Navigation Architecture

- Feed, Search, Chat, Notifications are persistent tabs via `StatefulShellRoute.indexedStack` in `router.dart`.
- Shell widget: `lib/widgets/main_shell.dart` (transparent passthrough — each screen keeps its own Scaffold + GlobalBottomNav).
- Tab switching uses `context.go()` — NOT `context.push()` — for these four routes.
- All other screens (post detail, marketplace, profile, etc.) push on root navigator as before.
- This keeps all four tabs alive in an IndexedStack — switching is instant, state is preserved.

---

## UI Decisions

- The app-side product branding is now `Allonssy` across in-app titles, auth screens, location dialogs, web metadata, and platform display metadata. Package IDs, bundle IDs, namespaces, and native method channel identifiers remain unchanged for stability.
- The mobile video feed scope controls (`Following`, `Radius`, `Public`, `Trending`) belong at the bottom of the video card, not as a top overlay.
- When the mobile video feed has no items, the user must still be able to switch filters from the empty state.
- The mobile video feed should render fast: load the active card first, use lightweight posters for off-screen cards, and avoid blocking first paint on per-post enrichment.
- New uploaded video posts should store a real thumbnail poster in `image_url` so the video feed can render instantly before playback starts.

---

## Notification Settings

- App preferences are stored in `auth.users.raw_user_meta_data.app_settings`.
- `video_autoplay` remains part of `app_settings`.
- In-app notification preferences are also stored in `app_settings`.
- Push notification preferences are stored in `app_settings` for future FCM/web push work, even though push delivery is not connected yet.
- Notification inserts must respect recipient settings centrally in the database, not only in Flutter UI.
- App UI language is stored in `profiles.app_language` with allowed values `en` and `fr`.
- The app locale is now driven at startup and after profile saves by `lib/core/localization/app_locale_controller.dart`, so Flutter mobile and Flutter web switch language from the same profile-backed preference.
- The language selector lives in `lib/features/profile/presentation/complete_profile_screen.dart` and must remain available in both complete-profile and edit-profile flows.
- Logged-out/auth screens default to French via `app_locale_controller.dart`; signed-in users still use their saved profile preference.
- Current translated surfaces include the shared navigation/app bar, complete/edit profile, profile settings, main profile detail actions/portfolio UI, auth screens, notifications, create-post, and quick-camera-post flows. User-generated post/comment content must remain in its original language and is not translated by the app.

---

## Release APK Workarounds

- Android release builds hit a `shared_preferences` plugin channel failure during `Supabase.initialize()`.
- Current workaround in `lib/main.dart` avoids `shared_preferences` during Android release startup by using file-backed auth storage and PKCE storage.
- If this workaround is removed later, verify release APK startup and session persistence before shipping.

---

## Media Flow Decisions

- Quick camera on Android uses the app's own native `MethodChannel` flow in `MainActivity.kt`, not `image_picker`, because the plugin path hit unstable Android `pigeon`/channel failures in this project.
- Android quick video capture must request both `CAMERA` and `RECORD_AUDIO` permissions before launch.
- Android quick video capture must tolerate both return styles from camera apps: file output via `EXTRA_OUTPUT` and fallback `content://` URI results.
- Local video preview in post composers uses a tap-to-play approach: show the FFmpeg-generated thumbnail first, then lazily initialize `VideoPlayerController.file()` only when the user taps the play button. Eager initialization caused freezes/crashes on some Android devices, but lazy init on tap is stable.
- Video uploads should still generate and store a real thumbnail poster in `image_url`; the thumbnail-first composer preview is only a local UI stability decision.
- Android gallery selection in the full create-post screen uses the native `MethodChannel` bridge for images/videos instead of the broken plugin path used earlier.
- Avatar selection in the profile screen should use `image_picker` on Android/iOS and keep `file_picker` only as a desktop/web fallback; the generic picker path was unstable on mobile while post/media selection already had mobile-specific handling.
- Storage object paths must keep the authenticated user ID as the first folder segment for buckets protected by `storage.foldername(name)[1] = auth.uid()::text`. Chat attachments in `post-images` therefore live under `<userId>/chat_attachments/...`, not `chat_attachments/<userId>/...`.

---

## Android Release Build (R8/ProGuard)

- Release builds require explicit ProGuard rules in `android/app/proguard-rules.pro` with `isMinifyEnabled = true` in `build.gradle.kts`; without this, AGP 8.x fails on missing Play Core classes.
- `image_picker_android` Pigeon `BasicMessageChannel` silently fails in release mode — root cause not resolved; do NOT attempt to fix again. Native `MethodChannel` bridge in `MainActivity.kt` is the confirmed working replacement.
- Camera + gallery go through `com.local_social/camera` MethodChannel: `capturePhoto`, `captureVideo`, `pickImages`, `pickVideoFromGallery`.
- `file_picker` (`com.mr.flutter.plugin.filepicker`) must be kept via `-keep class com.mr.flutter.plugin.filepicker.** { *; }` or R8 renames `FilePickerPlugin` and breaks method dispatch for `FileType.image`, `FileType.video`, etc.
- `ffmpeg_kit_flutter_new` (package `com.antonkarpenko.ffmpegkit`) classes are REMOVED by R8 by default, crashing video compression and thumbnail generation. Fix: `-keep class com.antonkarpenko.ffmpegkit.** { *; }` in `proguard-rules.pro`.
- Google Play Core classes must be suppressed with `-dontwarn com.google.android.play.core.**` rules.
- `FileProvider` config at `android/app/src/main/res/xml/file_paths.xml` is required for camera capture via `FileProvider.getUriForFile`.
- `MainActivity` extends `FlutterFragmentActivity` (not `FlutterActivity`) so that `ActivityResultLauncher` registration in `onCreate` has access to `ComponentActivity.registerForActivityResult`.

---

## Feed Performance Decisions

- The main feed keeps its 20-post pagination size for now, but heavy media should not be eagerly initialized for every visible card on first load.
- In the main feed, only the active card area should build full media widgets; off-focus posts should render lightweight media previews/posters and defer heavier media work until the user scrolls near them.

---

## Architecture Direction

- The project stays on Supabase as the primary backend.
- The app is now running against the self-hosted Supabase deployment on the VPS, not hosted Supabase.
- Firebase may be added later for push notifications and related mobile platform services, not as the primary replacement for the current relational backend.
- The current self-hosted Supabase/test VPS is `87.106.13.170` and the standard SSH user is `deploy`.
- On this development PC, SSH key-based access for `deploy@87.106.13.170` is already configured and should be assumed available for future maintenance commands unless noted otherwise.
- The self-hosted Supabase VPS now has automated `deploy`-user backups every 6 hours via `~/bin/backup_supabase_vps.sh`, writing timestamped database, storage, and config archives under `~/backups/supabase/` with a default 5-day retention window. This is an on-box recovery layer only; offsite replication is still required before launch.
- The VPS monitoring layer is intentionally lightweight and non-root: `~/bin/monitor_vps_health.sh` logs container status, public endpoint health, disk, memory, uptime, and load to `~/monitoring/health.log` every 10 minutes. This is sufficient for test/pre-launch visibility; external alerting can be added later.
- The VPS also sends one daily summary email via `~/bin/daily_server_summary.py`, reusing the existing SMTP config from `~/supabase-project/.env` and summarizing current health, containers, latest backup, and recent monitoring output. Default recipient is `ali.kashifmalik@gmail.com` unless overridden with `ALERT_EMAIL_TO`.
- Critical email alerting now runs separately via `~/bin/critical_server_alert.py` with a 30-minute cooldown. On the small test VPS it is intentionally limited to harder failures: missing/unhealthy containers, app/storage endpoint failures, and high disk usage. Memory/load-based critical alerting is deferred until the larger production VPS.

---

## Flutter Analyze Status

- ~126 issues (all infos), no errors or blocking warnings.
- Do NOT remove `_buildQaPreview` in `feed_screen.dart:3031` — it cascades into many more warnings.
- Common infos: `withOpacity` deprecated → replace gradually with `.withValues(alpha: x)`.

---

## Known Pitfalls

- `feed_screen.dart` has lots of dead code. Removing one unused method cascades into more warnings. Only remove simple unused imports/variables in small files.
- Always restore from git (`git checkout HEAD -- <file>`) if a deletion cascades badly.
- Unread badge streams in `unread_badge_controller.dart` listen to the entire `messages` and `offer_messages` tables unfiltered — every message from any user triggers an RPC call. Low priority now but will degrade at scale. (See `todo.md`)

---

## Firebase Security & Secrets (2026-03-16)

### What happened
Android `google-services.json` and web `firebase-messaging-sw.js` were accidentally committed and pushed to the public GitHub repo, exposing two Firebase API keys. Google and GitGuardian both sent alerts.

### What was done
- Both API keys rotated in Google Cloud Console immediately
- `android/app/google-services.json` removed from git tracking, added to `.gitignore`
- `web/firebase-messaging-sw.js` removed from git tracking, added to `.gitignore`
- `lib/core/config/firebase_web_config.dart` — hardcoded key replaced with `String.fromEnvironment('FIREBASE_WEB_API_KEY')`
- `web/firebase-messaging-sw.js.template` created — placeholder `{{FIREBASE_WEB_API_KEY}}` substituted at build time
- `scripts/build_web.sh` created — loads `.env.local`, generates service worker, runs `flutter build web`
- `.env.local.example` created as setup reference
- Web API key restricted in Google Cloud Console: HTTP referrers (Firebase Hosting domains only) + 8 Firebase APIs only

### Gitignored secrets (must be present locally — never commit)
| File | How to obtain |
|------|--------------|
| `android/app/google-services.json` | Firebase Console → Project Settings → Android app → Download |
| `ios/Runner/GoogleService-Info.plist` | Firebase Console → Project Settings → iOS app → Download |
| `web/firebase-messaging-sw.js` | Auto-generated by `scripts/build_web.sh` |
| `.env.local` | Copy `.env.local.example`, set `FIREBASE_WEB_API_KEY` |
| `lib/core/config/env.dart` | Manually created — contains Supabase URL + anon key |

### Running web locally
```bash
# Debug run only (service worker must already exist locally)
flutter run -d chrome --dart-define=FIREBASE_WEB_API_KEY=<your_key>
```

### Releasing / deploying web
Web is hosted on VPS at `deploy@87.106.13.170:/var/www/local_social_web/`, served by **Caddy v2** at `https://app.allonssy.com`. Firebase is used only for FCM and in-app messaging — NOT for hosting.

Every web release MUST go through the build script — never run `flutter build web` directly or the service worker won't be generated and FCM will break.

```bash
# Build + deploy in one command
bash scripts/build_web.sh --deploy

# Build only (no deploy)
bash scripts/build_web.sh
```

After deploying, verify:
- App loads at https://app.allonssy.com
- No Firebase errors in browser console (F12)
- Send a test FCM message from Firebase Console → Engage → Messaging → Send test message

### Firebase web API key restriction (Google Cloud Console)
Allowed APIs: FCM Registration, Firebase Installations, Firebase Hosting, Identity Toolkit, Token Service, Cloud Logging, Firebase App Check, Firebase In-App Messaging.
Allowed referrers: Firebase Hosting domains only.
Verified working: `curl` from outside allowed domain returns `403 PERMISSION_DENIED / API_KEY_HTTP_REFERRER_BLOCKED`.

---

## Working Rules

- Read this file before changing video feed layout, startup/auth persistence, navigation, or notification behavior.
- Update this file after every significant change without waiting to be asked.
- Never commit `google-services.json`, `GoogleService-Info.plist`, `firebase-messaging-sw.js`, `.env.local`, or `env.dart`.

---

## Docs Organization

---

## Localization Expansion

- As of 2026-03-16, fixed-text localization was extended further across `search_screen.dart` and `feed_screen.dart`.
- Search UI labels, filters, empty states, and fixed result metadata now follow the profile-backed app language.
- Feed translation now covers filter controls, share/status messages, desktop sidebars, top-trending cards, profile completeness cards, and feed error/open-original actions.
- User-generated content remains in its original language and is not auto-translated.
- Browse/list screens for marketplace, gigs, foods, businesses, and restaurants now localize their fixed titles, search/filter controls, sort labels, CTA buttons, and empty/error states.
- As of 2026-03-17, French is the default app language across logged-out/auth flows and as the fallback for profile-backed locale resolution. The language selector remains in `lib/features/profile/presentation/complete_profile_screen.dart`; it is not part of `profile_settings_screen.dart`.
- The `profiles.app_language` migration default/backfill was corrected to `fr`, and remaining localization call sites were aligned to `tr(..., args: ...)` to match the custom localization API.

- As of 2026-03-16, all repository Markdown files were consolidated under `docs/`.
- Moved files: root `README.md` → `docs/README.md`, root `CLAUDE.md` → `docs/CLAUDE.md`, `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` → `docs/ios_launch_screen_assets.md`.

---

## Feed UX Changes (2026-03-18)

### Collapsible filters — marketplace & gigs
- Both `marketplace_screen.dart` and `gigs_screen.dart` now use an `AnimatedSize`-wrapped collapsible filter panel toggled by an `ActionChip` that shows an active-filter count badge. A "Clear" `TextButton` resets all filters. Previously filters were always visible and took excessive vertical space.

### Video feed — single feed-level mute
- Removed per-video mute toggle from `NetworkVideoPlayer` when used inside the video feed.
- Added a single `_feedMuted` bool in `mobile_video_feed.dart`. All videos in the feed share this state via the `muted:` prop on `NetworkVideoPlayer`.
- `NetworkVideoPlayer` gained a `final bool? muted` prop and a `didUpdateWidget` override that syncs the external mute state to the controller volume.

### Video feed — gradient tap-through fix
- The gradient `DecoratedBox` overlay in `mobile_video_feed.dart` was absorbing all pointer events, blocking pause/mute taps. Fixed by wrapping it in `IgnorePointer`.

### Video feed — pull-to-refresh
- Pull-down refresh on first video: uses `PageController.addListener` reading `position.pixels < 0`. Threshold is 80 logical pixels of drag. Shows an arrow indicator → spinner on trigger.
- End-of-feed refresh button rendered in the same outer `Stack` at the bottom of the last card.
- `BouncingScrollPhysics(parent: PageScrollPhysics())` enables overscroll on the vertical `PageView`.

### Main feed — deferred media loading
- Each feed card is wrapped in `VisibilityDetector` with a 50% visibility threshold. Media (photo/video) is only rendered when the card is at least half visible.
- Replaced scroll-position estimate with a `Set<int> _visiblePostIndices` updated per card.

### Main feed — quick session filters
- Session-only filter chips: All, Marketplace, Gigs, Food, Lost & Found, Organization.
- Only chips for enabled post types appear (driven by the same feature-flag booleans used by the rest of the feed).
- Mobile: hidden pill toggle near the bottom nav; tapping opens an animated chip overlay. Web: always-visible bar above the feed.
- State is not persisted — resets to "All" on every app start.
- Filter popup had a white `Container` background removed; chips now float transparently over the feed.

### Main feed & video feed — FAB visibility
- FABs (post button + scroll-to-top) are hidden when the user is on the video feed page (`_mobileFeedPage == 1`).

---

## Sharing Module (2026-03-18)

### Overview
Listing share links for marketplace products, gigs, and food ads. Share button appears only on the three detail pages — not on feed cards.

### Share URLs
| Type | URL pattern |
|------|-------------|
| Product | `https://app.allonssy.com/marketplace/product/{id}` |
| Gig | `https://app.allonssy.com/gigs/service/{id}` |
| Food | `https://app.allonssy.com/foods/{id}` |

### Widget (`lib/widgets/share_button.dart`)
- `ShareButton` — icon button (`Icons.share_outlined`) placed in the app bar `actions`.
  - Mobile (Android/iOS): opens native OS share sheet via `share_plus`.
  - Web (mobile browser): uses Web Share API via `share_plus`.
  - Web (desktop/unsupported browsers): falls back to `Clipboard.setData` + snackbar "Link copied".
- `ShareSheet` — optional bottom-sheet variant (copy + native share) for future use.
- Helper functions: `marketplaceShareUrl()`, `gigShareUrl()`, `foodShareUrl()`.

### Detail screens updated
`marketplace_product_detail_screen.dart`, `gig_detail_screen.dart`, `food_ad_detail_screen.dart` — `GlobalAppBar` now receives `actions: [ShareButton(...)]` when the post is loaded. The `const` keyword was removed from the `GlobalAppBar` constructor call.

### Dynamic routing (desktop vs mobile vs app)
Links are plain HTTPS URLs pointing to the web app:
- **Desktop browser** → opens web app directly.
- **Android (app installed)** → Android App Links intercept → opens native app at the correct route.
- **Android (no app)** → opens mobile browser → loads web app.
- **iOS (app installed)** → Universal Links intercept → opens native app at the correct route.
- **iOS (no app)** → opens mobile browser → loads web app.

### Android App Links
Three `<intent-filter android:autoVerify="true">` blocks added to `AndroidManifest.xml` with `pathPrefix`:
- `/marketplace/product`
- `/gigs/service`
- `/foods`

Verification file: `web/.well-known/assetlinks.json` — SHA-256 fingerprint is populated from the debug keystore (release build currently uses `signingConfig = signingConfigs.getByName("debug")`).
SHA-256: `7A:70:86:F0:EC:30:94:64:FB:40:02:14:95:11:74:99:B4:F6:2F:F5:80:6E:DE:89:21:72:8F:6F:49:0D:D0:A9`
**If a dedicated release keystore is added later**, update `assetlinks.json` with the new fingerprint and redeploy web.

### iOS Universal Links
`ios/Runner/Runner.entitlements` created with `com.apple.developer.associated-domains` → `applinks:app.allonssy.com`.
**Requires linking in Xcode**: Open `ios/Runner.xcodeproj` → Runner target → Signing & Capabilities → + Capability → Associated Domains. Xcode will use the `.entitlements` file automatically once linked.

Verification file: `web/.well-known/apple-app-site-association` — **requires Apple Team ID** (placeholder `REPLACE_WITH_TEAM_ID`).
Find it in Apple Developer Portal → Membership. Replace and redeploy.

### Server
Caddy (`/etc/caddy/Caddyfile`) updated with:
- `handle /.well-known/apple-app-site-association` → serves with `Content-Type: application/json` (required by iOS, file has no extension).
- `handle /.well-known/*` → serves other well-known files statically.
- Both placed before the `try_files → index.html` catch-all handler.
Both `.well-known` files are deployed as part of `flutter build web` output in `web/.well-known/`.

### Package added
`share_plus: ^10.1.4` added to `pubspec.yaml`.

---

## Legal Pages — About Us, Terms & Conditions, Privacy Policy (2026-03-18)

### Routes
Three new public routes added to `router.dart` — no authentication required:
- `/about` → `LegalScreen(page: LegalPage.about)`
- `/terms` → `LegalScreen(page: LegalPage.terms)`
- `/privacy` → `LegalScreen(page: LegalPage.privacy)`

Router redirect updated: unauthenticated users are allowed through to these routes (alongside existing `/login`, `/register`, `/forgot-password`).

### Screen
Single file: `lib/screens/legal_screen.dart` with a `LegalPage` enum (`about`, `terms`, `privacy`). The screen has no `GlobalBottomNav` (intentionally — works without a session). Content is entirely inline.

### Content
| Page | Key details |
|------|-------------|
| About Us | Allonssy platform intro; Tradister SAS; SIREN 988 318 945; Ris-Orangis, France; hello@allonssy.com |
| Terms & Conditions | Eligibility (16+), account rules, acceptable use, user content licence, marketplace disclaimer, moderation, liability limit, governing law (France) |
| Privacy Policy | GDPR-compliant; data types collected; legal bases; user rights (access, rectification, erasure, portability, objection); CNIL reference; data retention 30 days after account deletion |

### Entry Points
| Surface | How links appear |
|---------|-----------------|
| Mobile bottom nav | Account sheet — About Us / Terms / Privacy list tiles with icons, separated by a `Divider`, placed above the logout tile |
| Web app bar (≥1100 px) | "More" popup menu — About Us / Terms / Privacy items separated by `PopupMenuDivider`, placed above logout |
| Login screen | Small teal underlined links in a `Wrap` at bottom of the login card (both mobile and web) |
| Register screen | Same footer at bottom of the register card |

---

## Price Range Feature (2026-03-18)

### Overview
Marketplace and gigs posts now support an optional price range (min + max) in addition to a single price.

### Database
- Migration `supabase/migrations/20260318120000_add_market_price_max.sql` adds `market_price_max double precision` to `posts`.
- Applied to production VPS via `docker exec supabase-db psql -U postgres -d postgres`.

### Model
- `Post` model: added `final double? marketPriceMax` field mapped from `market_price_max`.

### Service
- `PostService.createPost()`: added `double? marketPriceMax` parameter, included in insert payload as `market_price_max`.

### Create post screen
- For marketplace and gigs post types only, a **Single / Range** `ChoiceChip` toggle appears above the price field.
- "Single" mode: single EUR price field (existing behavior).
- "Range" mode: two side-by-side fields — "Min price" and "Max price". Validation ensures max > min.
- Food ad posts retain a single price field; the toggle is not shown for them.
- `_marketPriceMaxCtrl` added and disposed properly. `_priceIsRange` resets when switching away from market/service post types.

### Display — price formatting rule
All five display locations use this rule:
- Both min and max present (max > min): `EUR X.XX – EUR Y.XX`
- Min only: `EUR X.XX`
- Neither: fallback label (e.g. "Price on request", "Rate on request", "Looking to buy")

### Display locations updated
| File | Change |
|------|--------|
| `lib/widgets/post_card.dart` | `_MarketListingBody` now uses `post.marketPrice` + `post.marketPriceMax` directly instead of legacy content parsing. Intent and title also read from Post model fields with content fallback. |
| `lib/screens/marketplace_screen.dart` | Grid card price label updated to show range. |
| `lib/screens/gigs_screen.dart` | Grid card price label updated to show range. |
| `lib/screens/marketplace_product_detail_screen.dart` | Detail price row updated. |
| `lib/screens/gig_detail_screen.dart` | Detail price row updated. |

## 2026-03-18 Android release signing

### Release keystore
- Created dedicated Android upload keystore at `android/allonssy-upload-keystore.jks`.
- Local signing config stored at `android/key.properties`.
- Both files are gitignored and must be backed up securely outside the repo.

### Gradle signing
- `android/app/build.gradle.kts` now loads `key.properties` and signs `release` builds with the dedicated upload keystore instead of the debug keystore.
- Release artifact builds successfully as `build/app/outputs/bundle/release/app-release.aab`.

### App Links fingerprint
- `web/.well-known/assetlinks.json` must use the release keystore SHA-256 fingerprint, not the debug keystore fingerprint.
- Current production fingerprint: `46:D4:62:90:E1:98:25:4E:E1:0C:D2:87:20:54:59:8B:00:45:E8:AC:9D:D8:73:18:BD:CE:DE:67:DD:79:52:05`
- Any older notes referring to the debug-keystore fingerprint are superseded by this entry.

---

## Google Play App Signing & SHA Keys (2026-03-19)

- Google Play App Signing re-signs the AAB with Google's own delivery certificate — the SHA keys for the delivery certificate differ from the upload keystore.
- **Google Cloud Console Android OAuth client** must have the Play Store delivery SHA-1 (from Play Console → Setup → App signing → App signing key certificate).
- **Firebase** must have both: the upload keystore SHA-256 AND the Play Store delivery SHA-256. Firebase supports multiple SHA fingerprints per Android app.
- A **second** Android OAuth client (debug) was created in Google Cloud Console with the debug SHA-1 (`BB:E5:B1:A4:01:7C:10:A1:37:BA:03:15:34:E4:ED:87:D3:D5:AE:F8`) so that debug builds still work after the Play Store SHA replaced the original client's SHA-1.
- As of 2026-03-19: Firebase has 2 SHA-1s + 2 SHA-256s. Google Cloud Console has 2 Android OAuth clients (debug + production).

---

## Banned Emails (2026-03-19)

- Migration `supabase/migrations/20260319120000_add_banned_emails.sql` creates a `banned_emails` table with a unique index on `lower(email)`.
- A `BEFORE INSERT` trigger `check_banned_email_on_signup()` on `auth.users` raises an exception if the email matches any banned entry, blocking re-registration at the DB level.
- RLS policy: admins only (via `profiles.is_admin`).
- Applied to VPS via SSH + docker exec.
- Admin UI in `lib/features/moderation/presentation/admin_review_screen.dart`:
  - New "Banned" tab (tab 8 — `TabController(length: 8)`).
  - Paginated banned list with unban buttons and a manual add form.
  - When deleting a user, admin is prompted "Ban email address?" — if yes, email is immediately added to `banned_emails`.
  - "Banned Emails" quick-nav card added to admin dashboard.

---

## White Hover Fix — Chips & FilledButton (2026-03-19)

- `ChipThemeData` has no `overlayColor` property. The hover tint on chips is controlled via `color: WidgetStateProperty.resolveWith(...)` — this sets the chip background per state (selected/hovered/pressed) rather than a separate overlay.
- `FilledButtonThemeData` now uses `ButtonStyle` with `overlayColor: WidgetStateProperty.resolveWith(...)` using a dark (black) tint, which darkens the teal background on hover instead of flashing white (Material 3 default uses `onPrimary` = white).
- `OutlinedButtonThemeData`: added `overlayColor` with teal-tinted press state.

---

## French Category Translations (2026-03-19)

- All 5 category label functions now accept `{bool isFrench = false}`:
  - `marketCategoryLabel` (`lib/core/market_categories.dart`)
  - `serviceCategoryLabel` (`lib/core/service_categories.dart`)
  - `foodCategoryLabel` (`lib/core/food_categories.dart`)
  - `restaurantCategoryLabel` (`lib/core/restaurant_categories.dart`)
  - `businessCategoryLabel` (`lib/core/business_categories.dart`)
- All list screens (`marketplace_screen`, `gigs_screen`, `foods_screen`, `restaurants_screen`, `businesses_screen`) store `bool _isFrench` set from `context.l10n.isFrench` in `build()` and pass it to every label call.
- All detail screens (`marketplace_product_detail_screen`, `gig_detail_screen`, `food_ad_detail_screen`) use `final isFrench = context.l10n.isFrench;` and pass it to label calls. Missing `app_localizations.dart` import was added to each.
- `create_post_screen.dart`: post type dropdown uses `t.localizedLabel(isFrench: isFrench)`, sub-category dropdowns pass `isFrench`.
- `feed_filter_setup_screen.dart`: was missing `app_localizations.dart` import — added. All 3 category chip sections now pass `isFrench`.
- `PostTypeX.localizedLabel({bool isFrench = false})` added to `lib/core/post_types.dart`. Old `label` getter delegates to it for backward compatibility.
- `lib/core/create_post_launcher.dart` fully translated (Create post → Créer une publication, Camera → Appareil photo, etc.).
- `feed_screen.dart` `_getPostTypeBadge()` and `_getCategoryBadge()` and `_intentLabel()` updated for French.

---

## Chat Read Receipt Ticks (2026-03-19)

- `read_at` column already existed on both `messages` and `offer_messages` tables and was returned by the `get_messages` RPC.
- UI only changes:
  - `chat_screen.dart`: `_buildMessageBubble` accepts `createdAt` and `readAt` params. Own messages show `Icons.done` (grey = sent) or `Icons.done_all` (teal = seen). Timestamp shown on all messages. `_formatTime(String? isoString)` helper converts ISO to `HH:mm` local time.
  - `offer_chat_screen.dart`: same inline tick + timestamp logic.
- Realtime UPDATE subscription was already in place — ticks update live when recipient reads.

---

## Chat Reply + Like (2026-04-03)

### Reply to specific message
- Reply context (id, text preview, sender name) is stored in the message payload via `ChatMessageCodec` — no DB changes needed. Old messages without reply fields decode gracefully (null).
- Long press any message → action sheet with "Reply" + "Like/Unlike" options.
- Reply shows a teal-bordered banner above the input bar with the quoted sender + text. Cancel via ✕.
- Sent message shows an embedded reply quote at the top of the bubble.
- Both `chat_screen.dart` and `offer_chat_screen.dart` support reply. Offer chat now uses `ChatMessageCodec.encode()` for text messages.

### Like a message (❤️)
- Migration `supabase/migrations/20260403120000_add_message_reactions.sql` creates `message_reactions` and `offer_message_reactions` tables, each with `UNIQUE(message_id, user_id)` (one like per user per message) and full RLS.
- `ChatService.toggleReaction()` / `fetchReactions()` and matching methods on `OfferChatService`.
- Reactions are fetched after every `_reloadMessages()` call and stored in `_reactions` map.
- Liked messages show a small ❤️ {count} badge below the bubble; the heart is red if liked by me.
- **Apply migration**: SSH to VPS and run `docker exec supabase-db psql -U postgres -d postgres -f /dev/stdin < supabase/migrations/20260403120000_add_message_reactions.sql`

---

## Emoji Picker (2026-04-03)

- Added `emoji_picker_flutter: ^4.4.0` to `pubspec.yaml`.
- Emoji button (`Icons.emoji_emotions_outlined`) added to the input bar of `chat_screen.dart` and `offer_chat_screen.dart`, and below the content TextField in `create_post_screen.dart`.
- Tapping the button hides the keyboard and shows a 280px `EmojiPicker` panel below the input area; tapping the button again or tapping the text field restores the keyboard and hides the picker.
- The picker inserts emojis directly at the cursor position via the shared `TextEditingController`.
- Config: 8 columns, 28px emoji size, opens on SMILEYS category.

---

## App Name Fix (2026-03-19)

- `android:label` in `AndroidManifest.xml` was set to `"Allonssy"` (without `!`) in a pre-release cleanup commit.
- Restored to `android:label="Allonssy!"`.
- Version bumped to `1.0.3+4`; AAB rebuilt and uploaded to Play Store internal testing.

---

## Terminology Updates: Business or Service Provider & Professionals (2026-09-12)

- Updated account type registration/edit label from `"Business"` to `"Business or Service Provider"` (French: `"Entreprise ou prestataire de services"`) in `AppLocalizations`.
- Updated feed screen "Local directory" section to show `"Professionals"` (French: `"Professionnels"`) instead of `"Businesses"`, with subtitle `"Explore nearby local professionals."` (French: `"Explorez les professionnels locaux a proximite."`).
- Updated top title of the businesses screen (`lib/screens/businesses_screen.dart`) to `"Professionals and Service Providers"` (French: `"Professionnels et prestataires de services"`).
- Files updated: `lib/core/localization/app_localizations.dart`, `lib/screens/feed_screen.dart`, `lib/screens/businesses_screen.dart`.

---

## Web OAuth Redirect & Root Route Fix (2026-09-12)

- Google OAuth on web redirects back to root with auth code (`/?code=...`).
- `GoRouter` was throwing `GoException: no routes for location: /` because no root route was defined.
- Added `GoRoute(path: '/')` with loading indicator and updated router `redirect`:
  - When `path == '/'` with an auth `code` parameter, holds on root so Supabase can finish PKCE token exchange.
  - When authenticated, redirects from root to `/feed`.
  - When unauthenticated without code, redirects to `/login`.
- Files updated: `lib/app/router.dart`.
- VPS config: added `http://localhost:*/**,http://localhost:*,http://127.0.0.1:*/**,http://127.0.0.1:*` to `ADDITIONAL_REDIRECT_URLS` in `~/supabase-project/.env` and recreated `supabase-auth` container so OAuth redirects stay on localhost during development.

---

## 2-Tier Business & Professional Categorization (2026-09-12)

- Replaced flat legacy categories with a 2-tier categorization system (Main Category + Subcategory):
  - **Health & Medical**: Doctors, Clinics, Pharmacies, Therapists
  - **Professional & Legal**: Lawyers, Notaries, Accountants, Consultants
  - **Home & Trades**: Electricians, Plumbers, Construction, Maintenance
  - **Auto & Mobility**: Garages, Dealers, Mechanics
  - **Beauty & Personal Care**: Salons, Barbers, Spas
  - **Education & Fitness**: Tutors, Driving Schools, Gyms, Trainers
  - **B2B & Industry**: Manufacturing, IT Services, Wholesale
- **Database changes** applied directly on VPS (`docker exec -i supabase-db psql`):
  - Dropped old constraint `profiles_business_type_check`.
  - Added `business_subtype text` column to `profiles`.
  - Added index `idx_profiles_business_type_subtype (business_type, business_subtype)`.
  - Migrated legacy data (`it_software` -> `b2b_industry` with `it_services`).
  - Migration file: `supabase/migrations/20260912230000_add_business_subtype_and_update_categories.sql`.
- **UI changes**:
  - `lib/core/business_categories.dart`: Core taxonomy, definitions, and English/French helper formatters.
  - `lib/features/profile/presentation/complete_profile_screen.dart`: Two dropdowns for Main Category and Subcategory; Subcategory dynamically populates and validates based on selected Main Category.
  - `lib/screens/businesses_screen.dart`: Filter row has a Main Category dropdown filter and dynamic Subcategory filter when a main category is selected. Displays `Main Category • Subcategory` on cards.
  - `lib/features/profile/presentation/profile_detail_screen.dart`: Renders formatted category and subcategory string.
  - `lib/core/localization/app_localizations.dart`: Added category and subcategory localization keys.
  - `test/widget_test.dart`: Updated unit tests verifying the 7 main categories, all subcategories, and localized formatters.

---

## Feed Share Badge & Visibility Badge Refinement (2026-09-12)

- Redesigned the share badge on feed post cards (`lib/screens/feed_screen.dart`):
  - Previously, a post allowing sharing rendered an amber author badge containing clunky English phrases like `"Public can share"` directly next to `[PUBLIC]`, appearing repetitive and awkward (`[PUBLIC] [Public can share]`).
  - Created a dedicated `_buildShareBadge(String scope)` with a clean blue pill design (`Color(0xFF2563EB)` alpha border/fill) and an `Icons.share_outlined` icon.
  - Replaced the wordy phrasing with concise, professional terms:
    - `public`: `Shareable` (FR: `Partageable`)
    - `followers`: `Share: Followers` (FR: `Partage : Abonnés`)
    - `connections`: `Share: Connections` (FR: `Partage : Relations`)
  - Localized the visibility badge `[LOCAL]` / `[PUBLIC]` properly via `AppLocalizations`.
  - Added localization keys to `AppLocalizations` (`_en` and `_fr`) and added test assertions to `test/widget_test.dart`.

---

## Release 1.2.0+7 & Deployment (2026-09-12)

- **Version Bump**: Bumped version to `1.2.0+7` in `pubspec.yaml` and documented in `docs/play_store_release.md`.
- **Pre-Live QA**:
  - Ran full test suite (`flutter test`) verifying business taxonomy, localization, post parsing, and share badges (4 suites passed).
  - Static analysis: verified 0 compile errors on modified files.
  - Database schema & query integrity verified against VPS Supabase PostgreSQL (`87.106.13.170`).
- **Web Production Deploy**:
  - Generated production service worker from template with `FIREBASE_WEB_API_KEY`.
  - Built production web bundle via `scripts/build_web.sh --deploy`.
  - Deployed to VPS (`/var/www/local_social_web`) served by Caddy at `https://app.allonssy.com`. Verified HTTP 200 live response.
- **Android Release**:
  - Built release App Bundle (`.aab`) with upload keystore for Google Play Store upload.
- **Git**:
  - All changes committed and pushed to `origin/main`.

---

## Update "Businesses" to "Professionals" in Mobile Options & Quick Links (2026-09-13)

- Updated quick link label in the mobile bottom sheet Options menu (`lib/widgets/global_bottom_nav.dart`) from `businesses` to `professionals` (`"Professionals"` / `"Professionnels"`).
- Updated quick link button in the feed discovery section (`lib/screens/feed_screen.dart`) to use `professionals`.
- Updated `AppLocalizations` (`lib/core/localization/app_localizations.dart`):
  - `'businesses'` key now resolves to `"Professionals"` (FR: `"Professionnels"`).
  - `'search_businesses'` updated to `"Search professionals..."` (FR: `"Rechercher des professionnels..."`).
  - `'no_businesses_found'` updated to `"No professionals found"` (FR: `"Aucun professionnel trouvé"`).

---

## Marketplace Listing Status (Available / Reserved / Sold) (2026-09-15)

- Added listing status lifecycle (`available`, `reserved`, `sold`) for marketplace posts:
  - **Database Migration**: `supabase/migrations/20260915030000_add_item_status_to_posts.sql` adds column `item_status text DEFAULT 'available'`, an index on `(type, item_status)`, and a check constraint enforcing valid statuses.
  - **Data Model**: `lib/models/post_model.dart` updated with `itemStatus` property, default `'available'`, parsing from `map['item_status']`.
  - **Service**: `lib/services/post_service.dart` updated to set `item_status: 'available'` when creating market posts, and added `updateItemStatus({required String postId, required String status})`.
  - **Managed Ads**: `lib/features/profile/presentation/managed_ads_screen.dart` provides status badges, quick 1-tap status selector popup menu on ad cards, and status dropdown in the edit modal.
  - **Marketplace Browsing**: `lib/screens/marketplace_screen.dart` renders colored `RESERVED` and `SOLD` badge overlays on listing cards, dims sold item thumbnails, disables offer buttons on sold items, and includes a "Hide sold items" filter toggle.
  - **Product Detail**: `lib/screens/marketplace_product_detail_screen.dart` displays item status badge, provides listing owners with a status switcher, shows a notice when sold, and disables the offer button.
  - **Feed Market Card**: `lib/widgets/post_card.dart` displays `RESERVED` and `SOLD` badges on market posts in social feeds.
  - **Localization & Tests**: Added EN & FR strings in `lib/core/localization/app_localizations.dart` and comprehensive test coverage in `test/widget_test.dart`.

---

## Saved Listings / Bookmarks for Marketplace (2026-09-15)

- Added bookmarking and saved listings system for marketplace:
  - **Database Migration**: `supabase/migrations/20260915040000_create_saved_posts.sql` creates `saved_posts` table with `user_id`, `post_id`, timestamp, unique constraint, indexes, and user-scoped Row Level Security (RLS) policies.
  - **Service**: `lib/services/saved_post_service.dart` provides `isSaved`, `fetchSavedPostIds` (batch lookup), `savePost`, `unsavePost`, `toggleSave`, and `fetchSavedMarketplacePosts` with author exclusions and preserved bookmark chronology.
  - **Marketplace Screen**: `lib/screens/marketplace_screen.dart` has bookmark icon overlay buttons on cards with optimistic feedback & undo snackbars, batch saved status loading, an AppBar bookmark shortcut to `/marketplace/saved`, and a "Saved" filter toggle in the filter section.
  - **Product Detail**: `lib/screens/marketplace_product_detail_screen.dart` includes an interactive bookmark icon button in the AppBar actions alongside the Share button.
  - **Dedicated Saved Listings View**: `lib/screens/saved_listings_screen.dart` registered at `/marketplace/saved` with responsive grid matching marketplace, instant unsave with undo, and rich empty state.
  - **Entry Points**: Added "Saved Listings" navigation options to own profile sidebar & mobile profile sheet (`profile_detail_screen.dart`), and mobile bottom sheet options menu (`global_bottom_nav.dart`).
  - **Localization & Tests**: Full English and French translations in `AppLocalizations` and comprehensive unit test coverage in `test/widget_test.dart`.

---

## Marketplace Network Filter ("From connections / people you follow") & Trust Badges (2026-09-15)

- Added social trust and network-based discovery to Marketplace:
  - **Network ID Discovery**: `lib/services/follow_service.dart` adds `fetchMyNetworkIds()`, performing a single efficient indexed query to categorize both 1-way follows (`followingIds`) and 2-way mutual connections (`connectionIds`).
  - **Source Filtering**: `lib/screens/marketplace_screen.dart` adds a **Source** filter dropdown (`All listings`, `Following & Connections`, `Connections only`). Queries Supabase with `.inFilter('user_id', targetIds)` for exact server-side accuracy, with fast zero-item bypass if target network is empty.
  - **Listing Card Trust Badges**: `lib/screens/marketplace_screen.dart` renders colored trust pills (`Connected` in emerald green with hub icon for mutual connections, `Following` in soft blue with check icon for followed sellers) directly on marketplace listing cards.
  - **Product Detail Seller Card**: `lib/screens/marketplace_product_detail_screen.dart` features a dedicated seller card displaying avatar, seller name, location, and the `Connected` or `Following` badge, with 1-tap navigation to the seller's full profile.
  - **Empty State**: Tailored empty state when filtering by network with a 1-tap `View all listings` button.
  - **Localization & Tests**: Complete English and French keys in `AppLocalizations` and unit tests in `test/widget_test.dart`.

---

## Price Drop / Discount Indicator for Marketplace (2026-09-15)

- Added discount and price drop tracking and visualization across Marketplace:
  - **Database Migration**: `supabase/migrations/20260915050000_add_original_price_to_posts.sql` adds `original_price numeric` column to `posts` table with an index on `(post_type, original_price)`.
  - **Model**: `lib/models/post_model.dart` adds `originalPrice`, `hasDiscount` (`originalPrice != null && marketPrice != null && originalPrice! > marketPrice!`), and `discountPercentage` (rounded percentage off).
  - **Creation & Management**:
    - `lib/services/post_service.dart`: Accepts `originalPrice` and stores it with the post payload.
    - `lib/screens/create_post_screen.dart`: Provides an optional "Original price" input for marketplace posts.
    - `lib/features/profile/presentation/managed_ads_screen.dart`: In ad editor dialog, allows editing original price. If the seller lowers the price without manually filling the original price, the previous price is automatically preserved as `original_price`. Also displays strikethrough original prices and `-X%` discount badges on managed ad cards.
  - **Marketplace Grid & Filters**:
    - `lib/screens/marketplace_screen.dart`: Displays prominent red `-X%` badges on listing image cards, highlights discounted prices in bold red alongside strikethrough original prices, and adds a `Price drop only` checkbox filter.
  - **Saved Listings & Product Detail & Social Feeds**:
    - `lib/screens/saved_listings_screen.dart`: Displays `-X%` badge and strikethrough original price on saved item cards.
    - `lib/screens/marketplace_product_detail_screen.dart`: Renders current price, strikethrough original price, and `-X%` badge in product details header.
    - `lib/widgets/post_card.dart`: Renders strikethrough original price and `-X%` badge in feed marketplace cards.
  - **Localization & Tests**: Fully localized in English and French (`original_price`, `original_price_optional`, `price_drop`, `price_drop_only`, `percent_off`) and unit tests verified in `test/widget_test.dart`.

---

## Saved Gigs & Services (2026-09-15)

- Added bookmarking and quick filtering for freelance gigs and service requests:
  - **Service**: Extended `lib/services/saved_post_service.dart` with `fetchSavedGigPosts`, retrieving saved posts with `type in ('service_offer', 'service_request')`, excluded blocked/author posts, and mapped in preserved reverse-chronological order.
  - **Gigs Browsing (`lib/screens/gigs_screen.dart`)**:
    - Interactive bookmark icon overlay on gig cards with instant optimistic feedback, error rollback, and undo snackbar.
    - Batch loads saved post IDs upon feed load.
    - Added "Saved gigs only" filter toggle checkbox in the filter drawer to filter gigs by bookmarked status.
  - **Gig Detail (`lib/screens/gig_detail_screen.dart`)**:
    - Added bookmark icon button in `GlobalAppBar` actions for saving/unsaving directly from gig detail.
  - **Localization & Tests**: Added `saved_gigs` and `saved_gigs_only` keys in `AppLocalizations` (EN & FR) and unit test assertions in `test/widget_test.dart`.

---

## Favorite Local Businesses & Restaurants (2026-09-15)

- Added favoriting system for local directory (businesses & restaurants):
  - **Database Migration**: `supabase/migrations/20260915070000_create_favorite_businesses.sql` creates `favorite_businesses` table (`user_id`, `business_id`, timestamp, unique constraint, indexed, with RLS policies allowing users to select and modify their own favorites).
  - **Service**: Created `lib/services/favorite_business_service.dart` supporting optional injected `SupabaseClient` for testability, with `isFavorite`, `fetchFavoriteIds` (batch loading), `addFavorite`, `removeFavorite`, and `toggleFavorite`.
  - **Businesses Directory (`lib/screens/businesses_screen.dart`)**:
    - Trailing heart icon button on directory list tiles for 1-tap favoriting/unfavoriting.
    - "Favorites only" filter checkbox in the filter bar.
  - **Restaurants Directory (`lib/screens/restaurants_screen.dart`)**:
    - Trailing heart icon button on restaurant list tiles.
    - "Favorites only" filter checkbox below distance radius slider.
  - **Business / Restaurant Profile (`lib/features/profile/presentation/profile_detail_screen.dart`)**:
    - Favorite heart action button in `GlobalAppBar` when viewing external business/restaurant profiles.
    - Full-width outlined "Favorite" / "Favorited" action button in profile header.
  - **Localization & Tests**: Localized keys (`favorite_businesses`, `favorite_businesses_only`, `favorite_business`, `unfavorite_business`, etc.) in `AppLocalizations` (EN & FR) and unit tests in `test/widget_test.dart`.

---

## Marketplace Item Condition & Filter (2026-09-15)

- Added condition tier classification to Marketplace items:
  - **Database Migration**: `supabase/migrations/20260915060000_add_item_condition_to_posts.sql` adds column `item_condition text` to `posts` table with an index on `(type, item_condition)` and check constraint allowing `new`, `like_new`, `good`, `fair`, `parts`.
  - **Helper & Model**:
    - `lib/core/item_condition.dart`: Defines standard values and `itemConditionLabel(condition, l10n)` helper for UI display.
    - `lib/models/post_model.dart`: Adds `itemCondition` property parsed from `map['item_condition']`.
  - **Post Creation & Ads Management**:
    - `lib/services/post_service.dart`: `createPost` accepts `itemCondition`.
    - `lib/screens/create_post_screen.dart`: Condition selection dropdown when creating selling marketplace posts.
    - `lib/features/profile/presentation/managed_ads_screen.dart`: Condition dropdown in edit ad modal, persists condition updates, and displays condition chip on managed ad cards.
  - **Marketplace Browsing & Details**:
    - `lib/screens/marketplace_screen.dart`: Condition chip on product card, and condition dropdown filter in filter drawer (`All conditions`, `New`, `Like new`, `Good`, `Fair`, `For parts`).
    - `lib/screens/marketplace_product_detail_screen.dart`: Condition info badge row displayed prominently on product details.
    - `lib/widgets/post_card.dart`: Item condition chip displayed on marketplace cards in social feed.
  - **Localization & Tests**: Full EN & FR translations for all 5 condition tiers and filters in `AppLocalizations` and comprehensive unit test coverage in `test/widget_test.dart`.

---

## Quick Presets in Offer & Direct Chat (2026-09-15)

- Added 1-tap conversational suggestion chips above chat composers:
  - **Offer Chat (`lib/features/chat/presentation/offer_chat_screen.dart`)**:
    - Context-aware chips dynamically adapting to post type:
      - Marketplace: "Is this still available?", "What is your best price?", "Where is pickup located?", "Can you do delivery?"
      - Gigs / Services: "Are you still available for this?", "What is your estimated timeline?", "Can you provide a quote?", "Can we discuss details?"
    - Tapping a chip populates the message input field, positions cursor at the end, and focuses the input ready for sending or editing.
  - **Direct Chat (`lib/features/chat/presentation/chat_screen.dart`)**:
    - Horizontal scrollable quick preset chips ("Hi, how are you?", "Is this still available?", "Can you share more details?", "Let me know when you're free!") directly above composer.
  - **Localization & Tests**: Presets localized in English and French in `AppLocalizations` and tested in `test/widget_test.dart`.

---

## Profile Listings & Gigs Tabs (2026-09-15)

- Added segmented tabs on user profile screen (`lib/features/profile/presentation/profile_detail_screen.dart`):
  - Segmented control toggling between **Posts** (social timeline), **Marketplace** (selling items), and **Gigs & Services** (offered services).
  - Lazy loading for marketplace and service posts authored by the profile user with status chips (`Sold`, `Reserved`).
  - Contextual quick navigation to manage listings if the viewing user is the profile owner.
  - Localization in English (`tab_posts`, `tab_marketplace`, `tab_services`, `no_user_listings`, `no_user_services`) and French (`Publications`, `Marketplace`, `Missions & Services`).

---

## Unified Categorized Search (2026-09-15)

- Enhanced Search (`lib/screens/search_screen.dart`) with fast categorized exploration:
  - Top category filter chips: **People / Profiles**, **Posts**, **Marketplace**, **Gigs**, and **Directory**.
  - Direct querying of posts matching specific types (`market`, `post`, `service_offer`/`service_request`) with real-time UI indicator badges and pricing/rates.
  - Deep linking on tap:
    - Marketplace items -> `/marketplace/product/:id`
    - Gigs / Services -> `/gigs/service/:id`
    - Food ads -> `/foods/:id`
    - General posts -> `/post/:id`
    - Profiles & Directory -> `/p/:id`
  - Localization and testing in `test/widget_test.dart`.

---

## App Sharing & Community Invites (2026-09-15)

- Implemented community invite flow:
  - `lib/widgets/share_button.dart`: Added `appShareUrl()` returning canonical web address (`https://app.allonssy.com`) and `shareApp(BuildContext context)` with localized invite message and web fallback to clipboard.
  - Entry points:
    - Global bottom navigation sheet ("Share Allonssy" tile).
    - Profile settings screen ("Community & Feedback" section).
    - User profile action buttons and options popup menu.
  - Full localization in English and French (`share_app`, `share_app_title`, `share_app_subtitle`, `share_app_message`, `link_copied`).

---

## Feedback & Bug Report System (2026-09-15)

- Built in-app feedback and bug reporting flow:
  - **Database Migration**: `supabase/migrations/20260915080000_create_feedback.sql` creates `user_feedback` table (`user_id`, `category`, `message`, `rating`, `contact_email`, `device_info`, `app_version`, `created_at`) with RLS policy allowing authenticated and anon inserts.
  - **Service**: `lib/services/feedback_service.dart` providing `submitFeedback` with automatic platform and device info collection.
  - **UI**: `lib/screens/feedback_screen.dart` with category selection (General, Bug, Feature idea), star rating, message text field, optional email, and loading state. Accessible as both a standalone screen (`/feedback`) and modal bottom sheet via `FeedbackScreen.showSheet(context)`.
  - Accessible from bottom nav options, profile settings, and profile sidebar.
  - Full localization in English and French (`give_feedback`, `feedback`, `feedback_type`, `feedback_general`, `feedback_bug`, `feedback_feature`, `feedback_rating`, `feedback_submitted_success`, etc.).

---

## VPS Database Migrations Applied (2026-09-15)

- Successfully deployed and verified all 6 new database migrations on the self-hosted VPS (`87.106.13.170`):
  1. `20260915030000_add_item_status_to_posts.sql`: Added `item_status` column ('available', 'reserved', 'sold') and index.
  2. `20260915040000_create_saved_posts.sql`: Created `saved_posts` table, unique constraints, and RLS policies.
  3. `20260915050000_add_original_price_to_posts.sql`: Added `original_price` column to `posts`.
  4. `20260915060000_add_item_condition_to_posts.sql`: Added `item_condition` column and conditional index for marketplace posts.
  5. `20260915070000_create_favorite_businesses.sql`: Created `favorite_businesses` table, indexes, and user RLS policies.
  6. `20260915080000_create_feedback.sql`: Created `user_feedback` table, rating check, and RLS policies.
- Executed `NOTIFY pgrst, 'reload schema';` on `supabase-db` to immediately refresh PostgREST API schema cache.
- Mirrored all migration files to `/home/deploy/local_social_migrations/` on the VPS.

---

## Push Notifications Pipeline & Triggers Configured (2026-09-15)

- Configured end-to-end push notification delivery across mobile, web, and server:
  - **Android**:
    - Added `com.google.firebase.messaging.default_notification_channel_id` (`default`) and `default_notification_icon` (`@mipmap/ic_launcher`) to `android/app/src/main/AndroidManifest.xml`.
    - Maintained `POST_NOTIFICATIONS` permission and Google Services Gradle plugin `com.google.gms.google-services` with `com.allonssy.app` in `google-services.json`.
  - **Web**:
    - `web/firebase-messaging-sw.js` configured with Firebase project `allonssy` credentials and background notification handler.
    - Updated `lib/core/config/firebase_web_config.dart` with default `apiKey` matching `allonssy` web app for automatic client configuration.
  - **Client Token Sync**:
    - `lib/services/push_notification_service.dart`: Requests notification permissions on startup, fetches platform FCM tokens (using VAPID key on web), and upserts device tokens to `device_push_tokens` table on auth state changes.
  - **Edge Function (`push-dispatch`)**:
    - Deployed on VPS `supabase-edge-functions` container. Authenticates using Google OAuth 2.0 PKCS8 assertion with Firebase Service Account credentials.
    - Dispatches to FCM HTTP v1 API (`https://fcm.googleapis.com/v1/projects/allonssy/messages:send`) with Android high priority (`default` channel) and WebPush payloads.
    - Automatically purges expired/unregistered tokens (`UNREGISTERED` error response).
  - **Database Triggers (`pg_net`)**:
    - Migration `20260915090000_automated_push_notifications.sql` deployed to VPS Supabase:
      - `notification_push_setting_key_for_type(type)`: Maps notification types to user's `app_settings` push preferences.
      - `notification_push_enabled(user_id, type)`: Validates user recipient has push enabled for the specific category.
      - `send_push_notification(recipient_id, title, body, route)`: Dispatches asynchronous HTTP POST to `http://kong:8000/functions/v1/push-dispatch` via `net.http_post`.
      - `trg_push_on_notification`: Automatically sends push notifications for comments, replies, likes, mentions, shares, follows, follow requests, offers, and admin announcements.
      - `trg_push_on_message`: Sends real-time push notifications for new direct chat messages.
      - `trg_push_on_offer_message`: Sends real-time push notifications for offer updates, counter-offers, and offer messages.



