# Backend maintenance log (Nexus Lingua)

This project does **not** ship a separate HTTP backend. “Backend” here means **local persistence**: SQLite via `sqflite`, platform factories, backup/import, and repository boundaries. **Cursor agents are required** (see **`.cursorrules`** → `architecture.backend_maintenance_log`) to **append** a dated section here when they change that layer — never replace history.

---

## 2025-03-23 — Web release consistency pass

### Diagnosis (summary)

| Area | Finding |
|------|--------|
| **Web SQLite** | `sqflite_platform.dart` wires `databaseFactoryFfiWeb` on `dart.library.html`; `DatabaseHelper` uses `kIsWeb` + `getDatabasesPath()` (avoids `path_provider` on web). Aligned with PRD / handoff. |
| **Backup JSON** | `exportToJson` omitted `app_preferences`, so **theme mode** (and any future keyed prefs in SQLite) was not restored on import — inconsistent for web users who rely on DB-backed theme. |
| **Repository vs raw SQL** | `CardRepository` queried `language_profiles` via `_db.getDatabase()` for prototype helpers; duplicated logic that belongs in `DatabaseHelper` per “no raw SQL outside helper” rule. |
| **`sqflite_platform.dart`** | File used CRLF-only line endings; normalized to LF for consistent tooling. |

### Actions taken

1. **`DatabaseHelper.exportToJson`** — Added `app_preferences` to the export payload (same shape as other tables: list of row maps).
2. **`DatabaseHelper.importProfilesAndCardsFromJson`** — If `app_preferences` is present in the JSON, rows are upserted (`ConflictAlgorithm.replace`) inside the existing transaction. **`review_log` remains intentionally not imported** (append-only history). Return type is now a **named record**: `({int profiles, int cards, int preferences})`.
3. **`DatabaseHelper`** — Added `getFirstProfile()` and `getCardsForFirstProfile()` so the repository does not open the DB handle for ad-hoc queries.
4. **`CardRepository`** — `firstProfile` / `loadFirstProfileCards` delegate to the new helper methods; `importBackupProfilesAndCards` exposes the new record return type.
5. **`deck_manager_screen.dart`** — SnackBar text includes preference count when `preferences > 0`.
6. **Tests** — `exportToJson` test asserts `app_preferences` key; new test covers import restoring `theme_mode`.
7. **This log** — Created under `docs/BACKEND_MAINTENANCE_LOG.md`.

### Deferred: Windows 11 desktop release

- **DB path**: Already uses `getApplicationDocumentsDirectory()` + `nexus_lingua.db` (same schema as web).
- **Backup file**: `backup_export_io.dart` writes next to app documents; verify UX (path disclosure, overwrite) before shipping.
- **FFI / locks**: VM tests document Windows file-lock quirks; run `flutter test` / integration on Win11 before release.
- **Future**: PRD mentions `window_manager` overlay (v1.2+) — no DB impact expected.

### Deferred: Android release

- **Same** `path_provider` + SQLite path as Windows for native open path.
- **Scoped storage / backups**: Confirm `file_picker` + export path behavior on API 30+; may need SAF or user-visible folder choice.
- **WebView / WASM**: N/A on Android (native `sqflite`).

### Release checklist (web)

- [ ] `flutter analyze` clean.
- [ ] `flutter test` (CI or local).
- [ ] `flutter build web` — confirm first load opens DB (IndexedDB via `sqflite_common_ffi_web`).
- [ ] Manual: export backup → re-import → theme and decks match expectations.

---

## How to extend this log

Add a new `## YYYY-MM-DD — <short title>` section with **Diagnosis**, **Actions**, and **Follow-ups**. Link to PRs or commits when available.
