import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/board_storage.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_board_service.dart';
import 'services/tts_service.dart';
import 'state/auth_controller.dart';
import 'state/tile_state.dart';
import 'theme/app_theme.dart';
import 'views/auth_view.dart';
import 'views/emergency_view.dart';
import 'views/landing_view.dart';
import 'views/settings_view.dart';
import 'views/speak_view.dart';
import 'widgets/app_header.dart';
import 'widgets/bottom_nav.dart';

/// Firebase Realtime Database endpoint for the cloud board (REST API).
const String kFirebaseUrl =
    'https://echo-df114-default-rtdb.asia-southeast1.firebasedatabase.app';

/// Firebase Web API Key (Project settings → General → Web API Key).
/// Used only for the Authentication REST API.
const String kFirebaseApiKey = 'AIzaSyCasSFXSBiWw3IzIr04-UnUqaZ3x9mETBw';

/// ElevenLabs API key. Supplied at build time so the secret never lives in
/// source control:  flutter run --dart-define=ELEVENLABS_API_KEY=sk_...
/// (the run-echo.ps1 helper does this for you). When empty — e.g. a fresh
/// clone with no key — Echo falls back to the device's built-in TTS engine.
const String kElevenLabsApiKey = String.fromEnvironment('ELEVENLABS_API_KEY');

/// ElevenLabs voice id to speak with. "Sarah" — a clear default voice that the
/// free tier can use via the API (older library voices like Rachel are blocked
/// on free accounts).
const String kElevenLabsVoiceId = 'EXAVITQu4vr4xnSDxMaL';

void main() {
  // Required before constructing plugins (flutter_tts) that open a platform
  // channel during initialization.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    EchoApp(
      firebase: FirebaseBoardService(baseUrl: kFirebaseUrl),
      authService: FirebaseAuthService(apiKey: kFirebaseApiKey),
      tts: TtsService(
        elevenLabsApiKey: kElevenLabsApiKey,
        voiceId: kElevenLabsVoiceId,
      ),
    ),
  );
}

class EchoApp extends StatelessWidget {
  const EchoApp({super.key, this.firebase, this.authService, this.tts});

  /// Optional cloud backend + auth + speech. main() supplies the real ones;
  /// widget tests use `const EchoApp()` (all null) so they never touch the
  /// network, the TTS plugin, or the login gate.
  final FirebaseBoardService? firebase;
  final FirebaseAuthService? authService;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    // No auth backend (tests / offline preview): original flow, no login gate.
    if (authService == null) {
      return ChangeNotifierProvider<TileState>(
        create: (_) => TileState(firebase: firebase, tts: tts),
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

    // Real app: provide auth + board, and gate the UI behind login.
    final BoardStorage storage = BoardStorage();
    return MultiProvider(
      providers: <ChangeNotifierProvider<ChangeNotifier>>[
        ChangeNotifierProvider<AuthController>(
          create: (_) =>
              AuthController(auth: authService!, storage: storage)..init(),
        ),
        ChangeNotifierProvider<TileState>(
          create: (_) => TileState(firebase: firebase, storage: storage, tts: tts),
        ),
      ],
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
        child: _AuthGate(firebase: firebase),
      ),
    );
  }
}

/// Chooses what to show based on sign-in state, and keeps the board service's
/// auth + the loaded board in step with the current user.
class _AuthGate extends StatefulWidget {
  const _AuthGate({this.firebase});

  final FirebaseBoardService? firebase;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _appliedUid;

  void _sync(AuthController auth) {
    final FirebaseBoardService? firebase = widget.firebase;
    final TileState tiles = context.read<TileState>();

    if (auth.isLoggedIn) {
      final session = auth.session!;
      firebase?.setAuth(session.uid, session.idToken);
      if (_appliedUid != session.uid) {
        _appliedUid = session.uid;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => tiles.loadForUser(),
        );
      }
    } else if (_appliedUid != null) {
      _appliedUid = null;
      firebase?.clearAuth();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => tiles.resetToDefaults(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final EchoColors c = EchoColors.of(context);
    _sync(auth);

    return switch (auth.status) {
      AuthStatus.unknown => Scaffold(
        backgroundColor: c.background,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      ),
      AuthStatus.loggedOut => const _UnauthedFlow(),
      AuthStatus.loggedIn => const MainShell(),
    };
  }
}

/// Landing screen → "Get Started" → login/register.
class _UnauthedFlow extends StatefulWidget {
  const _UnauthedFlow();

  @override
  State<_UnauthedFlow> createState() => _UnauthedFlowState();
}

class _UnauthedFlowState extends State<_UnauthedFlow> {
  bool _showAuth = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _showAuth
          ? const AuthView(key: ValueKey<String>('auth'))
          : LandingView(
              key: const ValueKey<String>('landing'),
              onStart: () => setState(() => _showAuth = true),
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
