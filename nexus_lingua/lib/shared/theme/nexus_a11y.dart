/// UI-A11y guidance for Nexus Lingua (`.cursorrules` §2, follow-up plan).
///
/// **Magenta / secondary accent (`#E91E8C` / light pink variants) on obsidian (`#0D0D0D`):**
/// - Safe for **icons, borders, large headings** (≥18px bold) and short labels.
/// - For **body copy** under ~14px on `#0D0D0D`, prefer **primary cyan** for text or use
///   **fontWeight ≥ w600** if magenta must carry meaning (not color alone — pair with icon/shape).
/// - **Glow-only layers:** keep fill alpha roughly **≤ 0.35** so halos do not masquerade as text.
///
/// **Focus:** theme [FilledButtonTheme] / [IconButtonTheme] use a **2px primary** outline when
/// focused; custom neon widgets should use [WidgetState.focused] or [Focus] + border.
///
/// **Reduced motion:** respect [MediaQuery.disableAnimationsOf] via [NexusMotion.preferStaticMotion]
/// for decorative effects beyond [NexusSettings.effectsEnabled].
abstract final class NexusA11yNotes {
  NexusA11yNotes._();
}
