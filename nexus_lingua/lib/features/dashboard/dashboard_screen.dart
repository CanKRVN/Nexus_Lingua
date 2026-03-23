import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import '../../core/stats/review_streak.dart';
import '../../shared/layout/nexus_page_scaffold.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/nexus_surfaces.dart';
import '../../shared/widgets/dashboard_sigma_ring.dart';
import '../../shared/widgets/dashboard_tier_donut.dart';
import '../../shared/widgets/mastery_badge.dart';
import '../../shared/widgets/spectral/spectral_hud_tokens.dart';

/// PRD §7.7 — heatmap (draft), ΣS, per-language tiers, streak.
class DashboardScreen extends StatefulWidget {
  /// Creates the mastery dashboard.
  const DashboardScreen({super.key, required this.repository});

  final CardRepository repository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final sumS = await widget.repository.sumAllStability();
    final days = await widget.repository.loadDistinctReviewDaysDescending();
    final streak = computeReviewStreakDays(days);
    final heat = await widget.repository.loadReviewCountsByDayLast(112);
    final profiles = await widget.repository.loadAllProfiles();
    final tierBuckets = <int, Map<MasteryTier, int>>{};
    for (final p in profiles) {
      final id = p.id;
      if (id == null) continue;
      final cards = await widget.repository.loadCardsForProfile(id);
      final buckets = <MasteryTier, int>{
        for (final t in MasteryTier.values) t: 0,
      };
      for (final c in cards) {
        final t = masteryTierForStability(c.stability);
        buckets[t] = (buckets[t] ?? 0) + 1;
      }
      tierBuckets[id] = buckets;
    }
    return _DashData(
      sumS: sumS,
      streak: streak,
      heatmap: heat,
      profiles: profiles,
      tierBuckets: tierBuckets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashData>(
      future: _future,
      builder: (context, snap) {
        LanguageProfile? drawerProfile;
        late final Widget bodyChild;
        if (snap.connectionState != ConnectionState.done) {
          bodyChild = const Center(
            child: CircularProgressIndicator(color: AppColors.accentCyan),
          );
        } else if (snap.hasError) {
          bodyChild = Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: AppColors.feedbackMiss),
            ),
          );
        } else {
          final d = snap.data!;
          drawerProfile = d.profiles.isNotEmpty ? d.profiles.first : null;
          bodyChild = RefreshIndicator(
            color: AppColors.accentCyan,
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                NexusGlass(
                  borderRadius: 14,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardSigmaRing(sumS: d.sumS),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatTileInner(
                            label: 'Total stability (ΣS)',
                            value: d.sumS.toStringAsFixed(1),
                            hint: 'Sum of all card S values',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _StatTile(
                  label: 'Review streak',
                  value: '${d.streak} day${d.streak == 1 ? '' : 's'}',
                  hint: 'Consecutive local days with ≥1 review',
                ),
                const SizedBox(height: 24),
                Text(
                  'Last 16 weeks (reviews / day)',
                  style: nexusSectionTitleStyle(context),
                ),
                const SizedBox(height: 8),
                _HeatmapGrid(counts: d.heatmap),
                const SizedBox(height: 24),
                Text(
                  'Cards by mastery tier',
                  style: nexusSectionTitleStyle(context),
                ),
                const SizedBox(height: 8),
                ...d.profiles.map((p) {
                  final id = p.id;
                  if (id == null) return const SizedBox.shrink();
                  final b = d.tierBuckets[id] ?? {};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardTierDonut(buckets: b),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.displayDeckTitle,
                                style: GoogleFonts.jetBrainsMono(
                                  color: AppColors.accentCyan,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...MasteryTier.values.indexed.map((e) {
                                final i = e.$1;
                                final t = e.$2;
                                final n = b[t] ?? 0;
                                final (lab, col) = masteryTierStyle(t);
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: i < 4 ? 8 : 0,
                                  ),
                                  child: Transform.translate(
                                    offset: Offset(i * 6.0, 0),
                                    child: _SpectralTierBlade(
                                      tierColor: col,
                                      tierLabel: lab,
                                      count: n,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }
        return NexusPageScaffold(
          navigatorContext: context,
          repository: widget.repository,
          activeProfile: drawerProfile,
          title: const Text('Mastery dashboard'),
          body: bodyChild,
        );
      },
    );
  }
}

class _DashData {
  _DashData({
    required this.sumS,
    required this.streak,
    required this.heatmap,
    required this.profiles,
    required this.tierBuckets,
  });

  final double sumS;
  final int streak;
  final Map<String, int> heatmap;
  final List<LanguageProfile> profiles;
  final Map<int, Map<MasteryTier, int>> tierBuckets;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return NexusGlass(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _StatTileInner(label: label, value: value, hint: hint),
      ),
    );
  }
}

class _StatTileInner extends StatelessWidget {
  const _StatTileInner({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: AppColors.textSubtext,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: AppColors.textBody,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
        ),
      ],
    );
  }
}

/// Simple GitHub-style heatmap: 7 rows × 16 columns (recent weeks).
class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final rows = <Widget>[];
    for (var row = 0; row < 7; row++) {
      final rowChildren = <Widget>[];
      for (var col = 0; col < 16; col++) {
        final offsetDays = (15 - col) * 7 + (6 - row);
        final day = today.subtract(Duration(days: offsetDays));
        final key =
            '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final n = counts[key] ?? 0;
        final intensity = n <= 0
            ? 0.0
            : n == 1
            ? 0.35
            : n < 4
            ? 0.55
            : n < 8
            ? 0.75
            : 1.0;
        final emptyFill = scheme.primary.withValues(alpha: 0.05);
        final fillColor = n <= 0
            ? emptyFill
            : (Color.lerp(emptyFill, scheme.primary, intensity) ?? emptyFill);
        rowChildren.add(
          Container(
            margin: const EdgeInsets.all(1.5),
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.zero,
              boxShadow: n > 0
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: 0.12 + intensity * 0.2,
                        ),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }
      rows.add(Row(children: rowChildren));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

/// Glass “blade” row: angled BR clip + tier accent rail.
class _SpectralTierBlade extends StatelessWidget {
  const _SpectralTierBlade({
    required this.tierColor,
    required this.tierLabel,
    required this.count,
  });

  final Color tierColor;
  final String tierLabel;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = context.nexusExtras.glassFill;
    final overlayA = SpectralHudTokens.overlayOpacity(context);

    // Flat glass (no per-row BackdropFilter) — keeps web smooth with many tiers.
    return ClipPath(
      clipper: _SpectralBladeClipper(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            scheme.primary.withValues(alpha: overlayA),
            fill,
          ),
          border: Border(left: BorderSide(color: tierColor, width: 2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tierLabel.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.textBody.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                color: AppColors.textBody,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectralBladeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => spectralAngledBrPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
