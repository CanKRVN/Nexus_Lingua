import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/nexus_motion.dart';

/// Borderless answer line with a single cyan underline that pulses when focused.
class StudyAnswerField extends StatefulWidget {
  /// Creates a minimalist study answer field.
  const StudyAnswerField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.hintText,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  final bool enabled;

  final String? hintText;

  final TextInputAction textInputAction;

  final void Function(String value)? onSubmitted;

  final bool autofocus;

  @override
  State<StudyAnswerField> createState() => _StudyAnswerFieldState();
}

class _StudyAnswerFieldState extends State<StudyAnswerField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseCurve;
  bool _typingActive = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: NexusMotion.pulseCycle,
    );
    _pulseCurve = CurvedAnimation(parent: _pulse, curve: NexusMotion.pulseCurve);
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  void _onFocusChange() {
    if (_typingActive) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
    setState(() {});
  }

  void _onTextChanged() {
    final nowTyping = widget.focusNode.hasFocus && widget.controller.text.isNotEmpty;
    if (nowTyping == _typingActive) return;
    _typingActive = nowTyping;
    _onFocusChange();
  }

  @override
  void didUpdateWidget(covariant StudyAnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_onFocusChange);
    widget.focusNode.addListener(_onFocusChange);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            height: 1.35,
          ),
          cursorColor: scheme.primary,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: ex.textSubtext.withValues(alpha: 0.65),
              fontSize: 18,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.only(bottom: 10, top: 4),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
          onSubmitted: widget.onSubmitted,
        ),
        AnimatedBuilder(
          animation: _pulseCurve,
          builder: (context, _) {
            final active = focused && (widget.controller.text.isNotEmpty || _typingActive);
            final t = active ? _pulseCurve.value : 0.0;
            final opacity = lerpDouble(0.28, 0.95, t)!;
            final glow = lerpDouble(0.0, 10.0, t)!;
            return Container(
              height: 2,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(
                  alpha: active ? opacity : 0.22,
                ),
                boxShadow: active && glow > 0
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(
                            alpha: 0.35 * opacity,
                          ),
                          blurRadius: glow,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
