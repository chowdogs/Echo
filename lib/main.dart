import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/tile_state.dart';
import 'theme/app_theme.dart';
import 'views/emergency_view.dart';
import 'views/landing_view.dart';
import 'views/settings_view.dart';
import 'views/speak_view.dart';
import 'widgets/app_header.dart';
import 'widgets/bottom_nav.dart';

void main() {
  runApp(const EchoApp());
}

class EchoApp extends StatelessWidget {
  const EchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TileState>(
      create: (_) => TileState(),
      // Rebuild MaterialApp when the theme mode changes so the whole tree
      // re-themes. `select` keeps this to theme changes only.
      child: Consumer<TileState>(
        builder: (BuildContext context, TileState state, Widget? child) {
          return MaterialApp(
            title: 'Echo',
            debugShowCheckedModeBanner: false,
            theme: buildEchoTheme(kLightColors, Brightness.light),
            darkTheme: buildEchoTheme(kDarkColors, Brightness.dark),
            themeMode: state.themeMode,
            home: child,
          );
        },
        child: const EchoRoot(),
      ),
    );
  }
}

/// Top-level flow: the landing screen gives way to the main shell once the
/// user chooses to begin. Kept as a simple state swap rather than a route so
/// there is no back-stack to land on the splash again by accident.
class EchoRoot extends StatefulWidget {
  const EchoRoot({super.key});

  @override
  State<EchoRoot> createState() => _EchoRootState();
}

class _EchoRootState extends State<EchoRoot> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _started
          ? const MainShell(key: ValueKey<String>('shell'))
          : LandingView(
              key: const ValueKey<String>('landing'),
              onStart: () => setState(() => _started = true),
            ),
    );
  }
}

/// The full-screen mobile shell: a fixed header, a flexible content area that
/// fills everything between, and a fixed bottom navigation bar. No artificial
/// phone frame — the layout expands to the full width and height of whatever
/// device or window it runs on.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    // No explicit backgroundColor: the Scaffold picks up the active theme's
    // scaffoldBackgroundColor, so it flips with light/dark automatically.
    return const Scaffold(
      body: Column(
        children: <Widget>[
          AppHeader(),
          Expanded(child: _ActiveView()),
          BottomNav(),
        ],
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView();

  @override
  Widget build(BuildContext context) {
    // `select` rather than `watch`: this only rebuilds when the tab changes,
    // not on every utterance recorded.
    final EchoTab tab = context.select<TileState, EchoTab>(
      (TileState state) => state.activeTab,
    );

    final Widget view = switch (tab) {
      EchoTab.speak => const SpeakView(),
      EchoTab.emergency => const EmergencyView(),
      EchoTab.settings => const SettingsView(),
    };

    // Cross-fade between tabs so switching feels like one app, not a hard cut.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey<EchoTab>(tab), child: view),
    );
  }
}
