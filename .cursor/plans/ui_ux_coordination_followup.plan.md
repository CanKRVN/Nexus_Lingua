---
name: UI/UX coordination — QA follow-up + diagnosis
overview: Splits ownership between the principal agent (automation, token fixes, diagnosis gates) and the UI/UX developer agent (optional polish backlog). Supersedes follow-up items from the inspection plan; the original audit remains in `ui_ux_inspection_and_roadmap_cd0c8740.plan.md` (user `.cursor/plans/`).
todos: []
isProject: true
---

# Nexus Lingua — UI/UX coordination (post–inspection plan)

## Principal agent (this track) — owned tasks


| Task                                                                                                                                                | Status                |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| Align dark `ColorScheme.primary` / spectral easy-node cyan to PRD `#00BCD4` (`theme_constants.dart`, `spectral_hud_tokens.dart`, `.cursorrules` §2) | Done in repo          |
| Remove per-row `BackdropFilter` on dashboard tier blades (flat glass + left rail)                                                                   | Done                  |
| Introduce `NexusGlowFilledButton` / `NexusGlowFilledButtonIcon` and wire primary CTAs when `effectsEnabled`                                         | Done                  |
| Add `test/study_layout_test.dart` for typist width/height gates                                                                                     | Done                  |
| Update `UI_ROADMAP.md` §2b to match tokens and UI-G partial scope                                                                                   | Done                  |
| **Diagnosis gate:** `flutter analyze`, `flutter test`, `flutter build web --release` on `nexus_lingua/`                                             | Run each release / PR |


## UI/UX developer agent — remaining backlog


| ID            | Task                                                                                                              | Status                                                                                                  |
| ------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **UI-R2**     | Optional `NavigationBar` on compact width; `ConstrainedBox` max body width for `NexusLayoutClass.large`           | **Done** in repo (`nexus_compact_nav_bar.dart`, `NexusPageScaffold` + `maxContentWidthLp`)              |
| **UI-A11y**   | Focus rings on neon controls, contrast notes for magenta on obsidian, respect reduced motion beyond study effects | **Done** (`nexus_a11y.dart`, theme `ButtonStyle` focus `side`, `NexusMotion.preferStaticMotion` wiring) |
| **UI-G+**     | Donut or stacked bar for per-profile tier totals; further chart polish without hurting web performance            | **Done** (`dashboard_tier_donut.dart` — `CustomPainter` only, no extra `BackdropFilter`)                |
| **QA manual** | Browser pass at 320 / 390 / 768 / 1024 / 1440+ per `UI_ROADMAP` §3 (screenshots + overflow log)                   | **Template** in `UI_ROADMAP.md` §3b — human fills rows per release                                      |


## References

- Inspection baseline: [UI_ROADMAP.md](../../UI_ROADMAP.md) §2b, §3–§6
- Breakpoints: `nexus_lingua/lib/shared/layout/nexus_breakpoints.dart`
- Glow CTAs: `nexus_lingua/lib/shared/widgets/nexus_glow_filled_button.dart`

## Note on duplicate plan files

- **Repo:** `.cursor/plans/ui_ux_coordination_followup.plan.md` (this file) — versioned with the project.
- **Cursor user folder:** `ui_ux_inspection_and_roadmap_cd0c8740.plan.md` — original inspection playbook; do not delete; use this follow-up for execution status.

