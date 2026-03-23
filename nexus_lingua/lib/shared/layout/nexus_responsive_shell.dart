import 'package:flutter/material.dart';

import 'nexus_breakpoints.dart';

/// Wide: optional [leading] + [body] + optional [trailing] in a [Row].
/// Narrow: single [body] (scroll externally if needed).
class NexusResponsiveShell extends StatelessWidget {
  /// Creates a responsive shell.
  const NexusResponsiveShell({
    super.key,
    required this.maxWidth,
    this.leading,
    required this.body,
    this.trailing,
    this.leadingWidth = 200,
    this.trailingWidth = 280,
  });

  /// Pass [constraints.maxWidth] from [LayoutBuilder].
  final double maxWidth;

  final Widget? leading;
  final Widget body;
  final Widget? trailing;

  final double leadingWidth;
  final double trailingWidth;

  bool get _isWide => NexusBreakpoints.isWideLayout(maxWidth);

  @override
  Widget build(BuildContext context) {
    if (!_isWide) {
      return body;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null)
          SizedBox(
            width: leadingWidth,
            child: leading!,
          ),
        Expanded(child: body),
        if (trailing != null)
          SizedBox(
            width: trailingWidth,
            child: trailing!,
          ),
      ],
    );
  }
}
