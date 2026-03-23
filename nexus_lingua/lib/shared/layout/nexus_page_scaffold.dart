import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import 'nexus_app_drawer.dart';
import 'nexus_breakpoints.dart';

/// Cyber-minimal shell: obsidian scaffold, transparent app bar, global [endDrawer].
class NexusPageScaffold extends StatefulWidget {
  /// Creates a primary app page with shared chrome.
  const NexusPageScaffold({
    super.key,
    this.scaffoldKey,
    required this.title,
    required this.body,
    required this.repository,
    required this.navigatorContext,
    this.activeProfile,
    this.actions = const [],
    this.onAfterReturnFromPushedRoute,
    this.bottomNavigationBar,
  });

  final GlobalKey<ScaffoldState>? scaffoldKey;

  final Widget title;

  final Widget body;

  final CardRepository repository;

  /// Pass the same [BuildContext] that builds this widget (for drawer navigation).
  final BuildContext navigatorContext;

  final LanguageProfile? activeProfile;

  final List<Widget> actions;

  /// See [NexusAppDrawer.onAfterReturnFromPushedRoute].
  final Future<void> Function()? onAfterReturnFromPushedRoute;

  /// Optional bottom bar (e.g. [NexusCompactNavBar] on compact width).
  final Widget? bottomNavigationBar;

  @override
  State<NexusPageScaffold> createState() => _NexusPageScaffoldState();
}

class _NexusPageScaffoldState extends State<NexusPageScaffold> {
  late final GlobalKey<ScaffoldState> _localScaffoldKey;

  @override
  void initState() {
    super.initState();
    _localScaffoldKey = GlobalKey<ScaffoldState>();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final scaffoldStateKey = widget.scaffoldKey ?? _localScaffoldKey;

    return Scaffold(
      key: scaffoldStateKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: widget.title,
        actions: [
          ...widget.actions,
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () {
              scaffoldStateKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: NexusAppDrawer(
        navigatorContext: widget.navigatorContext,
        repository: widget.repository,
        activeProfile: widget.activeProfile,
        onAfterReturnFromPushedRoute: widget.onAfterReturnFromPushedRoute,
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
      body: LayoutBuilder(
        builder: (context, c) {
          final hPad = NexusBreakpoints.bodyHorizontalPaddingLp(c.maxWidth);
          final lc = NexusBreakpoints.layoutClassForWidth(c.maxWidth);
          final maxW = lc == NexusLayoutClass.large
              ? NexusBreakpoints.maxContentWidthLp
              : double.infinity;
          return Padding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: widget.body,
              ),
            ),
          );
        },
      ),
    );
  }
}
