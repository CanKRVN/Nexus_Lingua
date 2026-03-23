import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_direction.dart';
import '../../shared/widgets/fsrs_rating_row.dart';

/// Persisted UI preferences (PRD §8.5) + runtime notify for dependents.
class NexusSettings extends ChangeNotifier {
  /// Creates settings (call [load] once at startup).
  NexusSettings();

  static const _kSMax = 'nexus_s_max';
  static const _kEffects = 'nexus_effects_enabled';
  static const _kRatingStyle = 'nexus_rating_display_style';
  static const _kStudyDirection = 'nexus_study_direction';

  double _sMax = 365;
  bool _effectsEnabled = true;
  RatingDisplayStyle _ratingStyle = RatingDisplayStyle.labels;
  StudyDirection _studyDirection = StudyDirection.targetToKnown;

  double get sMax => _sMax;

  bool get effectsEnabled => _effectsEnabled;

  RatingDisplayStyle get ratingStyle => _ratingStyle;

  StudyDirection get studyDirection => _studyDirection;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _sMax = p.getDouble(_kSMax) ?? 365;
    if (_sMax < 1) _sMax = 365;
    _effectsEnabled = p.getBool(_kEffects) ?? true;
    final ri = p.getInt(_kRatingStyle) ?? 0;
    if (ri >= 0 && ri < RatingDisplayStyle.values.length) {
      _ratingStyle = RatingDisplayStyle.values[ri];
    }
    final sd = p.getInt(_kStudyDirection) ?? 0;
    if (sd >= 0 && sd < StudyDirection.values.length) {
      _studyDirection = StudyDirection.values[sd];
    }
    notifyListeners();
  }

  Future<void> setSMax(double value) async {
    final v = value.clamp(1.0, 10000.0);
    _sMax = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSMax, v);
  }

  Future<void> setEffectsEnabled(bool value) async {
    _effectsEnabled = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEffects, value);
  }

  Future<void> setRatingStyle(RatingDisplayStyle value) async {
    _ratingStyle = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kRatingStyle, value.index);
  }

  Future<void> setStudyDirection(StudyDirection value) async {
    _studyDirection = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kStudyDirection, value.index);
  }
}

/// Provides [NexusSettings] to the widget tree.
class NexusSettingsScope extends InheritedNotifier<NexusSettings> {
  /// Wraps [child] with [notifier] for `context.nexusSettings`.
  const NexusSettingsScope({
    super.key,
    required NexusSettings notifier,
    required super.child,
  }) : super(notifier: notifier);

  static NexusSettings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NexusSettingsScope>();
    assert(scope != null, 'NexusSettingsScope not found');
    return scope!.notifier!;
  }
}

extension NexusSettingsContext on BuildContext {
  /// Resolved [NexusSettings] (must be under [NexusSettingsScope]).
  NexusSettings get nexusSettings => NexusSettingsScope.of(this);
}
