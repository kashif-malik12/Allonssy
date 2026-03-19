# Play Store Release Pack

## Current Release Blocker

Before uploading to Google Play, fix Android release signing in [android/app/build.gradle.kts](/C:/Users/ALI/Documents/VS%20Projects/Allonssy/android/app/build.gradle.kts).

Current state:
- `release` still uses `signingConfigs.getByName("debug")`

This is not a proper production Play Store setup. Create a dedicated release keystore and switch the release build to that signing config before first production upload.

---

## App Identity

- App name: `Allonssy`
- Package name: `com.allonssy.app`
- Website: `https://app.allonssy.com`
- Company: `Tradister SAS`
- Location: `Ris-Orangis, France`

---

## Short Description

Use this in Google Play short description:

`Local social network for nearby posts, marketplace deals, gigs, food and chat.`

Alternative:

`Discover nearby posts, local deals, services, food ads and community chat.`

---

## Full Description

Use this as the main Play Store description:

`Allonssy is a local community app built to help people connect, share and discover what is happening nearby.

Follow local posts, browse marketplace listings, find services, explore food ads and chat directly inside one app.

With Allonssy you can:

- share updates with people near you
- discover local marketplace offers
- post or browse gigs and services
- explore food listings and nearby businesses
- follow people, businesses and organizations
- chat directly about posts and offers
- control your app language in English or French

Allonssy is designed for real local communities, with location-aware discovery, profile-based preferences and fast access to the content that matters around you.

Key features:

- Local feed with nearby posts
- Marketplace for products and offers
- Gigs and services listings
- Food ads and local business discovery
- Direct chat and offer conversations
- English and French app language support
- Shareable listing links
- Privacy, safety and moderation controls

Whether you want to buy, sell, promote a service, share local news or stay connected with people around you, Allonssy gives you one place to do it.

Join your local network with Allonssy.`

---

## Screenshot Plan

Google Play should show the clearest user value first. Do not use old screenshots with outdated labels like `Local Feed`.

Recommended phone screenshot order:

1. Local feed
   Caption: `See what is happening near you`

2. Marketplace
   Caption: `Buy and sell in your area`

3. Gigs / services
   Caption: `Find local services and opportunities`

4. Food listings
   Caption: `Explore food and nearby places`

5. Chat / offers
   Caption: `Message directly and manage offers`

6. Profile / settings / language
   Caption: `Use Allonssy in French or English`

Optional extra screenshots:

7. Search
   Caption: `Search posts and profiles nearby`

8. Notifications
   Caption: `Stay updated in real time`

---

## Screenshot Requirements

For Play Store phone screenshots, prefer:

- Portrait
- Clean data
- Consistent status bar
- No debug banners
- Real Allonssy branding
- At least one screenshot showing French UI
- At least one screenshot showing marketplace or gigs

Avoid:

- Empty states unless they look intentional
- Placeholder/demo text that looks fake
- Mixed old branding
- Debug/dev visual artifacts

---

## Capture Checklist

Before taking screenshots:

- Use a release-like build, not a debug banner build
- Make sure app title/branding says `Allonssy`
- Use polished demo accounts and realistic listings
- Keep location data valid and consistent
- Turn on the strongest screens: feed, marketplace, gigs, food, chat
- Capture one screenshot with French selected in profile language

---

## Release Checklist

1. Create a real Android release keystore.
2. Update `android/app/build.gradle.kts` to use release signing.
3. Increase `versionCode` and `versionName` if needed.
4. Build an Android App Bundle:
   `flutter build appbundle --release`
5. Test the release build on a real Android device.
6. Prepare Play Store graphics:
   - app icon
   - feature graphic
   - phone screenshots
7. Paste short and full descriptions from this doc.
8. Complete Play Console data safety, privacy policy, app access, and content rating.
9. Upload the `.aab`.
10. Roll out to internal testing first before production.

---

## Recommendation

Do not push directly to production Play release from the current signing setup.

First do:
- dedicated release keystore
- release AAB test on device
- fresh screenshots with current Allonssy branding
- internal test track upload
