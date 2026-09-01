# DEV_LOG

Running log of the GiftQuest Flutter rebuild (port of `../GiftQuest`, the Kotlin/Compose original). Newest entries first.

---

## Add/Edit Wish — required Category/Price, currency field

Follow-up to the redesign below: Category/Price/Link were tucked behind a collapsed "more details (optional)" section on Add/Edit Wish. Removed that — all three fields are now always visible. Category and Price are now required, with inline `errorText` validation blocking "save wish" if either is missing/invalid (Link stays optional). Also added a `currency` field to the `Gift` model/Firestore schema and a currency dropdown next to Price (`USD`/`EUR`/`TND`/`GBP`, defaulting to TND — a short curated list, not full ISO-4217).

- `lib/models/gift.dart` — new `currency` field (default `'TND'`), `kCurrencyCodes`, and a `currencyLabel()` helper (`$`/`€`/`£`/`DT`, falls back to the raw code otherwise).
- `lib/repositories/gifts_repository.dart` — `addGift`/`updateGift` both take `currency` now, written alongside `price`.
- `lib/providers/guess_chat_providers.dart` — the AI prompt's price-bucket text and win-reveal text use `currencyLabel(item.currency)` instead of a hardcoded €. The numeric bucket cutoffs themselves are deliberately *not* currency-converted (no FX rates involved) — this is fuzzy hint-shaping for the AI, not an actual price display, so only the symbol changes.
- `lib/screens/add_edit_gift_screen.dart` — dropped `_MoreDetailsSection`; Category, Price+currency, and Link are inline fields now. `_validate()` gates `_save()`.

**Legacy data:** wishes saved before this change have `category: ''` / `price: 0.0`. Making the fields hard-required retroactively would mean opening any old wish to tweak something unrelated immediately throws a blocking validation error. Instead, existing wishes missing this data are pre-filled with a fallback on load — category defaults to the existing "🎁 Something Else" catch-all bucket, price defaults to `"0.00"` (0 was already the app's "no price recorded" sentinel, e.g. in the AI prompt's `price<=0` branch) — so validation passes without forcing the user to invent data, while they're still free to correct it. This only applies to *existing* wishes; a brand-new wish still starts with both fields genuinely blank, so the requirement is real going forward.

### Verification
`flutter analyze` → no issues found. `flutter build apk --debug` → succeeded. No app run/adb/emulator testing, no git commit — per `CLAUDE.md`.

---

## Sunset Pop redesign, part 2 — the 8 screens rebuilt against the new data layer

Finishes the redesign started in "Sunset Pop redesign — theme system + Home/Pairing/AI-chat screens" (below) plus the data-layer rebuild from the prior session (see `journal.txt` for the blow-by-blow). That prior session rewrote the models/repositories/providers (renamed `Gift.note`→`hint`, added `GiftVisibility`/lock state, reworked pairing to a request/accept flow, added guesser-driven `gifted` status, capped guesses at 5) but left every screen still calling the old API surface — none of it compiled. This session rebuilt the screens to match `docs/giftquest_ui_spec.md` + the mockups and closed that gap.

- **`lib/screens/home_screen.dart`** — rewritten from a 2-column grid to a vertical row list. My Wishes rows show one of four states in precedence order: locked (faded, lock icon, "unlocks {date}" or "locked") → hidden (not yet guessed) → guessed by partner → gifted. The partner tab embeds the pairing UI directly (`PairingPanel`) when unpaired — no more pushing a separate route — and shows anonymized "wish #N" rows once paired, revealing the real title once resolved (win or lose). Added empty states and a loading skeleton (3 pulsing placeholder rows) for both tabs, and a small custom 2-item bottom nav bar (Home/Settings) with an underline active-indicator, replacing the old plain `AppBar`.
- **`lib/screens/add_edit_gift_screen.dart`** — reordered to the mockup's layout: a rectangular dashed-border photo picker (new `DashedPhotoBox` widget, since `StickerAvatar` is circular), TITLE, "HINT FOR THE AI" (renamed from the old free-text "note" field), a GUESSABLE dropdown driving `GiftVisibility` (with an inline date picker for the "on a set date" option), then save/delete. Category/price/link — used by the existing AI-context logic but absent from the mockup — moved into a collapsed "more details (optional)" section instead of being dropped.
- **`lib/screens/pairing_screen.dart`** — split into `PairingPanel` (the actual UI, no `Scaffold`, so Home can embed it directly) and a thin `PairingScreen` wrapper for the standalone route (reachable from Settings). Replaced the placeholder QR box with a real one via `qr_flutter`. Added the two states the new request/accept pairing flow actually needs to be usable: an incoming-request card (accept/decline) and a "waiting for {partner} to confirm" row with a cancel action. "Scan QR code" opens the new `lib/screens/qr_scan_screen.dart` (`mobile_scanner`), which pops back with the decoded code string.
- **`lib/screens/guess_chat_screen.dart`** — rewritten: anonymized header label (Home passes down "wish #N"), a "⚡ N/5" pill replacing the old 8-segment progress bar, a static "ask anything — I'll answer, but I won't say it outright" hint pill, and an input row that's just a text field + circular send button (no more separate "I think I know!" button — every message has always been a guess under the hood, so the extra button was cosmetic). Removed the old in-chat game-over banner entirely: on the guess controller's `gameState` flipping to `won`/`lost` (via `ref.listen`), the screen now does a `pushReplacement` to the new Reveal screen instead.
- **`lib/screens/reveal_screen.dart`** (new) — win/lose outcome screen. Takes just the `(itemId, itemOwnerId)` args and re-derives everything by watching the same `guessChatControllerProvider` family instance, rather than being handed a snapshot of fields — this means it transparently supports both how it gets reached: `pushReplacement` from an in-progress chat (same live controller), or a direct push from Home's "already resolved" partner row (a fresh controller instance whose existing-result branch reconstructs identical state). Radial gradient tint, tinted outcome icon (solid border for a win, dashed for a loss), result card with the gift thumbnail/title/hint. Win path has a "mark as gifted" action (guesser-driven, per the "gifted" model field) that becomes a static confirmation once used; loss path has no primary action at all — brag/share was explicitly ruled out earlier so nothing was added in its place.
- **`lib/screens/settings_screen.dart`** (new) — dense bordered-row list per the design system's "bordered rows, not cards" convention: account (read-only), notification-preferences/privacy (visual stubs — no backing infra exists), link/unlink partner (confirm dialog before unlinking), log out.
- **`lib/widgets/sticker.dart`** — added `DashedPhotoBox` and `StickerOutcomeIcon`, both backed by a small private dashed-rounded-rect `CustomPainter` (no new package pulled in for this).
- **`lib/utils/date_format.dart`** (new) — a single `formatShortDate()` helper ("24 Dec") since the app doesn't otherwise need `intl`.

Login/signup screens and the other existing widgets (`pill_toggle`, `auth_hero`, `google_sign_in_button`) needed no changes — already matched the established style.

### Verification
`flutter analyze` → no issues found. `flutter build apk --debug` succeeded, confirming `mobile_scanner`/`qr_flutter`'s native Android wiring actually compiles (one non-fatal Gradle deprecation warning about `mobile_scanner` applying its own Kotlin Gradle Plugin — upstream, not actionable here). Per `CLAUDE.md`, the app itself was not run and no adb/device/emulator testing was attempted — that's the user's own next step.

---

## App icon — exact match to the Kotlin app (Android), not a recreation

The previous approach (`flutter_launcher_icons` rasterizing `icon_flat_purple_bold.png`/`icon_foreground_white_bold.png` into per-density PNGs) was a *recreation* of the Kotlin icon from flat art, which introduced fidelity drift versus the original vector. Replaced that with a direct, byte-for-byte copy of the Kotlin app's actual source for the Android adaptive icon.

- **Source confirmed:** `../GiftQuest` (sibling of this project) → `app/src/main/res/drawable/ic_launcher_foreground.xml`. Copied with `cp` (not re-typed/re-derived) to `android/app/src/main/res/drawable/ic_launcher_foreground.xml`; verified identical with `cksum` on both files (same checksum, same byte count — 1542 bytes). No `-v24`-style density variant existed in the Kotlin project to mirror (vector drawables are density-independent by nature, so there's only ever the one `drawable/` copy).
- **Background wiring:** the Kotlin project's `mipmap-anydpi-v26/ic_launcher.xml` wires `<background android:drawable="@color/ic_launcher_background"/>` + `<foreground android:drawable="@drawable/ic_launcher_foreground"/>`, with the color itself defined in `values/ic_launcher_background.xml` as `#3B82F6` (blue — the Kotlin app's own original color, unrelated to this project's purple). Replicated that exact two-element wiring in `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml` (kept the Flutter project's existing `launcher_icon` resource name rather than renaming to `ic_launcher`, since `AndroidManifest.xml` already points `android:icon` at `@mipmap/launcher_icon` and nothing required changing that), with the color value overridden to `#4F378B` (purple) per this project's palette — `values/colors.xml` already had that exact value from the prior icon task, so no change was needed there. Every other structural detail (background/foreground element structure, no inset, direct drawable references) now matches Kotlin's original file.
- **What flutter_launcher_icons had added that Kotlin's original doesn't have:** a `<foreground><inset android:inset="16%">…</inset></foreground>` wrapper. Removed it — the Kotlin vector's own path coordinates (drawn inside a 256×256 viewport, roughly x∈[32,224]) already bake in the correct visual padding for an adaptive icon; wrapping it in another 16% inset would double-pad it and shrink the mark further than the original.
- **Removed the rasterized foregrounds** (`drawable-{m,h,x,xx,xxx}hdpi/ic_launcher_foreground.png`) that `flutter_launcher_icons` had generated. This wasn't just cleanup: Android's resource resolution prefers a density-specific PNG over a density-independent vector XML of the same name, so leaving those PNGs in place would have silently shadowed the new verbatim vector on every real device.
- **`flutter_launcher_icons` is now iOS-only** (`android: false` in `pubspec.yaml`) — iOS can't consume Android's vector-drawable format and still needs a flat PNG, so it keeps using `icon_flat_purple_bold.png` exactly as before (already generated in the prior task; untouched here). Disabling `android` in the config isn't just narrowing scope for this change — it prevents a future `dart run flutter_launcher_icons` from regenerating and clobbering the hand-wired Android setup above back into rasterized PNGs.
- **Deliberately out of scope:** the legacy flat launcher icon for pre-Android-8 devices (`mipmap-{density}/launcher_icon.png`, used when adaptive icons aren't supported at all) is still the `flutter_launcher_icons`-rasterized version from the prior task. The Kotlin app's own equivalent fallback (`mipmap-{density}/ic_launcher.webp`) is *also* a flat raster composite, not a vector — there's no vector source to copy for that tier, and regenerating it here would mean rendering the vector to a PNG myself, i.e. exactly the kind of recreation this task was about avoiding. Left as-is; API 26+ (which is what "exact match" actually matters for) is unaffected.
- Verified `AndroidManifest.xml` still reads `android:icon="@mipmap/launcher_icon"` (unchanged — nothing required updating it, since the resource name wasn't renamed).

`flutter analyze` → no issues found. No app/device/adb testing, per `CLAUDE.md`.

---

## App icon — bolder variants

Superseded the previous icon setup with bolder-stroke assets provided as a revision.

- New source files: `icon_flat_purple_bold.png` (primary, replaces `icon_flat_purple.png`) and `icon_foreground_white_bold.png` (adaptive foreground, replaces `icon_foreground_white.png`). `flutter_launcher_icons` in `pubspec.yaml` now points at both; re-ran `dart run flutter_launcher_icons`, which regenerated the Android mipmaps/adaptive XML (`colors.xml` still `#4F378B`, unchanged) and the iOS `AppIcon.appiconset`.
- `assets/icon/alternate/` (the unwired backup) now holds `icon_flat_blue_bold.png` / `icon_foreground_blue_bold.png` instead of the old blue variants — note the meaning flipped: the old blue backup was a white background with a blue mark, the new one is a **blue background with a white mark**. Old alternate files were deleted, not kept alongside, since the new ones supersede rather than complement them.
- Deleted the now-unreferenced `icon_flat_purple.png`, `icon_flat_blue.png` and `icon_foreground_blue.png` from `assets/icon/` (top level) — nothing else in the project referenced them.
- **Deliberately kept** the old (non-bold) `icon_foreground_white.png` on disk — it's still the active `image`/`android_12.image` for `flutter_native_splash`, which is out of scope for this change (the task only asked to update the launcher icon, and explicitly said to leave the splash SVGs alone). Updating the native splash to the bold foreground too would be a one-line follow-up if wanted, but wasn't requested here.
- Splash SVGs (`gift_body_white.svg`/`gift_lid_white.svg`, stroke-width 12) left untouched per the instruction — no visual mismatch was flagged as needing a fix, so none was made.
- `flutter analyze` → no issues found. No app/device/adb testing, per `CLAUDE.md`.

---

## App icon, gift photos + category, splash screen

Three independent pieces of polish on top of the Sunset Pop redesign.

### 1. App icon
- The 8 provided assets (`icon_flat_purple.png`, `icon_flat_blue.png`, `icon_foreground_white.png`, `icon_foreground_blue.png`, `gift_body_white.svg`, `gift_body_blue.svg`, `gift_lid_white.svg`, `gift_lid_blue.svg`) live in `assets/icon/`. `icon_flat_blue.png` / `icon_foreground_blue.png` are additionally copied into `assets/icon/alternate/` as a kept-but-unused backup — that folder isn't declared in `pubspec.yaml`'s `assets:` list (which only covers `assets/icon/` non-recursively), so it's inert as far as the app/build is concerned, just preserved in the repo for a possible future switch.
- Added `flutter_launcher_icons` (dev dependency) with `image_path: assets/icon/icon_flat_purple.png` as the primary/non-adaptive icon, and an adaptive icon (`adaptive_icon_background: "#4F378B"`, `adaptive_icon_foreground: assets/icon/icon_foreground_white.png`) for Android 8+. Ran `dart run flutter_launcher_icons`, which regenerated `android/app/src/main/res/mipmap-*/launcher_icon.png` + the `mipmap-anydpi-v26` adaptive XML, added `colors.xml` (`ic_launcher_background = #4F378B`), updated `AndroidManifest.xml`'s `android:icon` to `@mipmap/launcher_icon`, and overwrote the iOS `AppIcon.appiconset`.
- Also fixed `pubspec.yaml`: `uses-material-design`/`assets` had been pasted under `dependencies.flutter.sdk` (invalid — that block is a special pub dependency pointer, not a place for Flutter config), which would have made the `assets/icon/` declaration silently ineffective. Moved both keys to the real top-level `flutter:` section where they belong.

### 2. Gift photo + category dropdown (`lib/screens/add_edit_gift_screen.dart`)
- `lib/models/gift.dart` gained an optional `photoUrl` field (`fromFirestore`/`toFirestore`/`copyWith` updated); `GiftsRepository.addGift`/`updateGift` gained an optional `photoUrl` param written straight through to Firestore.
- Category is now a `DropdownButtonFormField<String>` over a fixed 12-value list (`kGiftCategories` in the screen file) — emoji prefixes are part of the stored string, not decoration, so old free-text categories that don't match the list just show as "no selection" rather than crashing the dropdown (`DropdownButtonFormField` asserts if `initialValue` doesn't match an item).
- Photo picking reuses the exact `image_picker` → `CloudinaryService` pattern already used for profile photos on sign-up. On save: if the user picked a new photo, it's uploaded first and only overwrites the stored `photoUrl` on a successful upload — a failed/timed-out upload falls back to whatever `photoUrl` the gift already had, so editing a gift's title can never accidentally wipe out its photo.
- Extracted the circular sticker-shadow photo picker that sign-up's screen had as a private `_StickerAvatar` into a shared `StickerAvatar` widget in `lib/widgets/sticker.dart` (now takes an `ImageProvider?` instead of being hardcoded to a local `XFile`, so it works for both a freshly-picked local photo and an already-uploaded network one) and pointed both screens at it instead of duplicating the widget.

### 3. Splash screen
**Step A — native static splash.** Added `flutter_native_splash`, configured with `color: "#4F378B"` and the centered `icon_foreground_white.png` (including the `android_12:` block, since Android 12+'s splash API is a separate code path from the legacy one). Ran `dart run flutter_native_splash:create`, which generated the launch-background drawables/styles for Android and the launch image set for iOS. No extra `FlutterNativeSplash.preserve()`/`.remove()` calls were needed — `main()` already awaits `Firebase.initializeApp()` before `runApp()`, so the native splash naturally stays up through that init work and disappears exactly when the first Flutter frame paints.

**Step B — animated reveal (`lib/screens/splash_screen.dart`).** This is what that first Flutter frame renders. Pure `AnimationController` + `Transform` + `flutter_svg` — no Lottie, no video, no third-party animation package, as instructed; this was achievable without reaching for anything heavier, so no fallback-to-static-hold was needed.
- Two `SvgPicture.asset` layers (`gift_body_white.svg` static, `gift_lid_white.svg` animated) stacked on a `#4F378B` background; both SVGs share a 256×256 viewBox and were already authored to overlap correctly when rendered at the same size, so the closed-gift pose needed no manual alignment.
- Timeline on one `AnimationController` (800ms) via a single `Interval(0.25, 1.0, curve: Curves.easeOutBack)`: holds flat for the first 200ms, then the lid animates `Transform.translate` (0 → −50px) + `Transform.rotate` (0 → −10°) over the remaining 600ms. On completion, a 150ms hold, then a second 200ms `AnimationController` drives a `FadeTransition` (opacity 1→0) over a `Stack` that has the real start screen (`AuthGate`) already built underneath, revealing it. Total runtime ≈1.15s, under the 1.5s budget.
- Wired in as `MaterialApp.home: SplashScreen(child: AuthGate())` in `main.dart` — `SplashScreen` is a generic `{child}` wrapper, not hardcoded to any particular start screen.

### Verification
`flutter analyze` → no issues found. Per `CLAUDE.md`'s testing boundary, the app was not run and no adb/device/emulator testing was attempted.

---

## Sunset Pop redesign — theme system + Home/Pairing/AI-chat screens

Restyled the app to the "Sunset Pop" visual direction and, per the go-ahead to build real functionality rather than mockups, implemented the three screens that were previously missing: Home (gift grid), Pairing, and the AI Guessing Chat.

### Concurrent-session note
Partway through this task another Claude Code session was found to be working the same request against the same working tree (evidenced by duplicate file writes to `lib/theme.dart` / `lib/widgets/sticker.dart` and duplicate entries in the shared task list). The user closed that session and had this one take over and consolidate. The surviving foundation (`lib/theme.dart` with `buildAppTheme()`, `lib/widgets/sticker.dart`, `lib/widgets/auth_hero.dart`, the restyled `login_screen.dart`/`signup_screen.dart`, and the `*_providers.dart` split) is from that session; everything from Home onward is this session's.

### Theme system
- `lib/theme.dart` — `buildAppTheme()` builds a single dark `ThemeData`/`ColorScheme` from the design tokens (surface `#1C1B1F`, primary `#4F378B`, secondary `#D0BCFF`), plus a `StickerTheme` `ThemeExtension` (border color/width, shadow color/offset, corner radius) so the sticker-shadow look is themed centrally instead of hardcoded per widget. Typography mixes two `google_fonts` families: Fredoka for display/headline/titleLarge slots, Schibsted Grotesk for everything else (labels, body, buttons).
- Screens pull colors via `Theme.of(context).colorScheme` / `.textTheme` — no hardcoded hex values in screen code.

### Reusable components
- `lib/widgets/sticker.dart` — `StickerCard` (bordered panel + hard-edged `BoxShadow` with `blurRadius: 0`, reading the `StickerTheme` extension) and `StickerButton` (pill/rounded button, same treatment, `primary`/`secondary`/`outline` variants, `isLoading` state).
- `lib/widgets/auth_hero.dart` — the purple hero panel with the Fredoka "GiftQuest" wordmark, shared by Login and Sign Up.
- `lib/widgets/pill_toggle.dart` — segmented pill toggle (filled purple = active) used for Home's "My Wishes" / partner switch.
- `lib/widgets/google_sign_in_button.dart` — now a thin wrapper around `StickerButton` (outline variant) instead of a bespoke button.

### Screens restyled (logic/providers/navigation unchanged)
- **Login / Sign Up** — hero panel, pill inputs (via the global `InputDecorationTheme`), `StickerButton` CTAs, Google button below, light-purple text links. No changes to `LoginController`/`SignUpController` or navigation flow.

### Screens built new (Home, Pairing, AI chat didn't exist before this task — only auth screens did)
These are real, Firestore/Groq-wired screens, not visual mockups, per the decision to build full functionality now rather than restyle-only:

- **`lib/screens/home_screen.dart`** — AppBar with wordmark + tappable avatar (opens a sheet: manage pairing / sign out). `PillToggle` between "My Wishes" and the partner's name. My Wishes is a grid of real gift cards (tap to edit via `AddEditGiftScreen`, FAB to add). The partner tab shows anonymized "Mystery Gift" cards with a segmented progress bar and a status label, or a "not linked" empty state pointing at Pairing.
- **`lib/screens/add_edit_gift_screen.dart`** — minimal form (title/category/price/link/note) wired to the existing `GiftsRepository.addGift`/`updateGift`/`deleteGift`. Not in the original design brief's screen list, but Home can't be functional without a way to populate/edit gifts, so it was added as the minimum viable support screen.
- **`lib/screens/pairing_screen.dart`** — "Link with your partner" heading, `StickerCard` "YOUR CODE" panel (via `PairingRepository.ensureMyShareCode`), a **placeholder** QR box (see Deviations), pill code input + Connect (`PairingRepository.linkWithPartnerCode`), and an Unlink action + linked-partner card once paired.
- **`lib/screens/guess_chat_screen.dart`** — header with a segmented guess-count indicator, dark AI bubbles / purple right-aligned user bubbles, bottom input + "I think I know!" `StickerButton` as the single submit action (see Deviations), game-over banner on win/give-up.

### New data layer for the above
- `lib/providers/gifts_providers.dart`, `pairing_providers.dart`, `user_providers.dart` — thin `Provider`/`StreamProvider` wrappers around the existing repositories (`GiftsRepository`, `PairingRepository`, `GameResultsRepository`), plus a `PairingController` (`Notifier`) for the link/unlink actions' loading+error state.
- `lib/providers/guess_chat_providers.dart` — `GuessChatController`, a `NotifierProvider.autoDispose.family<GuessChatController, GuessChatState, GuessChatArgs>` keyed by `(itemId, itemOwnerId)` so each chat screen instance gets isolated, disposable state (mirrors the Kotlin ViewModel's per-screen lifecycle). Ports `GuessChatViewModel`'s greeting → guess loop → save-result flow faithfully, including the exact system prompts and price-bucketing logic.
- `lib/services/groq_api_client.dart` — ports `GroqApiClient` (OpenAI-compatible chat completions against `api.groq.com`), including the 429 → 30s backoff → retry(×2) behavior.
- `lib/services/gift_context_fetcher.dart` — ports `GiftContextFetcher` (fetches the gift's product link, regex-extracts `og:title`/`og:description`, silently no-ops on failure).
- `lib/repositories/game_results_repository.dart` — extended with `getResultForItem` and `streamResults` (read queries needed to know "already guessed" state and to badge the Home grid); the existing `saveGameResult` write path was left as-is.
- `lib/models/chat_message.dart` — `GameState` gained an `alreadyPlayed` value (Kotlin has this; the existing Dart enum didn't).
- `lib/config/game_config.dart` — Groq model IDs (`llama-3.1-8b-instant` for the greeting, `llama-3.3-70b-versatile` for the game), mirroring Kotlin's `GameConfig`.
- `lib/config/app_config.dart` — added `groqApiKey`. **Unlike** `CLOUDINARY_CLOUD`/`CLOUDINARY_PRESET`/`WEB_CLIENT_ID`, this has **no baked-in default** — it's a real bearer secret, not a public identifier, so it must be supplied via `--dart-define=GROQ_API_KEY=...` at build time. `GroqApiClient` degrades gracefully (returns an in-chat message, doesn't crash) when it's absent.

### Deliberate deviations from the Kotlin app / design brief
- **QR code is a static placeholder** (bordered box + icon), not a real generated code — no `qr_flutter`/zxing-equivalent dependency was added. Scanning (camera) was also not ported.
- **No push notifications.** The Kotlin app pings the partner via FCM on new items / guesses / correct guesses (`NotificationService`); not ported — out of scope for a UI redesign task.
- **No drag-to-reorder** on My Wishes (Kotlin uses a `reorderable` Compose library); `GiftsRepository.reorder` exists but nothing calls it yet.
- **AI difficulty is fixed at `Difficulty.medium`**, defined locally (`lib/models/chat_message.dart`), rather than pulled from Firestore remote config the way current Kotlin does (`RemoteConfigRepository`/`aiConfig`) — that remote-config layer wasn't ported to keep this change UI-scoped.
- **Chat history isn't persisted**, only the final `GameResult` (guessCount/won/difficulty) — this matches the existing Dart model's own doc comment ("In-memory only during a guessing game — never written to Firestore"), which predates this session, even though current Kotlin now also stores `itemSnapshot`/`messages`. Kept the simpler existing Flutter schema rather than widening it.
- **Hint-progress bar is `guessCount`-based, not a real "N of 8 hints" counter** — the backend has no persisted hint counter (Kotlin doesn't either, mid-game state is never written to Firestore), so both the Home grid badge and the chat header show `min(guessCount, 8)` filled segments as a proxy.
- **"I think I know!" is the only submit action** in chat (no separate "ask a question" vs "guess" distinction) — the underlying Groq call has always treated every message uniformly and let the model infer correctness, so a second button would've been cosmetic without matching backend semantics.
- Home's account menu (avatar tap) is a simple bottom sheet (pairing / sign out), not the Kotlin app's full `ModalNavigationDrawer` with tutorial overlay, FCM token registration, etc.

### Firebase project change
Registered the debug keystore's SHA-1 with the Flutter app's Firebase Android client (`gift-guess-app` project) via `firebase apps:android:sha:create`, then re-pulled `google-services.json` — needed for Google Sign-In to get a valid OAuth Android client for `com.abdennour.giftquest_flutter` (previously only had a web client entry). This was done in the earlier auth-flow session; noted here since it's what makes the Google button on the restyled Login/Sign Up actually work.

### Verification
`flutter analyze` → no issues found. Per explicit instruction for this task, the app was **not** run/deployed/tested on a device or emulator — that's out of scope here and handled separately.

---

## Auth flow (Login + Sign Up)

Built the email/password + Google Sign-In auth flow as a faithful port of the Kotlin app's `LoginScreen`/`SignUpScreen`/`LoginViewModel`/`SignUpViewModel`.

### What was built
- `lib/repositories/auth_repository.dart` — wraps `firebase_auth` (sign in/up, sign out, password reset) and `google_sign_in` (v7 API: `GoogleSignIn.instance.initialize(serverClientId: ...)` once, then `authenticate()` → `GoogleAuthProvider.credential(idToken: ...)` → `signInWithCredential`).
- `lib/repositories/user_repository.dart` — `saveUser(UserProfile)` → `users/{uid}`.
- `lib/services/cloudinary_service.dart` — multipart upload to Cloudinary on signup photo pick; returns `null` (never throws) on any failure so signup isn't blocked by a bad upload, matching Kotlin.
- `lib/providers/auth_providers.dart` — `LoginController`/`SignUpController` (`Notifier<AuthFormState>`) mirroring `LoginViewModel`/`SignUpViewModel`'s loading/error state shape. Google sign-in profile creation for brand-new users is fire-and-forget (matches Kotlin: navigation doesn't wait on the Firestore write), but the **email/password** signup path *does* wait for the Cloudinary upload + Firestore write to finish before reporting success, also matching Kotlin.
- `lib/screens/login_screen.dart`, `signup_screen.dart` (now restyled — see above).
- `lib/config/app_config.dart` — `CLOUDINARY_CLOUD`/`CLOUDINARY_PRESET`/`WEB_CLIENT_ID`, `--dart-define`-overridable but defaulted to the real values from the Kotlin project's `local.properties` (these are public identifiers, not secrets, so baking in real defaults is safe and means the app works without extra setup).

### Decisions
- **Forgot Password is actually wired up.** The Kotlin app has `LoginViewModel.reset(email)` but the screen's `onForgotPassword` callback is empty (`{}`) — dead scaffolding. The task asked for it to work, so Login's "Forgot Password?" opens a small dialog and calls `sendPasswordResetEmail`, with a generic confirmation snackbar (doesn't leak whether the email exists, and swallows errors the same way Kotlin's `reset()` does).
- **Navigation is explicit** (`Navigator.push`/`pushAndRemoveUntil`), not a reactive router keyed off `authStateChanges()`. This matters for email signup: Firebase flips to "signed in" the instant `createUserWithEmailAndPassword` succeeds, before the Cloudinary upload/Firestore write finish — a reactive router would navigate to Home too early. `AuthGate` in `main.dart` only picks the *initial* screen once (mirroring the Kotlin NavHost's `startDestination` check), matching Kotlin's `popUpTo(LOGIN){inclusive=true}` semantics via explicit calls instead.
- Facebook Login was confirmed unused/dead scaffolding in the Kotlin app and was not ported.

### Firebase project change
See the SHA-1 registration note above (Sunset Pop section) — done during this phase of the work.

### Verification
Built and ran on a connected Android device (`23117RA68G`) against the live `gift-guess-app` Firebase project: confirmed the Login screen renders per the (pre-redesign) layout, and email signup form fields work via `adb`-driven input. Google Sign-In and end-to-end signup/login against Firestore were not exercised to completion in that pass — the redesign work above superseded the original request before that testing finished.
