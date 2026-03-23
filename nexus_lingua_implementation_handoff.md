# Nexus Lingua — Implementation Handoff (Phases 1–5 complete → Phase 6 next)

This document summarizes **what is implemented through Phase 5**, **Phase 6 / Phase 7 guidance for the next agent**, **what remains per the PRD**, and **constraints the next developer or agent must not violate**. It is meant to be read together with **`nexus_lingua_prd.md`** and **`.cursorrules`**.

**File location:** repository root, alongside `nexus_lingua_prd.md`  
**Flutter project root:** `nexus_lingua/`

---

## 1. Sources of truth (read before changing behavior)

| Document | Role |
|----------|------|
| **`nexus_lingua_prd.md`** | Product requirements, schema, roadmap phases, UX rules |
| **`.cursorrules`** | Enforced engineering rules (web-first, no `dart:io` in web-shared code, repository pattern, breakpoints, dependency policy) |

If the PRD and this handoff disagree, **trust the PRD** for product intent and **update this handoff** after you change the codebase.

---

## 2. Roadmap alignment (PRD §10)

| Phase | PRD name | Status in repo |
|-------|-----------|----------------|
| **1** | Foundation | **Done** — project, models, `DatabaseHelper`, web DB factory hook |
| **2** | Cyber UI | **Done** — theme, responsive shell, flashcard, XP bar, mastery badge |
| **3** | SRS Engine | **Done** — `FSRSEngine`, study session, `review_log`, due queries |
| **4** | Evaluation & Input | **Done** — `StudyLayout.useTypistMode` (≥840 lp), typist `TextField` + `SimilarityEvaluator` + `similarity_r` in `review_log`, compact `FsrsRatingRow`, confetti on Easy (4), short miss “glitch” border pulse (Again / typist Miss) |
| **5** | Text Processing | **Done (MVP)** — `SentenceTokenizer` (`\p{L}\p{N}`-aware split), **`SentenceDecoderScreen`** (wide split / narrow stack), cyan underline + border for known lemmas, bottom sheet → **`CardRepository.insertCard`**; home rail **Sentence decoder** only when **wide** (≥840 lp). **Not** full PRD §8.2 Card CRUD manager. |
| **6** | Packaging | **Next** — PRD §10: web build + hosting notes + browser QA; then Windows `.exe` + Android `.apk` |
| **7** | *(Handoff scope)* | **Not in PRD §10** — Use **§13** below: post-v1.0 hardening, CI, deck/dashboard, deferred PRD (v1.1 / v1.2). |

**Transition (Phases 1–5 → 6):** Feature work through **Sentence decoder** is in place; **no PRD blockers** to starting Phase 6. Remaining product gaps (full deck manager, dashboard, Settings) are **documented in §8** and can ship **after** or **in parallel** with packaging QA—do **not** block **`flutter build web`** on them unless product owner says otherwise.

**Phase 4 nuance:** Compact 4-button flow remains for viewports **below** the study breakpoint. **Typist mode** does not show manual FSRS buttons (PRD §5.1 / §8.3). Optional `.cursorrules` refinement (non-web `Platform.isAndroid` forcing compact on phones) is **not** implemented — gating is **width-only** for a single web-safe code path.

**Phase 5 nuance:** Decoder **entry** is wide-only on the home **deck rail**; the **screen** still works on narrow (stacked panes) if navigated there later. New cards use **minimal metadata** from `LanguageProfile.features` (`case_sensitive` → `false`, other keys → `null`).

---

## 3. Phase 1 — Foundation (what exists)

### 3.1 Project & dependencies

- **`nexus_lingua/pubspec.yaml`**  
  - Runtime: `sqflite`, `sqflite_common_ffi_web` (web SQLite factory), `path`, `path_provider`, `confetti` (**used** on study screen for Crit!/Easy), `meta`  
  - Dev: `sqflite_common_ffi` for **VM tests** only  
- **Do not** add packages outside the PRD stack without explicit approval (see `.cursorrules` / PRD exceptions for web DB).

### 3.2 Directory layout (under `lib/`)

Scaffold matches PRD: `core/database`, `core/models`, `core/srs`, `core/evaluator`, **`core/text`** (tokenizer), `features/study`, `features/deck_manager`, `features/dashboard`, **`features/sentence_decoder`**, `shared/widgets`, `shared/theme`, `shared/layout`.

### 3.3 Models (`lib/core/models/`)

- **`language_profile.dart`** — `id`, `language`, `features` (list ↔ JSON in SQLite), `createdAt`  
- **`word_card.dart`** — Full card + SRS fields; **`metadata`** as `Map<String, dynamic>` ↔ JSON column; **`lastReviewedAt`** (`DateTime?`) persisted for FSRS elapsed-time on subsequent reviews  

**Critical:** All JSON for `metadata` and profile `features` is encoded/decoded in Dart only — SQL stores opaque text.

### 3.4 Database (`lib/core/database/`)

- **`database_helper.dart`** — **Singleton** (`DatabaseHelper()`). Owns the single `Database` instance, schema version **3**, `PRAGMA foreign_keys = ON` + **`busy_timeout`** after open.  
  - **Native:** DB file under app documents dir via `path_provider`  
  - **Web (`kIsWeb`):** path from `getDatabasesPath()` after platform factory is set (avoids `path_provider` failures on web)  
  - **Tests:** `DatabaseHelper.debugDatabaseAbsolutePath` forces a temp file path; call `closeDatabaseForTesting()` between tests  
- **`sqflite_platform.dart`** — Conditional import: stub vs **`sqflite_platform_web.dart`** (`databaseFactory = databaseFactoryFfiWeb`)  
- **Schema tables:** `language_profiles`, `word_cards`, `review_log`, **`app_preferences`** (key/value string prefs, e.g. theme mode via **`ThemeService`**) — PRD §6 plus v2/v3 migrations in code.  
- **Backup JSON (`exportToJson` / import):** Export includes **`language_profiles`**, **`word_cards`**, **`review_log`**, and **`app_preferences`**. **`importProfilesAndCardsFromJson`** merges **profiles + cards** and, when the key is present, **upserts `app_preferences`** by primary key; it does **not** import **`review_log`** (append-only history). Returns **`({profiles, cards, preferences})`**. Older backup files without `app_preferences` still import.  
- **API surface:** `insertProfile`, `insertCard`, `getCardsForProfile`, **`getLemmaSetForProfile`**, **`getFirstProfile`**, **`getCardsForFirstProfile`**, `getDueCards`, `updateCardAfterReview`, `insertReviewLog`, **`getAppPreference` / `setAppPreference`**, `exportToJson`, `importProfilesAndCardsFromJson`, `seedDatabase`, `countProfiles`, etc.

**Critical invariant:** **UI and features must not import or call `DatabaseHelper` directly.** Use **`CardRepository`** (see §4). **Exception:** small core services (e.g. **`ThemeService`**) may use **`DatabaseHelper`** with constructor injection for tests — not widgets.

### 3.5 Repository (`lib/core/database/card_repository.dart`)

- **`CardRepository({DatabaseHelper? helper})`** — inject `helper` in tests  
- **`loadDueCardsForProfile(profileId, now)`** — due = `due_date <= now` (unix seconds)  
- **`insertCard(WordCard)`** — new row (Sentence Decoder / future deck manager)  
- **`loadLemmaSetForProfile(profileId)`** — lemma set for underline (wraps **`getLemmaSetForProfile`**)  
- **`commitReview({ updatedCard, rating, stabilityBefore, similarityR })`** — **must** persist card row then append **`review_log`**; `updatedCard.id` required; **`similarityR`** set in typist mode (ratio), `null` in compact-only flow  
- **`bootstrapPersistence()`** — opens DB, seeds German demo deck if empty  
- **`firstProfile` / `loadFirstProfileCards`** — delegate to **`DatabaseHelper.getFirstProfile` / `getCardsForFirstProfile`** (no ad-hoc `getDatabase` queries in the repository)  
- **`importBackupProfilesAndCards`** — wraps **`importProfilesAndCardsFromJson`**; returns **`({profiles, cards, preferences})`**

---

## 4. Phase 2 — Cyber UI (what exists)

### 4.1 Theme (`lib/shared/theme/app_theme.dart`)

- **`buildNexusTheme()`** — Material 3 tuned to Cyber-Minimalist palette  
- **`AppColors`** — includes feedback colors for Miss / Hard / Hit / Crit! (aligned with PRD §5.2)

### 4.2 Layout (`lib/shared/layout/`)

- **`nexus_breakpoints.dart`** — **`NexusBreakpoints.wideLayoutMinWidthLp = 840`** (must stay aligned with `.cursorrules` `study_layout_breakpoint_width_lp`)  
- **`nexus_responsive_shell.dart`** — wide rail vs compact column for **home** shell  
- **`study_layout.dart`** — **`StudyLayout.useTypistMode(BuildContext)`** — `MediaQuery` width ≥ **840** lp → typist study UI (Phase 4)

### 4.3 Widgets (`lib/shared/widgets/`)

- **`flashcard_widget.dart`** — lemma/translation + metadata grid filtered by `LanguageProfile.features`; gender-colored border  
- **`xp_stability_bar.dart`** — stability vs `S_max` (constant in widget; PRD suggests settings later)  
- **`mastery_badge.dart`** — tier from stability thresholds  
- **`fsrs_rating_row.dart`** — four buttons, FSRS ratings **1–4**, min tap height **48** lp  

---

## 5. Phase 3–5 — Core features (what exists)

### 5.1 `FSRSEngine` (`lib/core/srs/fsrs_engine.dart`)

- **Custom Dart only** — **no** third-party FSRS package (auditable, per project rules)  
- **17 default weights** — exactly the PRD / `.cursorrules` list  
- **`schedule(WordCard card, int rating, DateTime now)`** — returns **`WordCard.copyWith(...)`** (immutable update); sets **`dueDate`** as `now + Duration(days: S.round())`, updates **`lastReviewedAt`** on first and subsequent reviews as implemented  
- First review vs subsequent review branches use **`reviewCount == 0`**  
- Subsequent reviews use **`lastReviewedAt`** for elapsed days **t** in **R = 0.9^(t/S)**

**Critical for downstream work:** Any new field that affects scheduling must be threaded through **`WordCard`**, **`toMap`/`fromMap`**, **`updateCardAfterReview`**, and tests.

### 5.2 Similarity evaluator (`lib/core/evaluator/`)

- **`similarity_evaluator.dart`** + **`evaluation_result.dart`**  
- Matches PRD §5.1 thresholds and labels  
- **Wired** from **`StudySessionScreen`** when **`StudyLayout.useTypistMode`** is true: submit → **`evaluate`** → brief label display → **`commitReview`** with **`similarityR: result.ratio`**

### 5.3 Study session (`lib/features/study/study_session_screen.dart`)

- **Stateful** screen: loads due queue via repository, **reveal** prompt (lemma) → **`FlashcardWidget`**, then:
  - **Typist (wide):** `TextField` (“Type the lemma”), **Submit** / keyboard done → evaluator → colored **Crit!/Hit/Hard/Miss** label ~450ms → FSRS schedule + **`commitReview`** with **`similarityR`**
  - **Compact (narrow):** **`FsrsRatingRow`** → **`commitReview`** with **`similarityR: null`**
- **Confetti** (`confetti` package): **`ConfettiController.play()`** when FSRS rating **4** (Easy / perfect typist outcome)  
- **Miss feedback:** ~300ms red border emphasis on the study card area for **Again (1)** (compact) or typist **Miss**; not a full PRD GLSL glitch (deferred to v1.1+ per OI-03)  
- Empty queue / error / loading UX implemented  
- **Child presentation widgets** remain stateless where possible (aligned with `.cursorrules`)

### 5.4 Sentence decoder (Phase 5, PRD §8.4)

- **`lib/core/text/sentence_tokenizer.dart`** — **`SentenceTokenizer.tokenize`**: split on `[^\p{L}\p{N}'-]+` (Unicode letters/numbers; apostrophe/hyphen allowed inside tokens).  
- **`lib/features/sentence_decoder/sentence_decoder_screen.dart`** — paste pane + token **`Wrap`**; known lemmas: **cyan** border + **underline** (case-insensitive match vs DB set). Tap token → modal bottom sheet (translation) → **`insertCard`**.  
- **`main.dart`** — **`_DeckRail`**: **Sentence decoder** **`OutlinedButton`** when **`onDecoderTap != null`** (parent passes callback only if layout **wide**).

### 5.5 App entry (`lib/main.dart`)

- Bootstraps DB + seed, shows **`NexusResponsiveShell`**, deck list, card inspector, **`Study (N)`** in app bar opening **`StudySessionScreen`**, wide rail **Sentence decoder** → **`SentenceDecoderScreen`**, all with shared **`CardRepository`** (prototype; consider injection for tests).

---

## 6. Rules that must not be broken

1. **Singleton DB** — One `DatabaseHelper`; no second `openDatabase` path for app data.  
2. **UI → `CardRepository` only** — No `DatabaseHelper()` from widgets/features.  
3. **Web-safe gating** — No `dart:io` / `Platform.*` in libraries that must compile for **web**. Use **`MediaQuery` / `LayoutBuilder` / `kIsWeb`**. Breakpoint constant **840 lp** is centralized in **`NexusBreakpoints`**; typist vs compact uses **`StudyLayout.useTypistMode`**.  
4. **Atomic review persistence** — **`commitReview`** is the single logical “update card + log review” path for the study loop; keep **`insertReviewLog`** parameters consistent with FSRS rating and optional **`similarity_r`** (typist mode).  
5. **Timestamps** — DB stores unix **seconds** for `due_date`, `rated_at`, etc.; `WordCard` uses `DateTime` in Dart — keep **`toMap`/`fromMap`** consistent (see existing code).  
6. **FSRS ratings** — Integers **1–4** only (Again / Hard / Good / Easy).  
7. **Dependencies** — Do not add packages not in PRD without documenting rationale (exception: web SQLite parity already covered by `sqflite_common_ffi_web`).

---

## 7. Testing (what exists)

| File | Purpose |
|------|---------|
| `test/database_helper_test.dart` | Temp DB; round-trip; **`getLemmaSetForProfile`** + **`insertCard`** via repository; **`exportToJson`** (incl. **`app_preferences`**); **`importProfilesAndCardsFromJson`** prefs restore; **`commitReview`** + **`review_log`** / **`similarity_r`**; **`StudySessionScreen`** widget tests (compact Hit + wide typist); timed **`pump`** (no infinite **`pumpAndSettle`** with spinner) |
| `test/sentence_tokenizer_test.dart` | Tokenizer punctuation, Unicode, apostrophe, order |
| `test/fsrs_engine_test.dart` | FSRS scheduling behavior |
| `test/similarity_evaluator_test.dart` | Levenshtein / thresholds |
| `test/mastery_badge_test.dart` | Badge tiers |

**Agent note:** Widget tests that show the study loading spinner **must not** rely on **`pumpAndSettle()`** indefinitely — the progress indicator never idles.

**Windows caveat:** If **`flutter test` fails** copying **`sqlite3.dll`** into `build/native_assets` (file lock / errno 183), close processes holding the build tree, delete `build` / stale locks, retry. This is environmental, not a Dart logic error.

---

## 8. Known gaps & technical debt (safe to address in later phases)

- **`features/deck_manager/`** — No full Card CRUD / profile manager (PRD §8.1–8.2); decoder uses **minimal** create path only.  
- **`features/dashboard/`** — No mastery dashboard / heatmap yet.  
- **`window_manager`** — Not in `pubspec` (deferred post–v1.0 per PRD).  
- **Settings / configurable `S_max`** — Not implemented (OI-05 open in PRD).  
- **FSRS reference vectors** — PRD success metric mentions reference impl.; current coverage is project-specific unit tests.  
- **Web manual QA** — Chrome, Edge, Safari at multiple widths still required before a v1.0 web release (`.cursorrules`).  
- **PRD shader-grade glitch** — MVP uses border pulse only; GLSL deferred (OI-03).  
- **Sentence decoder** — No widget test yet; regex edge cases (OI-02) may need follow-up after real-language paste QA.

---

## 9. Phase 6 & 7 — For the next agent (overview)

| Track | PRD reference | Goal |
|--------|----------------|------|
| **Phase 6** | PRD §10 “Packaging”, §7.8 web browsers, §3 success metrics | Shippable **web** artifact + documented hosting; **manual QA** on Chrome, Edge, Safari; then **Windows** and **Android** release builds. |
| **Phase 7** | *Handoff-defined* (extends PRD “Later” rows) | **After** Phase 6 smoke on web: automation (CI), **§8.1–8.2** deck/profile CRUD, **§7.7** dashboard, Settings (**§8.5**), v1.1/v1.2 deferred features as approved. |

**Always run from:** `nexus_lingua/` (directory containing `pubspec.yaml`).

---

## 10. Quick file index (Phase 1–5 touchpoints)

| Area | Path |
|------|------|
| App entry | `lib/main.dart` |
| Study UI | `lib/features/study/study_session_screen.dart` |
| Sentence decoder | `lib/features/sentence_decoder/sentence_decoder_screen.dart` |
| Tokenizer | `lib/core/text/sentence_tokenizer.dart` |
| Typist vs compact gate | `lib/shared/layout/study_layout.dart` |
| Repository | `lib/core/database/card_repository.dart` |
| DB + schema | `lib/core/database/database_helper.dart` |
| Web DB factory | `lib/core/database/sqflite_platform_web.dart` |
| FSRS | `lib/core/srs/fsrs_engine.dart` |
| Evaluator | `lib/core/evaluator/similarity_evaluator.dart` |
| Theme / colors | `lib/shared/theme/app_theme.dart` |
| Breakpoint | `lib/shared/layout/nexus_breakpoints.dart` |
| Flashcard / ratings | `lib/shared/widgets/flashcard_widget.dart`, `fsrs_rating_row.dart` |

---

## 11. Implementation log (for continuity)

| Phase | Change |
|-------|--------|
| **4** | **`study_layout.dart`**; typist + **`similarity_r`**; confetti / miss pulse; study widget tests. |
| **5** | **`getLemmaSetForProfile`** / **`loadLemmaSetForProfile`**; **`CardRepository.insertCard`**; **`SentenceTokenizer`**; **`SentenceDecoderScreen`**; home rail **Sentence decoder** (wide); **`test/sentence_tokenizer_test.dart`**; DB test for lemma set + insert. |
| **6** *(in progress)* | **`flutter analyze`** + **`flutter build web --release`** + **Linux CI** workflow; study screen **lifecycle** fix (**post-frame** `_reloadQueue`), **test-only** confetti omission (**`debugOmitConfettiOverlay`** + lazy controller), **`TickerMode.valuesOf`**-gated delays; **`database_helper_test`**: **`_SeededFirstLoadRepository`**, **`StudySessionScreen` widget tests skipped on Windows** ( **`FORCE_STUDY_WIDGET_TESTS=true`** to force); handoff **§12.3–§12.7** updated. |

---

## 12. Phase 6 — Packaging playbook (PRD-aligned)

### 12.1 Preconditions

- **`flutter doctor`** — Fix **Chrome** for web; for **Windows** desktop builds, install **“Desktop development with C++”** (MSVC, Windows SDK) per doctor output. **Android** needs SDK for `.apk`.
- **Project root:** `cd nexus_lingua` before any `flutter` command (repo root has no `pubspec.yaml`).

### 12.2 Web (primary v1.0 target)

| Step | Command / action |
|------|-------------------|
| Analyze | `flutter analyze` |
| Tests | `flutter test` (see **§7**; Windows **errno 183** on `sqlite3.dll` copy → close locking apps, delete `build/`, retry) |
| Release build | `flutter build web --release` |
| Output | `build/web/` — static files only; deploy to any static host (Firebase Hosting, Netlify, GitHub Pages, S3+CloudFront, IIS, etc.) |

**Hosting notes (fill in for your environment):**

- **Base href:** If the app is served under a subpath (e.g. `https://example.com/nexus/`), build with  
  `flutter build web --release --base-href=/nexus/` (trailing slash; path must match server mount).
- **SPA routing:** Single-page Flutter web apps typically need the host to **rewrite** all paths to `index.html` (avoid 404 on refresh). Configure per provider (e.g. `firebase.json` rewrites, Netlify `_redirects`).
- **SQLite on web:** This project uses **`sqflite_common_ffi_web`** (browser-backed SQLite). After deploy, smoke-test **first load**, **reload**, **study session**, **sentence decoder** on **Chrome, Edge, Safari** (PRD §3 / §7.8). If WASM/assets fail to load, verify **correct MIME types** for `.wasm` / `.mjs` and **HTTPS** where required.
- **CORS / COOP:** Only relevant if you add cross-origin APIs later; v1.0 is local-first SQLite.

### 12.3 Manual QA matrix (copy for release notes)

PRD requires **Chrome**, **Edge (Chromium)**, **Safari**; widths **320–1920+** lp (§3 / §7.8).

**Automation snapshot (most recent agent run from `nexus_lingua/`):**

| Check | Result |
|-------|--------|
| `flutter analyze` | Pass — no issues (full package) |
| `flutter build web --release` | Pass — artifact under `build/web/` |
| `flutter test` (full package) | **Harness ready** (**`_SeededFirstLoadRepository`**, **`TickerMode(enabled: false)`**, **`runAsync` + `pump()`**). **Last agent run:** blocked on Windows when **`sqlite3.dll`** copy hits **errno 183** or the DLL is **access-denied** (locked under **`build/native_assets/windows`**). Re-run after freeing the file or on **Linux/macOS CI** (§12.7). |

**Original viewport grid (still use for manual sign-off):**

| Viewport (logical width) | Home / deck list | Study (compact vs typist at ≥840) | Sentence decoder (≥840 entry) |
|--------------------------|------------------|-----------------------------------|-------------------------------|
| ~320 (phone) | ☐ | ☐ compact row | ☐ (rail hidden; optional deep-link later) |
| ~768 (tablet) | ☐ | ☐ | ☐ |
| ≥840 (desktop) | ☐ wide shell | ☐ typist + compact check | ☐ paste + token + save |

**Manual matrix by browser (required before v1.0 web tag):**

| Viewport | Chrome | Edge | Safari |
|----------|--------|------|--------|
| ~320 — Home / deck | ☐ | ☐ | ☐ |
| ~320 — Study (compact) | ☐ | ☐ | ☐ |
| ~768 — Home / Study / Decoder | ☐ | ☐ | ☐ |
| ≥840 — Home (wide shell) | ☐ | ☐ | ☐ |
| ≥840 — Study (typist; re-check compact in narrow window) | ☐ | ☐ | ☐ |
| ≥840 — Decoder (paste → token → save card) | ☐ | ☐ | ☐ |

**Flows to verify:** cold load; **Study** due queue; **Hit/Miss** persist; **typist** submit writes **`similarity_r`**; **Decoder** token → new card → lemma highlight updates after reload; **RefreshIndicator** reload; no horizontal overflow.

### 12.4 Windows (`.exe`)

| Step | Command / action |
|------|------------------|
| Build | `flutter build windows --release` |
| Output | `build/windows/x64/runner/Release/` (or equivalent per SDK) |
| Run test | Launch `.exe`; confirm DB path under user data; study + decoder on wide window |

### 12.5 Android (`.apk` / `.aab`)

| Step | Command / action |
|------|------------------|
| Build APK | `flutter build apk --release` |
| App bundle | `flutter build appbundle --release` (Play Store) |
| Signing | Configure `key.properties` / signing in `android/app` per Flutter docs before store upload |

### 12.6 Deliverables checklist (Phase 6 “done”)

- [x] `flutter analyze` clean locally (verified; add CI in Phase 7 §13)  
- [x] `flutter test` **green** on **Linux CI**; on **Windows** run **`Stop-Process flutter_tester`** if **`sqlite3.dll`** copy fails (§12.7.1). **`StudySessionScreen` widget tests** are **skipped on Windows** by default (**`FORCE_STUDY_WIDGET_TESTS=true`** to opt in — may stall **`pump()`**).  
- [x] `flutter build web --release` succeeds; **`build/web`** produced locally  
- [ ] **`build/web`** deployed to a **test URL** (product owner / hosting)  
- [ ] QA matrix signed off for **Chrome, Edge, Safari** at **320 / 768 / ≥840** (human)  
- [ ] Short **hosting runbook** (deploy URL, `--base-href`, SPA rewrite, SQLite smoke) — §12.2 bullets or `README`  
- [ ] Optional: `flutter build windows --release` and `flutter build apk --release` artifacts built and smoke-tested  

### 12.7 Pre–Phase 6 verification snapshot *(replace dates when you re-run)*

Recorded **2026-03-22** (run from `nexus_lingua/`):

| Check | Result |
|-------|--------|
| `flutter pub get` | OK |
| `flutter analyze` | **No issues found** (full package) |
| `flutter test` (entire `test/` tree, **7 files / 29 tests** when green) | **Widget harness:** `database_helper_test.dart` uses **`_SeededFirstLoadRepository`**, **`TickerMode(enabled: false)`**, **`tester.runAsync` + `pump()`** (no **`pump(Duration)`** on study chrome). **Windows `sqlite3.dll`:** **`PathExistsException` errno 183** / *access denied* when the DLL is locked — **most often orphaned `flutter_tester.exe`** (see **§12.7.1**). **Mitigation:** `Stop-Process -Name flutter_tester -Force`, then remove **`build/native_assets/windows/sqlite3.dll`** or re-run tests; prefer **Linux/macOS CI**. |
| `flutter build web --release` | **Succeeded** → `build/web/` (Flutter may print *Wasm dry run* / `--wasm` suggestion; optional for Phase 6) |

#### 12.7.1 Windows `sqlite3.dll` — diagnosis procedure *(errno 183 / access denied)*

1. **List stray test VMs:** `Get-Process flutter_tester -ErrorAction SilentlyContinue` — if any show **`--packages=...\<this repo>\nexus_lingua\.dart_tool\package_config.json`**, they are **orphaned `flutter test` runs** (e.g. timed-out or background sessions) still mapping **`build/native_assets/windows/sqlite3.dll`**.
2. **Confirm delete is blocked:** from `nexus_lingua/`, `Remove-Item build\native_assets\windows\sqlite3.dll -Force` — *access denied* while **`flutter_tester`** is running matches this root cause.
3. **Fix (do not kill IDE `dart.exe` language-server unless you accept restarting analysis):** `Stop-Process -Name flutter_tester -Force` (optionally wait 2s), then delete **`sqlite3.dll`** or run **`flutter test`** again so the tool can recopy cleanly.
4. **Prevention:** avoid long **`flutter test`** in background without cancel; use **CI** or **`--concurrency=1`** to reduce contention; after a stuck test, always check for **`flutter_tester`** before blaming “random” errno 183.

---

## 13. Phase 7 — Post-packaging & roadmap continuation *(handoff-defined; not a separate PRD phase number)*

PRD §10 ends at **Phase 6**. Use **Phase 7** here as the **next engineering milestone** after web packaging is green.

### 13.1 Suggested priority order

1. **CI** — **`.github/workflows/flutter_ci.yml`** runs **`flutter analyze`** + **`flutter test --concurrency=1`** on **ubuntu-latest** (canonical gate; avoids Windows **`sqlite3.dll`** / **`flutter_tester`** quirks). Optionally add **`flutter build web --release`** on main.  
2. **Deck & profile management (PRD §8.1–8.2)** — Replace prototype “first profile only” in `main.dart` with real **Language Profile** CRUD and **Card** CRUD / JSON import.  
3. **Mastery dashboard (PRD §7.7)** — Heatmap, ΣS “XP”, per-language breakdown, streak.  
4. **Settings (PRD §8.5)** — Rating style, `S_max`, shader toggle, **export JSON** via **`CardRepository.exportBackupJson`** / **`DatabaseHelper.exportToJson`** (full payload includes **`app_preferences`** for theme and future keyed prefs).  
5. **v1.1+** — GLSL / glow (OI-03); **v1.2** — `window_manager` overlay (PRD deferred), Supabase sync (PRD deferred).

### 13.2 Constraints unchanged

All **§6** rules still apply: **singleton `DatabaseHelper`**, **`CardRepository`** at UI boundary, **no `dart:io`** in web-shared libraries, **840 lp** breakpoint single source in **`NexusBreakpoints`**.

### 13.3 Documentation updates after Phase 6 / 7 work

- Bump **§2** roadmap table and **§11** implementation log.  
- Add **`build/web`** / CI links to **§12.6** when known.  
- If `README.md` is expanded, keep it aligned with PRD **browser list** and **project root** `nexus_lingua/`.  
- **Persistence / backup changes:** append a **dated section** to **`docs/BACKEND_MAINTENANCE_LOG.md`** (see **`.cursorrules`** — agents are required to maintain this log).

---

## 14. Quick command reference (Phase 6 agent)

```text
cd nexus_lingua
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build windows --release
flutter build apk --release
```

---

*Last updated: **Phase 6 packaging playbook** exercised (analyze, test harness, web release); **manual browser QA + deploy URL** still open. Update §2, §11 when Phase 6 is fully signed off.*
