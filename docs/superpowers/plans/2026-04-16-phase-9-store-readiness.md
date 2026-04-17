# Phase 9 — Store Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the app to Apple App Store and Google Play internal/TestFlight tracks with final icon + splash, bilingual store metadata, 6 screenshots per language per platform, a published privacy policy, data-safety declarations, and CI that runs `flutter analyze` + `flutter test` on every PR.

**Architecture:** Most of this phase is binary-ops + docs, not Dart code. The code-side changes are minimal: replace Flutter default icon/splash assets, add `flutter_launcher_icons` + `flutter_native_splash` dev deps to generate per-platform sizes from single SVG/PNG source, and a `.github/workflows/ci.yml` workflow. Store copy and screenshots live under `docs/store/` with a README pointing at upload targets.

**Tech Stack:** Dart 3.11, Flutter, `flutter_launcher_icons ^0.13.1`, `flutter_native_splash ^2.4.0`, GitHub Actions.

---

## File Structure

- **Create**
  - `assets/branding/icon_source.png` — 1024×1024 master icon (Soviet Notebook).
  - `assets/branding/splash_source.png` — 2048×2048 master splash artwork.
  - `docs/store/README.md` — uploading guide (where each file goes in App Store Connect / Play Console).
  - `docs/store/listing_en.md` — English store copy (title, subtitle, description, keywords, promo text).
  - `docs/store/listing_ru.md` — Russian store copy.
  - `docs/store/screenshots/` — 6 per language per platform (24 images total minimum).
  - `docs/store/data_safety.md` — Play Data Safety + App Store Privacy Nutrition Label answers.
  - `docs/store/privacy_policy.md` — source of the policy (published to a public URL).
  - `.github/workflows/ci.yml` — CI.
  - `.github/PULL_REQUEST_TEMPLATE.md` — optional but cheap.

- **Modify**
  - `pubspec.yaml` — add dev deps + `flutter_launcher_icons` + `flutter_native_splash` config.
  - `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — regenerated.
  - `ios/Runner/Assets.xcassets/LaunchImage.imageset/` — regenerated.
  - `android/app/src/main/res/mipmap-*/ic_launcher.png` — regenerated.
  - `android/app/src/main/res/drawable/launch_background.xml` — regenerated.
  - `ios/Runner/Info.plist` — update `CFBundleDisplayName`; confirm privacy strings.
  - `android/app/src/main/AndroidManifest.xml` — confirm `android:label` matches launch.

---

## Task 1: Add icon + splash generator packages

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dev deps**

In `pubspec.yaml` under `dev_dependencies:`:

```yaml
  flutter_launcher_icons: ^0.13.1
  flutter_native_splash: ^2.4.0
```

And at file root, add generator configs:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/branding/icon_source.png"
  adaptive_icon_background: "#FFFEF0"
  adaptive_icon_foreground: "assets/branding/icon_foreground.png"
  min_sdk_android: 21

flutter_native_splash:
  color: "#FFFEF0"
  image: "assets/branding/splash_source.png"
  android_12:
    color: "#FFFEF0"
    image: "assets/branding/splash_source.png"
```

- [ ] **Step 2: pub get**

Run: `flutter pub get`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flutter_launcher_icons + flutter_native_splash"
```

---

## Task 2: Place the master icon + splash artwork

**Files:**
- Create: `assets/branding/icon_source.png`, `icon_foreground.png`, `splash_source.png`

- [ ] **Step 1: Commission / design the icon**

Hand the designer the brief:
- 1024×1024 PNG, no rounded corners (iOS adds them; Android adaptive icon does its own masking).
- Soviet Notebook vocabulary: cream `#FFFEF0` background, navy `#1D2B38` primary, crimson `#B22030` accent, amber `#F5A234` sparingly.
- Central motif: a stylized letter tile with Cyrillic "С" (or bilingual "С/A") with a tiny crimson "stamp" accent. Grid-paper texture OK but readable at 29×29.
- Adaptive foreground version: 1024×1024 PNG with only the letter-tile motif (no background); Google will render it against the cream.

- [ ] **Step 2: Commission / design the splash**

- 2048×2048 PNG.
- Same palette; centered composition; lots of safe-area padding so Android 12+ circular crop doesn't clip.
- Can be simpler than the icon — e.g. the game title in Playfair Display + a small tile motif.

- [ ] **Step 3: Drop files into `assets/branding/`**

- [ ] **Step 4: Generate**

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

- [ ] **Step 5: Verify on device**

Run: `flutter run`
Check: App icon on home screen matches design. Splash shows for <800ms on launch then fades to app.

- [ ] **Step 6: Commit**

```bash
git add assets/branding/ ios/Runner/Assets.xcassets/ android/app/src/main/res/
git commit -m "chore: generate app icon + splash screen from master art"
```

---

## Task 3: Write English store listing

**Files:**
- Create: `docs/store/listing_en.md`

- [ ] **Step 1: Draft copy**

Create `docs/store/listing_en.md`:

```markdown
# Store listing — English

## App Store

**Name:** Слова из Слова — Word Puzzle
**Subtitle:** Bilingual Russian + English word game

**Promotional text (170 char max):**
Form words from one source word. 50 levels in Russian + 50 in English. Cozy Soviet-notebook design. Free to play, no sign-up.

**Description:**
From the makers of cozy word puzzles: **Слова из Слова** (Words from a Word) is a bilingual brain-game for fans of Russian and English wordplay.

Pick a long source word. Form as many shorter words as you can by tapping letter tiles. Each level has required words and bonus finds. 50 handcrafted levels in Russian. 50 in English. No timers. No sign-up. No ads in premium.

**Features**
• 100 levels across two languages
• Soviet-notebook aesthetic — cream pages, navy ink, crimson stamps
• Daily free hint
• Streaks, trophies, best-score tracking
• Bonus words for the curious
• Offline — play anywhere
• One-time "remove ads" purchase
• Designed for Russian-speaking families in the US — English side helps kids learn

**Keywords:** word puzzle, bilingual, russian, слова, anagram, cozy, word game, family

## Google Play

**Title:** Слова из Слова — Word Puzzle
**Short description (80 char):** Bilingual Russian + English word puzzle. 100 handcrafted levels. Offline.
**Full description:** (same as App Store description above)
**Category:** Word
**Content rating:** Everyone

## Assets

- Feature graphic (Play): 1024×500 — see `docs/store/screenshots/feature_en.png`
- App icon (both stores): generated by `flutter_launcher_icons`
- Screenshots: see `docs/store/screenshots/en/`
```

- [ ] **Step 2: Commit**

```bash
git add docs/store/listing_en.md
git commit -m "docs: English store listing copy"
```

---

## Task 4: Write Russian store listing

**Files:**
- Create: `docs/store/listing_ru.md`

- [ ] **Step 1: Draft copy**

Create `docs/store/listing_ru.md`:

```markdown
# Карточка магазина — Русский

## App Store

**Название:** Слова из Слова — Головоломка
**Подзаголовок:** Двуязычная игра в слова

**Рекламный текст (до 170 символов):**
Составляйте слова из одного длинного слова. 50 уровней по-русски и 50 по-английски. Уютный стиль советской тетради. Играть бесплатно.

**Описание:**
**Слова из Слова** — это двуязычная головоломка для всей семьи, созданная в эстетике советской тетради в клетку.

Выберите длинное слово. Составляйте из его букв как можно больше коротких слов, касаясь плиток. В каждом уровне есть обязательные слова и бонусные находки. 50 авторских уровней на русском. 50 на английском. Без таймеров. Без регистрации. Премиум убирает рекламу.

**Возможности**
• 100 уровней на двух языках
• Стиль советской тетради — кремовая бумага, тёмно-синие чернила, алые печати
• Бесплатная подсказка каждый день
• Серии, награды, лучшие результаты
• Бонусные слова для любознательных
• Работает без интернета
• Разовая покупка «Без рекламы»
• Создано для русскоязычных семей в США — английская сторона помогает детям учить язык

**Ключевые слова:** слова, головоломка, русский, английский, анаграмма, детям, семейная игра

## Google Play

**Название:** Слова из Слова — Головоломка
**Краткое описание (80 симв):** Двуязычная головоломка. 100 авторских уровней. Без интернета.
**Полное описание:** (как выше)
**Категория:** Слова
**Возрастной рейтинг:** Для всех

## Ассеты

- Feature graphic (Play): 1024×500 — `docs/store/screenshots/feature_ru.png`
- Скриншоты: `docs/store/screenshots/ru/`
```

- [ ] **Step 2: Commit**

```bash
git add docs/store/listing_ru.md
git commit -m "docs: Russian store listing copy"
```

---

## Task 5: Capture screenshots

**Files:**
- Create: `docs/store/screenshots/{en,ru}/{ios-6.7,ios-5.5,ipad-12.9,android-phone,android-tablet}/*.png`

- [ ] **Step 1: Prepare a demo RewardsProvider state**

Create a script or developer-mode screen that puts the app in an attractive state for screenshots: level 10 in progress, high best scores showing, trophies partially unlocked, bonus counter at 7/10. Easiest: set mock `shared_preferences` values.

- [ ] **Step 2: Capture 6 shots per language per platform**

Suggested shot list (both languages, same composition):

1. Home screen showing Lifetime Score + streak + language
2. Game screen mid-play with tiles selected spelling a word
3. Game screen showing bonus word counter strip + banked hint
4. Level complete overlay with new-best tag
5. Level picker grid showing completed + in-progress states
6. Trophies screen with some badges unlocked

Platform sizes (portrait, final pixel dimensions):
- iOS 6.7" (iPhone 16 Pro Max): 1290×2796
- iOS 5.5" (iPhone 8 Plus): 1242×2208
- iPad 12.9": 2048×2732
- Android phone: 1080×1920
- Android tablet: 1600×2560

- [ ] **Step 3: Add a localized text overlay on each shot (optional but recommended)**

Use Figma or any image editor: top strip with a tagline like "Soviet-notebook word puzzles" / "Уютная головоломка". Brand color accents. Keep safe zones away from store chrome.

- [ ] **Step 4: Save to `docs/store/screenshots/<lang>/<platform>/01.png` etc.**

- [ ] **Step 5: Commit**

```bash
git add docs/store/screenshots/
git commit -m "docs: store screenshots (6 per lang per platform)"
```

---

## Task 6: Write the privacy policy

**Files:**
- Create: `docs/store/privacy_policy.md`

- [ ] **Step 1: Draft the policy**

Create `docs/store/privacy_policy.md`:

```markdown
# Privacy Policy — Слова из Слова

Effective date: 2026-04-16

## 1. Who we are

Слова из Слова (Words from a Word) is published by <Publisher Name>, based in <Country>. Contact: <email>.

## 2. Data we collect

| Data | Source | Purpose | Shared with |
|---|---|---|---|
| Advertising ID (IDFA / AAID) | Device | Serve ads, measure ad performance | AdMob, Google |
| App interaction events (level start/complete, purchases) | In-app | Analytics, tuning | Firebase Analytics |
| Crash diagnostics | In-app (release builds) | Fix bugs | Firebase Crashlytics |
| Purchase receipts | Apple / Google | Entitle premium, grant hint packs | Apple, Google |

We do not collect: your name, email, contacts, location, photos, camera, microphone, or any other personal data.

## 3. Consent

On iOS, we ask permission to use tracking (ATT) before loading any ads. If you decline, ads are still shown but are not personalised. On Android in the EEA/UK, we show Google's UMP consent form for personalised ads. You can revoke or change consent at any time in the app settings.

## 4. Children

The game is rated for all ages. We do not knowingly collect data from children under 13 beyond the minimum required for advertising, and advertising is configured to restrict child-targeted creatives where possible.

## 5. Your rights

You can request deletion of your data by emailing <email>. Because we do not collect personal identifiers, deletion is limited to advertising IDs associated with your device.

## 6. Changes

We will update this page when material changes occur. The effective date at the top reflects the current version.

## 7. Contact

<email>
```

- [ ] **Step 2: Publish to a public URL**

Options:
- Push `docs/store/privacy_policy.md` through GitHub Pages (enable Pages for `docs/` folder in repo settings). URL becomes `https://<user>.github.io/words-from-a-word/store/privacy_policy.html`.
- Or host on a personal site.

Store the final URL — you'll need it in both App Store Connect and Google Play Console.

- [ ] **Step 3: Commit**

```bash
git add docs/store/privacy_policy.md
git commit -m "docs: privacy policy (draft)"
```

---

## Task 7: Data-safety declarations

**Files:**
- Create: `docs/store/data_safety.md`

- [ ] **Step 1: Draft**

Create `docs/store/data_safety.md`:

```markdown
# Data-safety declarations

## Google Play — Data Safety form answers

### Data collected

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| Device or other IDs (Advertising ID) | Yes | Yes (AdMob) | Advertising, Analytics | No (inherent to ad-supported model) |
| App interactions | Yes | Yes (Firebase) | Analytics, App functionality | No |
| Crash logs | Yes | Yes (Firebase) | Analytics, App functionality | No |
| Purchase history | Yes | No | App functionality (entitlements) | No |

### Data not collected

- Personal info (name, email, address, phone)
- Financial info beyond the platform purchase flow
- Health & fitness
- Messages
- Photos, videos, audio, files, contacts
- Location
- Web browsing
- Device performance (besides crashes)

### Data is encrypted in transit: Yes
### Users can request data deletion: Yes (via email; practical because we don't hold identified data)

## App Store — Privacy Nutrition Label

### Data Used to Track You
- Device ID (for third-party advertising via AdMob)

### Data Linked to You
- (none — we don't have user accounts)

### Data Not Linked to You
- Usage Data (product interactions)
- Diagnostics (crashes)
- Purchases (platform-managed)

### Privacy Practices
- No account required
- Tracking handled per Apple's ATT framework
- No data sold to third parties
```

- [ ] **Step 2: Commit**

```bash
git add docs/store/data_safety.md
git commit -m "docs: data-safety declarations for Play + App Store"
```

---

## Task 8: Write `docs/store/README.md`

**Files:**
- Create: `docs/store/README.md`

- [ ] **Step 1: Draft**

Create `docs/store/README.md`:

```markdown
# Store-submission artifacts

This folder contains everything a release manager needs to submit to Apple App Store and Google Play.

## Contents

- `listing_en.md` / `listing_ru.md` — copy to paste into App Store Connect and Play Console, field by field.
- `privacy_policy.md` — source text; published at <URL>. Paste the URL into both store consoles under "Privacy Policy".
- `data_safety.md` — answers to App Store Privacy Nutrition Label and Google Play Data Safety form.
- `screenshots/` — 6 shots per language per platform.
- `feature_en.png`, `feature_ru.png` — 1024×500 Play Store feature graphic.

## Upload checklist — App Store Connect

1. App Information → Privacy Policy URL: <URL>
2. App Information → Category: Word; Secondary: Family
3. Pricing: Free
4. App Privacy → fill per `data_safety.md` §"Privacy Nutrition Label"
5. Localization → English + Russian; paste from `listing_*.md`
6. App Review Information → test account if any; contact email
7. Version → upload build from Xcode archive
8. Screenshots → upload 6 from `screenshots/en/ios-6.7/` and `screenshots/ru/ios-6.7/` plus iPad sets
9. Submit for Review

## Upload checklist — Google Play Console

1. Store presence → Main store listing → paste from `listing_*.md` for each language
2. Store presence → Store settings → Category: Word; Tags: Relaxing, Brain Games
3. App content → Privacy policy: <URL>
4. App content → Data safety → fill per `data_safety.md` §"Play Data Safety"
5. App content → Ads: Yes (AdMob)
6. App content → Target audience: 13+
7. Monetization → In-app products: premium_no_ads_299, hint_pack_099_5
8. Production → Internal testing first; release via staged rollout
9. Upload screenshots to each language track
```

- [ ] **Step 2: Commit**

```bash
git add docs/store/README.md
git commit -m "docs: store-submission README"
```

---

## Task 9: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`
- Create (optional): `.github/PULL_REQUEST_TEMPLATE.md`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install deps
        run: flutter pub get

      - name: Validate level content
        run: dart run tool/validate_levels.dart

      - name: Static analysis
        run: flutter analyze

      - name: Run tests
        run: flutter test --no-pub

  build-android:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Build APK (debug)
        run: flutter build apk --debug

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 7
```

Notes:
- Firebase `google-services.json` / `GoogleService-Info.plist` are gitignored. For CI to build an Android/iOS release with Firebase, add them as `secrets` decoded at workflow-time — out of scope for v1.1 soft-launch since CI only builds debug here.
- iOS build on CI requires macOS runners + code-sign secrets. Skip for v1.1 and build iOS locally via Xcode for TestFlight submission.

- [ ] **Step 2: Optional PR template**

Create `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Summary

<!-- 1-3 bullets: what and why -->

## Testing

- [ ] `flutter analyze` clean
- [ ] `flutter test` passing
- [ ] Manual smoke test on device

## Screenshots (if UI)

<!-- attach before/after -->
```

- [ ] **Step 3: Push and verify**

Push to a branch and open a PR against `main`. Confirm:
- All three CI steps run (validate / analyze / test).
- They pass.
- On merge, `build-android` runs and uploads the APK artifact.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml .github/PULL_REQUEST_TEMPLATE.md
git commit -m "ci: add GitHub Actions workflow (validate + analyze + test + build)"
```

---

## Task 10: App Store Connect + Play Console — product setup

*(Manual console work, documented for the release manager)*

- [ ] **Step 1: App Store Connect**

1. Create app. Bundle ID matches `ios/Runner.xcodeproj`. Primary language: Russian.
2. Add English (U.S.) as secondary localization.
3. Paste metadata from `listing_en.md` / `listing_ru.md`.
4. Add privacy policy URL.
5. Create IAPs:
   - `premium_no_ads_299` — Non-Consumable — $2.99
   - `hint_pack_099_5` — Consumable — $0.99
6. Fill App Privacy details from `data_safety.md`.
7. Upload build via Xcode: Product → Archive → Distribute App → App Store Connect.
8. Assign build to version; submit to TestFlight internal group.

- [ ] **Step 2: Google Play Console**

1. Create app. Package name matches `android/app/build.gradle`. Default language: Russian.
2. Add English (United States) language.
3. Paste metadata.
4. Add privacy policy URL.
5. Create IAPs (same product IDs as Apple).
6. Fill Data Safety form per `data_safety.md`.
7. Upload AAB: `flutter build appbundle --release` → Internal testing track.
8. Add testers; release to internal track.

No code commit for this task.

---

## Task 11: Final pre-launch checklist

- [ ] **Step 1: Code checklist**

- [ ] `flutter analyze` zero issues.
- [ ] `flutter test` all passing.
- [ ] `dart run tool/validate_levels.dart` passes.
- [ ] Manual smoke test: fresh install → ATT prompt → level 1 → purchase premium sandbox → restore → mute → language change → VoiceOver pass.

- [ ] **Step 2: Metadata checklist**

- [ ] `docs/store/listing_en.md` final copy approved.
- [ ] `docs/store/listing_ru.md` final copy approved.
- [ ] Privacy policy published at a stable URL.
- [ ] Screenshots uploaded to both stores for both languages.
- [ ] Feature graphic uploaded to Play.
- [ ] Data safety / privacy label filled.

- [ ] **Step 3: Release checklist**

- [ ] iOS TestFlight build accepted.
- [ ] Android internal-testing track rollout started.
- [ ] Crashlytics DSN verified end-to-end.
- [ ] Firebase Analytics DebugView shows events from TestFlight build.
- [ ] AdMob production ad units live.
- [ ] Both IAP products approved and live in both consoles.

- [ ] **Step 4: Tag the release**

```bash
git tag v1.1.0
git push origin v1.1.0
```

---

## Exit criteria recap

- App icon + splash replaced with final Soviet-Notebook branding.
- Bilingual store copy drafted and approved.
- 6 screenshots per language per platform.
- Privacy policy published; data safety forms completed.
- CI runs on every PR (`validate_levels` + `flutter analyze` + `flutter test`); builds debug APK on main.
- App submitted to TestFlight + Play internal-testing tracks.
