# NEXUS LINGUA
## Universal Vocabulary Engine — Product Requirements Document

| Field | Value |
|---|---|
| **Version** | v1.0 — Initial Release |
| **Platform** | **Web (primary)** · Windows 11 · Android |
| **Stack** | Flutter (Dart) + SQLite (+ web-compatible DB factory) + FSRS |
| **Browser QA (v1.0)** | Google Chrome, Microsoft Edge (Chromium), Apple Safari |
| **Author** | Lead Architect / Product Manager |
| **Status** | Draft — For Development |

> *"Vocabulary is not memorized. It is engineered."*

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Product Vision & Goals](#3-product-vision--goals)
4. [Mathematical Model & Core Logic](#4-mathematical-model--core-logic)
5. [Testing & Evaluation Logic](#5-testing--evaluation-logic)
6. [Database Architecture](#6-database-architecture)
7. [UI / UX Design System](#7-ui--ux-design-system)
8. [Functional Modules](#8-functional-modules)
9. [Technical Stack & Architecture](#9-technical-stack--architecture)
10. [Development Roadmap](#10-development-roadmap)
11. [Cursor Initialization Prompt Sequence](#11-cursor-initialization-prompt-sequence)
12. [Open Issues & Decisions](#12-open-issues--decisions)
- [Appendix A: Feature Glossary](#appendix-a-feature-glossary)

---

## 1. Executive Summary

Nexus Lingua is a local-first, cross-platform vocabulary learning application built for power users who treat language acquisition as a structured, data-driven discipline. Unlike conventional flashcard applications that apply a one-size-fits-all model, Nexus Lingua treats vocabulary as a mathematically modeled dynamic dataset — flexible enough to represent any human language's unique structural properties, yet rigorous enough to guarantee optimal retention through algorithmic scheduling.

The application is designed and maintained by a single developer with a mathematics background, built in Flutter for **Web (first shipping target for v1.0)**, Windows 11, and Android. The **web** build must be fully functional (persistent local data, study flows, CRUD), **responsive** across phone-, tablet-, and desktop-class viewports, and **manually verified** on **Chrome**, **Edge**, and **Safari**. Native apps follow in priority after the web experience is stable. The product's aesthetic identity is **Cyber-Minimalist**: obsidian backgrounds, neon cyan/magenta accents, gamified progress feedback, and shader-driven animations — visual language borrowed from the gamer world to create a study environment that feels alive, not clinical.

---

## 2. Problem Statement

### 2.1 Core Problem

Existing flashcard applications (Anki, Quizlet, Duolingo) fail power users in three critical ways:

- **Schema rigidity:** A single vocabulary model cannot accurately represent the structural divergence between, e.g., a highly inflected language like Hungarian and an analytic language like Mandarin. Most apps hardcode fields or ignore them entirely.
- **Suboptimal SRS:** Many tools use SM-2 (a 1987 algorithm). The modern FSRS algorithm, trained on millions of reviews, produces materially better scheduling — but is available in few native mobile/desktop applications.
- **Engagement deficit:** Study sessions feel utilitarian. There is no progression feedback, no achievement system, and no visual dynamism that reinforces the habit loop.

### 2.2 Target User

The primary user is a dedicated self-learner or polyglot who manages multiple target languages simultaneously, expects granular control over their vocabulary data schema, and is comfortable with structured tools. Secondary users include linguistics students and academic researchers who need language-agnostic data structures.

---

## 3. Product Vision & Goals

### 3.1 Vision Statement

To be the definitive vocabulary engineering platform for serious language learners — where any word in any language can be precisely represented, rigorously tested, and efficiently retained.

### 3.2 Success Metrics (v1.0)

| Metric | Target | Measurement Method |
|---|---|---|
| Card CRUD latency | < 100ms | Flutter DevTools profiling |
| FSRS scheduling accuracy | Matches reference impl. | Unit test against FSRS test vectors |
| Levenshtein evaluator | Correct threshold mapping | Unit tests (>20 word samples) |
| App launch time | < 2s cold start | Stopwatch on target devices |
| SQLite query (1000 cards) | < 50ms | Profiling with sqflite_common (native); web: best-effort with web DB impl. |
| Cross-platform parity | Feature-identical Web / Win / Android | Manual QA checklist (web first) |
| Web responsiveness | No horizontal overflow; usable at 320–1920+ CSS px | Chrome, Edge, Safari + DevTools device modes |
| Web browsers | No critical breakage | Smoke + study session on Chrome, Edge, Safari |

---

## 4. Mathematical Model & Core Logic

### 4.1 The Vocabulary Set

The full vocabulary corpus **C** is a set of *n* word cards:

$$C = \{card_1, card_2, \dots, card_n\}$$

### 4.2 Language Profile

Each language **L** is governed by a Language Profile **P_L**, defined as an active feature set:

$$F = \{f_1, f_2, \dots, f_n\} \quad \text{where} \quad f_i \in \{\text{Gender, Conjugation, Plural, Case, Tense, CaseSensitive}\}$$

The Language Profile acts as a configuration layer: activating a feature causes it to appear in the card UI and database schema; disabling it hides and ignores it. This is the core mechanism that makes Nexus Lingua language-agnostic.

### 4.3 The Word Card Tuple

Each Word Card **C** is a 4-tuple:

$$C = (L,\ T,\ M,\ \phi)$$

| Component | Type | Description |
|---|---|---|
| **L** | String | Lemma — the primary form of the word being learned |
| **T** | String | Translation — the target-language equivalent |
| **M** | SRS State | Mastery State — contains Stability (S), Difficulty (D), Retrievability (R), and next-review timestamp |
| **φ** | `Map<String, dynamic>` | Metadata mapping φ: F → Value — stores all active language-specific features as a JSON-encoded dictionary |

### 4.4 FSRS Mastery Function

The Spaced Repetition schedule is governed by the **FSRS algorithm** (Free Spaced Repetition Scheduler). Three state variables are maintained per card:

- **Stability (S):** The number of days after a review at which Retrievability decays to 0.9. Higher S means a longer retention half-life.
- **Difficulty (D):** A value on a 1–10 scale reflecting the intrinsic difficulty of the card, updated with each review.
- **Retrievability (R):** The real-time probability of correct recall, defined as:

$$R(t) = 0.9^{(t/S)}$$

where *t* is the number of elapsed days since last review.

User ratings map to FSRS input buttons: **Again (1)**, **Hard (2)**, **Good (3)**, **Easy (4)**. The FSRS algorithm uses these to update S, D, and schedule the next review date.

---

## 5. Testing & Evaluation Logic

### 5.1 Typist / Wide Study Mode — Similarity Evaluator

On **wide layouts** (native Windows app **or** web browser above the responsive breakpoint — see §7.8), the app uses an automated text **similarity evaluator** instead of the 4-button self-rating row. The user types their answer, and the system computes a normalized score against the target lemma.

#### 5.1.1 Similarity Ratio Formula

The similarity ratio **R** is computed using Normalized Levenshtein Distance:

$$R = 1 - \frac{d\bigl(T(U,p),\ T(T,p)\bigr)}{\max(\text{len}(U),\ \text{len}(T))}$$

The case-transformation function **T(s, p)** is:

$$T(s, p) = \begin{cases} s & \text{if } p = \text{true (case-sensitive)} \\ \text{lowercase}(s) & \text{if } p = \text{false} \end{cases}$$

The boolean property **p** (`case_sensitive`) is stored in the card's φ metadata map and is configured per language in the Language Profile.

#### 5.1.2 Threshold-to-FSRS Mapping

| Ratio (R) | FSRS Button | Display Label | UI Color | Interpretation |
|---|---|---|---|---|
| R = 1.0 | Easy (4) | Crit! | Neon Green `#00E676` | Perfect precision — zero typos |
| 0.85 ≤ R < 1.0 | Good (3) | Hit | Light Green `#69F0AE` | 1 small typo (medium word) or 2 in a long word |
| 0.65 ≤ R < 0.85 | Hard (2) | Hard | Amber `#FFD740` | Correct vibe, shaky spelling |
| R < 0.65 | Again (1) | Miss | Neon Red `#FF5252` | Significant structural error or wrong word |

#### 5.1.3 SimilarityEvaluator Class Contract (Dart)

The `SimilarityEvaluator` class must be implemented in Dart with the following responsibilities:

- `computeLevenshtein(String a, String b): int` — Pure Levenshtein edit distance using dynamic programming.
- `computeRatio(String userInput, String target, bool caseSensitive): double` — Applies `T(s,p)` transformation and returns R ∈ [0.0, 1.0].
- `mapToFSRS(double ratio): int` — Returns 1, 2, 3, or 4 based on the threshold table above.
- `evaluate(String userInput, WordCard card): EvaluationResult` — Full pipeline: reads `caseSensitive` from `card.φ`, computes ratio, returns structured result with ratio, label, and FSRS button.

### 5.2 Compact Study Mode — Confidence-Based Rating

On **Android** and on **narrow web** viewports (and whenever the shell selects compact study mode), the app presents a standard 4-button Anki-style self-rating interface. The buttons are gamified with customizable display modes, configurable in Settings:

| FSRS Button | Default Label | Symbol | Color |
|---|---|---|---|
| Again (1) | Miss | ✕ | Neon Red `#FF5252` |
| Hard (2) | Hard | ↑ (short) | Amber `#FFD740` |
| Good (3) | Hit | ↑↑ (mid) | Light Green `#69F0AE` |
| Easy (4) | Crit! | ↑↑↑ (long) | Neon Green `#00E676` |

---

## 6. Database Architecture

### 6.1 Schema Design Philosophy

The database uses a **hybrid schema**: fixed columns for universal card properties, and a single `TEXT` column containing JSON for all language-specific metadata. This approach avoids schema migrations when new language features are introduced, while maintaining the performance benefits of SQLite for core queries.

**Web:** Flutter Web does not embed native SQLite the same way as mobile/desktop; v1.0 uses a **supported `sqflite`-compatible initialization path for web** (e.g. WASM / browser-backed storage) so the **same SQL schema, `DatabaseHelper` API, and queries** apply on all platforms. Persisted data must survive normal reloads within browser storage policies.

### 6.2 SQLite Table Definitions

#### Table: `language_profiles`

```sql
CREATE TABLE language_profiles (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  language    TEXT    NOT NULL,  -- e.g. 'German', 'Japanese'
  features    TEXT    NOT NULL,  -- JSON array of active feature keys
  created_at  INTEGER NOT NULL   -- Unix timestamp
);
```

#### Table: `word_cards`

```sql
CREATE TABLE word_cards (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  profile_id      INTEGER NOT NULL REFERENCES language_profiles(id),
  lemma           TEXT    NOT NULL,  -- Primary string (L)
  translation     TEXT    NOT NULL,  -- Target language (T)
  stability       REAL    NOT NULL DEFAULT 1.0,   -- S (days)
  difficulty      REAL    NOT NULL DEFAULT 5.0,   -- D (1.0–10.0)
  retrievability  REAL    NOT NULL DEFAULT 1.0,   -- R (probability)
  due_date        INTEGER NOT NULL DEFAULT 0,     -- Unix timestamp
  review_count    INTEGER NOT NULL DEFAULT 0,
  metadata        TEXT    NOT NULL DEFAULT '{}',  -- JSON: phi map
  created_at      INTEGER NOT NULL
);
```

#### Table: `review_log`

```sql
CREATE TABLE review_log (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id       INTEGER NOT NULL REFERENCES word_cards(id),
  rated_at      INTEGER NOT NULL,  -- Unix timestamp
  rating        INTEGER NOT NULL,  -- 1=Again, 2=Hard, 3=Good, 4=Easy
  similarity_r  REAL,              -- Typist/wide mode only; NULL in compact mode
  s_before      REAL NOT NULL,
  s_after       REAL NOT NULL
);
```

### 6.3 The Metadata JSON Bridge

The `metadata` column is the core of Nexus Lingua's schema-less flexibility. Its lifecycle:

1. **On card creation:** Dart reads the active `LanguageProfile`'s feature set F and constructs an initial φ map, e.g. `{ "gender": null, "plural": null, "case_sensitive": false }`.
2. **On write (`toMap()`):** The `Map<String, dynamic>` is serialized via `jsonEncode()` and stored as `TEXT` in the `metadata` column.
3. **On read (`fromMap()`):** The `TEXT` string is deserialized via `jsonDecode()` and cast back to `Map<String, dynamic>`.
4. **At render time:** The UI reads the active `LanguageProfile` to know which keys to display. Unknown keys from inactive profiles are preserved but ignored.

**Example — German profile metadata:**

```json
{
  "gender": "masculine",
  "plural": "die Häuser",
  "case": ["nominative", "accusative"],
  "case_sensitive": false
}
```

### 6.4 DatabaseHelper Pattern

`DatabaseHelper` must be implemented as a **Singleton**. It is the exclusive interface to the SQLite database — no other class holds a database reference.

| Method | Signature | Responsibility |
|---|---|---|
| `getInstance` | `DatabaseHelper` | Returns the single static instance |
| `getDatabase` | `Future<Database>` | Lazy-initializes the SQLite connection on first call |
| `insertCard` | `Future<int>` | Serializes φ via `toMap()` and inserts |
| `getCardsForProfile` | `Future<List<WordCard>>` | Deserializes all cards for a profile |
| `updateCardAfterReview` | `Future<void>` | Updates S, D, R, `due_date`, and `review_count` |
| `getDueCards` | `Future<List<WordCard>>` | Returns cards where `due_date` ≤ now |
| `exportToJson` | `Future<String>` | Full export for backup (always available, no auth required) |

---

## 7. UI / UX Design System

### 7.1 Cyber-Minimalist Theme

| Token | Value | Usage |
|---|---|---|
| Background Primary | `#0D0D0D` (Obsidian) | App background, card backs |
| Accent Cyan | `#00BCD4` | Borders, masculine gender, interactive elements |
| Accent Magenta | `#E91E8C` | Feminine gender, warning states |
| Accent Green | `#00E676` | Neuter gender, success states |
| Glassmorphic Surface | `rgba(255,255,255,0.05)` | Card front surfaces, dialog overlays |
| Neon Red | `#FF5252` | Miss / Again feedback |
| Amber | `#FFD740` | Hard feedback |
| Body Text | `#E0E0E0` | Primary content text |
| Subtext | `#777777` | Secondary labels |

### 7.2 State-Based Gender Coloring

The card's primary neon border color is a function of the word's gender metadata:

$$f(\text{Masculine}) = \text{Neon Cyan } \texttt{\#00BCD4}$$
$$f(\text{Feminine}) = \text{Neon Magenta } \texttt{\#E91E8C}$$
$$f(\text{Neuter}) = \text{Neon Green } \texttt{\#00E676}$$
$$f(\text{None / Undefined}) = \text{Neutral Gray } \texttt{\#555555}$$

This is implemented at render time by reading the `gender` key from the card's φ map and selecting the corresponding `BoxDecoration` border color. Cards from languages without gender use the neutral color.

### 7.3 The Flashcard Widget

The card uses a **Box Method** layout — a tree of nested rectangular containers. It is a dynamic grid that expands from 2×2 to 3×2 depending on the number of active metadata fields in the Language Profile:

- **Minimum layout (2×2):** Lemma, Translation, XP Bar (Stability), Mastery Badge.
- **Extended layout (3×2):** Adds rows for Gender/Category, Plural/Conjugation, or other active features.
- The grid adapts at runtime by iterating the active feature list from the `LanguageProfile` and conditionally rendering metadata cells.

### 7.4 Gamification System

#### XP Bar (Stability Visualizer)

A `LinearProgressIndicator` at the bottom of each card. Its value is computed as:

$$\text{progress} = \min\!\left(\frac{S}{S_{\max}},\ 1.0\right)$$

where `S_max` is a user-configurable constant (default: 365 days). The bar color transitions from dim to bright neon as S increases.

#### Mastery Level Badges

| Badge | Stability Range (S) | Level Range | Color |
|---|---|---|---|
| Novice | 0 – 1 day | 1–10 | Gray |
| Apprentice | 1 – 7 days | 11–20 | Cyan |
| Journeyman | 7 – 30 days | 21–30 | Green |
| Elite | 30 – 120 days | 31–40 | Magenta |
| Legend | 120+ days | 41+ | Gold `#FFD700` |

#### Visual Feedback Effects

- **Crit! (Perfect Match / Easy):** Confetti particle burst using the `confetti` Flutter package.
- **Glitch Effect:** On-miss shader-distortion flicker for 300ms.
- **Shader Glow Pulse:** Neon border brightness is a function of Stability S. Words with S > 30 days pulse with a live glow. New cards (S < 1) have a dim, static border.

### 7.5 Wide Layout — Multi-Panel Dashboard (Web + Windows 11)

When viewport width is at or above the **wide breakpoint** (default **840 logical pixels**, aligned with project rules), use a full-dashboard view with three panels:

- **Left Panel:** Navigation rail — Deck list by Language Profile, Today's Due count badge, Settings access.
- **Center Panel:** Primary study area — Flashcard widget with text input for **Typist / SimilarityEvaluator** flow.
- **Right Panel:** Card inspector — Full metadata view, edit controls, review history graph.

This layout applies to **desktop-class web** (Chrome, Edge, Safari) and to the **Windows 11** app at sufficient window width.

### 7.6 Compact Layout — Single Column (Android + Narrow Web)

Below the wide breakpoint, or on phone-first native Android, use a single-column view:

- **Top:** Card counter (e.g., `12 / 47 remaining`).
- **Center:** Flashcard widget (tap to flip; avoid overflow — scroll if needed on small web viewports).
- **Bottom:** 4-button rating row in the configured display style (label, symbol, or color-only).

### 7.7 Mastery Dashboard

A dedicated screen showing:

- **Study Heatmap:** A GitHub-style calendar grid showing review activity intensity per day.
- **Total XP:** Aggregate of all card Stability values (ΣS), displayed as a global score.
- **Per-language breakdown:** Cards by badge tier per active Language Profile.
- **Streak counter:** Consecutive days with at least one review.

### 7.8 Responsive Web & Browser Support (v1.0)

- **Targets:** **Google Chrome**, **Microsoft Edge** (Chromium), and **Apple Safari** (desktop and/or iOS per Flutter web support for the chosen SDK).
- **Responsive:** Layouts must adapt smoothly from narrow (single column, large touch targets) to wide (multi-panel). Use `LayoutBuilder` / `MediaQuery` breakpoints — no reliance on fixed pixel desktop widths.
- **Alive:** Maintain Cyber-Minimalist motion where performant (confetti, glitch, glow); prefer `CustomPainter` / standard Flutter animations on web; defer heavy GLSL to v1.1+.
- **Keyboard / input:** On web typist mode, ensure focus management and Enter-to-submit (or explicit submit) work; avoid obscuring the input with on-screen chrome on mobile browsers.
- **QA order for v1.0:** Web (three browsers, multiple widths) → Windows 11 → Android.

---

## 8. Functional Modules

### 8.1 Language Profile Manager

Allows users to create, edit, and delete Language Profiles. Each profile configures the active feature set F. The UI presents all known features as a checklist; toggling a feature activates it for all new cards created under that profile.

### 8.2 Card CRUD Manager

Full create, read, update, delete for `WordCard`s. The form is dynamically generated from the active profile's feature set — only active fields are shown. Supports bulk import from JSON.

### 8.3 Study Session Engine

Orchestrates a study session in sequence:

1. Load due cards from `DatabaseHelper.getDueCards()`.
2. Present card (front = lemma; back = translation + metadata).
3. **Typist / wide study mode:** Accept text input, run `SimilarityEvaluator`, display result + auto-rating.
4. **Compact study mode:** Display 4-button rating row; await user selection.
5. Call FSRS logic with rating; compute new S, D, R, next `due_date`.
6. Write updated card to DB. Append `review_log` entry.
7. Trigger visual feedback (confetti, glitch, glow update).
8. Advance to next card.

### 8.4 Sentence Decoder (Wide Layout — Web + Windows)

When the shell is in **wide layout** (§7.5), provide a split-screen view (including **desktop web** in Chrome, Edge, and Safari):

- **Left pane:** Multi-line text input for pasting source-language text.
- **Right pane:** Tokenized word list. Tokenization uses Dart-native regex splitting on whitespace/punctuation for MVP.
- Each token is tappable: tapping pre-fills the Card CRUD form with the lemma for one-click card creation.
- Tokens already in the database are highlighted with a cyan underline.

### 8.5 Settings Module

| Setting | Type | Description |
|---|---|---|
| Mobile Rating Style | Enum (Labels / Symbols / Colors) | Switches the mobile 4-button display mode |
| S_max (XP normalization) | Numeric input | Maximum stability value for XP bar normalization (default: 365) |
| Shader Effects | Toggle | Enable/disable glow pulse and particle effects |
| Backup to File | Action button | Exports full DB to a JSON file at user-chosen path |
| Cloud Sync (Beta) | Toggle (v1.2+) | Enables Supabase mirroring after authentication |

---

## 9. Technical Stack & Architecture

### 9.1 Stack Summary

| Layer | Technology | Rationale |
|---|---|---|
| Frontend / UI | Flutter (Dart) | Single codebase for **Web (primary v1.0)**, Win11, Android; responsive breakpoints; `CustomPainter` for MVP effects |
| Local Database | SQLite via `sqflite` (+ web factory) | Same schema everywhere; web uses a supported browser-backed SQLite init path |
| SRS Algorithm | FSRS (custom Dart impl.) | State-of-the-art scheduling; superior to SM-2 for retention |
| String Evaluation | Levenshtein (Dart) | Native Dart; no dependencies; unit-testable |
| Text Tokenization | Dart Regex (MVP) | Zero dependencies; sufficient for MVP; upgradable to NLP package |
| Cloud Sync (v1.2+) | Supabase Free Tier | Postgres mirror of SQLite; free tier sufficient for single user |
| Window Management | `window_manager` (Flutter pkg) | Enables always-on-top overlay mode on Windows (v1.2+) |
| Particle Effects | `confetti` (Flutter pkg) | Lightweight confetti animation for Crit! feedback |

### 9.2 Architecture Principles

- **Singleton Pattern:** `DatabaseHelper` is instantiated exactly once. All DB calls go through it.
- **Repository Pattern:** A `CardRepository` class wraps `DatabaseHelper`, providing a clean async API to the UI layer. UI never calls `DatabaseHelper` directly.
- **Study mode selection (web-safe):** Gate typist vs compact study by **viewport width** (and optional native Android compact rule). Do **not** use `dart:io` `Platform` in code that compiles for web — use `MediaQuery` / `LayoutBuilder` and `kIsWeb` from `flutter/foundation.dart` as needed.
- **Stateless Widgets First:** Study session state managed via a `StatefulWidget` session controller; all child card widgets are stateless.
- **JSON Metadata Invariant:** The `metadata` column is never parsed at the SQL layer. All JSON encode/decode happens in Dart. SQL only stores and retrieves opaque text.

---

## 10. Development Roadmap

| Phase | Name | Deliverables | Priority |
|---|---|---|---|
| Phase 1 | Foundation | Flutter project init (Cursor), web + native targets enabled, SQLite schema, web DB init, `DatabaseHelper` Singleton, `WordCard` / `LanguageProfile` models | Critical |
| Phase 2 | Cyber UI | Theme system (colors, fonts), responsive shell (wide vs compact), `FlashcardWidget` with dynamic grid, gender borders, XP bar, badges | Critical |
| Phase 3 | SRS Engine | FSRS Dart class (S, D, R update functions), study session controller, `review_log` write, due card query | Critical |
| Phase 4 | Evaluation & Input | `SimilarityEvaluator`, typist text flow (web + wide native), compact 4-button flow, particle effects | Critical |
| Phase 5 | Text Processing | Sentence Decoder on wide layout (web + Windows), regex tokenizer, DB highlight, one-click card from token | High |
| Phase 6 | Packaging | **`flutter build web`** + hosting notes; browser QA (Chrome, Edge, Safari); then `.exe` (Win11) and `.apk` (Android) | High |
| v1.2 — Later | Overlay Mode | `window_manager` always-on-top mini-window for Windows | Deferred |
| v1.2 / v2.0 — Later | Cloud Sync | Supabase integration, auth flow, JSON backup, sync toggle in Settings | Deferred |

---

## 11. Cursor Initialization Prompt Sequence

Execute these prompts in Cursor in order, one at a time.

---

### Prompt 1 — Project & Dependency Scaffold

```
Create a new Flutter project called "nexus_lingua". Enable Web, Windows, and Android.
Configure pubspec.yaml with: sqflite (latest), path (latest), path_provider (latest),
confetti (latest), plus any current, documented sqflite-compatible package needed for
SQLite on Flutter Web (add with a one-line rationale). Create the following directory
structure under lib/:
  core/database/
  core/models/
  core/srs/
  core/evaluator/
  features/study/
  features/deck_manager/
  features/dashboard/
  features/sentence_decoder/
  shared/widgets/
  shared/theme/
Do not generate any UI yet. Only scaffold the folders and an empty main.dart with a
placeholder MaterialApp.
Use LayoutBuilder or a custom ResponsiveLayout widget: at width >= 840 logical pixels,
use the 3-panel wide dashboard shell; below that, single-column compact shell.
Study mode must not import dart:io Platform for web compatibility — use breakpoints
(and kIsWeb only if needed). Prioritize `flutter run -d chrome` for early verification.
```

---

### Prompt 2 — Data Models

```
In lib/core/models/, create two Dart classes.

(1) LanguageProfile: fields id (int?), language (String), features (List<String>),
createdAt (DateTime). Implement toMap() and fromMap() for SQLite serialization.
The features list must be JSON-encoded for storage.

(2) WordCard: fields id (int?), profileId (int), lemma (String), translation (String),
stability (double, default 1.0), difficulty (double, default 5.0), retrievability
(double, default 1.0), dueDate (DateTime), reviewCount (int, default 0),
metadata (Map<String, dynamic>, default {}), createdAt (DateTime).
Implement toMap() (with jsonEncode for metadata) and fromMap() (with jsonDecode
for metadata). Both classes must be null-safe.
```

---

### Prompt 3 — DatabaseHelper Singleton

```
In lib/core/database/database_helper.dart, implement a Singleton class DatabaseHelper.
It must use a private constructor and a static _instance field. Implement an async
_initDb() method that opens a SQLite database called 'nexus_lingua.db' (using the
correct factory on Web vs native) and runs onCreate to execute the three CREATE TABLE
statements for language_profiles, word_cards, and review_log as specified in the PRD schema.
Implement the following async methods:
insertProfile, insertCard, getCardsForProfile, getDueCards, updateCardAfterReview,
insertReviewLog, exportToJson. All methods must use the singleton database reference
via getDatabase().
```

---

### Prompt 4 — FSRS Engine

```
In lib/core/srs/fsrs_engine.dart, implement a class FSRSEngine. It must implement
the official FSRS-4.5 algorithm with the following:

(1) A schedule(WordCard card, int rating, DateTime now) method that returns a new
WordCard with updated stability, difficulty, retrievability, and dueDate.

(2) Stability update: use the FSRS stability formulas for new cards (first review)
and review cards (subsequent reviews), parameterized by the 17 FSRS weights
(use the published FSRS-4.5 default weights).

(3) Difficulty update: use the FSRS difficulty formula.

(4) Retrievability: computed as R(t) = 0.9^(t/S) where t is days elapsed since
last review.

(5) Next due date: calculated as now + Duration(days: S.round()).

(6) Default Weights: [
  0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 
  0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61
]

Include inline comments referencing the FSRS paper equations.
```

---

### Prompt 5 — Similarity Evaluator

```
In lib/core/evaluator/similarity_evaluator.dart, implement a class SimilarityEvaluator
with the following pure functions:

(1) int computeLevenshtein(String a, String b) — standard dynamic programming
Levenshtein distance.

(2) double computeRatio(String userInput, String target, bool caseSensitive) —
applies lowercase() if !caseSensitive, then returns:
  R = 1 - (levenshtein / max(a.length, b.length))
Clamp result to [0.0, 1.0].

(3) int mapToFSRS(double ratio) — returns 4 if ratio == 1.0, 3 if >= 0.85,
2 if >= 0.65, else 1.

(4) EvaluationResult evaluate(String userInput, WordCard card) — reads caseSensitive
from card.metadata, runs the pipeline, returns a record with ratio (double),
fsrsRating (int), and label (String: 'Crit!', 'Hit', 'Hard', 'Miss').

Write 10 unit tests covering boundary conditions.
```

---

### Prompt 6 — Cyber Flashcard Widget

```
In lib/shared/widgets/flashcard_widget.dart, create a StatelessWidget called FlashcardWidget.

Layout: Use the "Box Method" with a Card containing a Column.

Dynamic Grid: The central metadata section must use a Wrap widget or GridView.builder that iterates through card.metadata.keys.

Logic: Cross-reference keys against the active LanguageProfile.features. Only render metadata cells for keys that exist in the current profile.

Styling: Apply the "Cyber-Minimalist" theme: Obsidian background, glassmorphic surfaces, and a neon border whose color is determined by the gender key in metadata (Cyan for masc, Magenta for fem, Green for neuter).
```

---

## 12. Open Issues & Decisions

| ID | Issue | Status | Decision |
|---|---|---|---|
| OI-01 | FSRS weight initialization: use published FSRS-4.5 defaults or allow user customization? | Open | Use defaults for v1.0. User-tunable weights deferred to v1.2. |
| OI-02 | Tokenization: Regex MVP vs. Dart NLP package (e.g., `nlp_tokenizer`)? | Open | Regex for MVP. Evaluate `dart_nlp` package post-Phase 4 if regex fails edge cases. |
| OI-03 | Shader implementation: Flutter fragment shaders (GLSL) vs. `CustomPainter` animation? | Open | `CustomPainter` for MVP (no tooling overhead). GLSL shaders in v1.1 iteration. |
| OI-04 | Heatmap widget: build custom or use `fl_chart` / `calendar_view` package? | Open | Evaluate `calendar_view` package first. Custom fallback if license or style conflicts. |
| OI-05 | S_max constant for XP bar: hardcoded or settings-configurable? | Open | Configurable in Settings, default 365 days. |
| OI-06 | Flutter Web SQLite: which supported `sqflite`-compatible factory/package for v1.0? | Open | Pick current maintained option (WASM/IndexedDB); document in pubspec + README; verify Chrome, Edge, Safari. |

---

## Appendix A: Feature Glossary

| Term | Definition |
|---|---|
| **Lemma (L)** | The dictionary/base form of a word, used as the primary lookup key. |
| **Translation (T)** | The user's native-language equivalent of the lemma. |
| **Stability (S)** | FSRS variable: days until retrievability decays to 90% after a successful review. |
| **Difficulty (D)** | FSRS variable: intrinsic card difficulty, on a 1.0–10.0 scale. |
| **Retrievability (R)** | FSRS variable: real-time probability of correct recall. R = 0.9^(t/S). |
| **Language Profile (P_L)** | A configuration object that defines which linguistic features are active for language L. |
| **Metadata Map (φ)** | A JSON-encoded dictionary stored per card that maps active feature keys to their values. |
| **FSRS** | Free Spaced Repetition Scheduler — a modern SRS algorithm trained on 20M+ reviews. |
| **Levenshtein Distance** | Minimum edit distance (insertions, deletions, substitutions) between two strings. |
| **Similarity Ratio (R)** | Normalized Levenshtein score in [0, 1]. 1.0 = perfect match. |
| **XP Bar** | A linear progress bar representing normalized Stability S/S_max for a word card. |
| **Mastery Badge** | A tier label (Novice → Legend) assigned based on Stability thresholds. |
| **Typist / wide study mode** | Layout-wide study flow: typed answer + `SimilarityEvaluator` → FSRS rating. |
| **Compact study mode** | Narrow layout or compact native: user picks Again/Hard/Good/Easy manually. |

---

*END OF DOCUMENT — Nexus Lingua PRD v1.0*
