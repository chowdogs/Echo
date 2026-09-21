import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/pairing.dart';
import '../services/pairing_service.dart';
import '../state/auth_controller.dart';
import '../state/controller_state.dart'
    show ControllerState, kMaxGuardiansPerPatient;
import '../theme/app_theme.dart';
import '../widgets/sub_page_header.dart';

/// Shown on the *patient's* device: the code a guardian needs to gain control.
///
/// The same value appears twice — as a QR image and as large text — because a
/// guardian's camera may be broken, awkward to aim, or simply slower than
/// typing six characters. Either route ends at the identical code.
///
/// The link is only completed while this screen is open: the device watches
/// its own pairing record and writes the grant itself. That is what makes a
/// guessed code worthless on its own.
class PatientQrPage extends StatefulWidget {
  const PatientQrPage({super.key});

  @override
  State<PatientQrPage> createState() => _PatientQrPageState();
}

class _PatientQrPageState extends State<PatientQrPage> {
  Timer? _poll;
  String? _code;
  String? _error;
  String? _linkedTo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createCode());
  }

  @override
  void dispose() {
    _poll?.cancel();
    // A code left on screen and walked away from should not stay claimable.
    final String? code = _code;
    if (code != null && _linkedTo == null) {
      unawaited(
        context.read<PairingService>().deletePairing(code).catchError(
          (Object _) {},
        ),
      );
    }
    super.dispose();
  }

  Future<void> _createCode() async {
    final AuthController auth = context.read<AuthController>();
    final PairingService pairing = context.read<PairingService>();
    final String? uid = auth.session?.uid;

    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'You need to be signed in to share a code.';
      });
      return;
    }

    try {
      final String code = await pairing.createPairing(
        patientUid: uid,
        patientEmail: auth.session?.email ?? '',
      );
      if (!mounted) return;
      setState(() {
        _code = code;
        _loading = false;
      });
      _poll = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkForClaim(),
      );
    } on PairingException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// Watches for a guardian stamping the code, then writes the actual grant.
  Future<void> _checkForClaim() async {
    final String? code = _code;
    if (code == null || _linkedTo != null) return;

    final AuthController auth = context.read<AuthController>();
    final PairingService pairing = context.read<PairingService>();
    final String? uid = auth.session?.uid;
    if (uid == null) return;

    try {
      final Map<String, dynamic>? record = await pairing.readPairing(code);
      final Object? claimedBy = record?['claimedBy'];
      if (claimedBy is! String || claimedBy.isEmpty) return;

      final Object? claimedEmail = record?['claimedEmail'];

      // The cap is enforced here, at the only point that can enforce it: the
      // patient's own device is the one writing the grant.
      final List<PatientLink> existing = await pairing.fetchControllers(uid);
      final bool alreadyLinked = existing.any(
        (PatientLink g) => g.uid == claimedBy,
      );
      if (!alreadyLinked && existing.length >= kMaxGuardiansPerPatient) {
        _poll?.cancel();
        await pairing.deletePairing(code);
        if (!mounted) return;
        setState(
          () => _error =
              'You already have $kMaxGuardiansPerPatient guardians. Remove '
              'one in Settings before adding another.',
        );
        return;
      }

      await pairing.grantAccess(
        patientUid: uid,
        patientEmail: auth.session?.email ?? '',
        controllerUid: claimedBy,
        controllerEmail: claimedEmail is String ? claimedEmail : '',
      );
      await pairing.deletePairing(code);

      _poll?.cancel();
      if (!mounted) return;
      // Update the patient's guardian list right away, so it is already
      // correct behind this screen rather than a page-visit later.
      unawaited(context.read<ControllerState>().refreshGuardians());
      setState(
        () => _linkedTo = claimedEmail is String && claimedEmail.isNotEmpty
            ? claimedEmail
            : 'your guardian',
      );
    } catch (_) {
      // Transient — the next tick will try again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: <Widget>[
          const SubPageHeader(
            title: 'Controller access',
            subtitle: 'Let a guardian manage this board',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: _body(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(EchoColors c) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }
    if (_error != null) {
      return _Notice(
        icon: Icons.error_outline_rounded,
        color: c.danger,
        title: 'Could not create a code',
        body: _error!,
      );
    }
    if (_linkedTo != null) {
      return _Notice(
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF0F8A5F),
        title: 'Connected',
        body:
            '$_linkedTo can now manage this board and will receive emergency '
            'alerts from this device.',
      );
    }

    final String code = _code!;
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // QR codes need a light ground to scan reliably, in either theme.
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border),
          ),
          child: QrImageView(
            data: PairingCode.toQrPayload(code),
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF1A1D29),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1A1D29),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Or give them this code',
          style: TextStyle(fontSize: 13.5, color: c.muted),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            color: c.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              // Wide tracking so 0/O and 1/I are read correctly aloud.
              letterSpacing: 8,
              color: c.text,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 18, color: c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keep this screen open until the guardian connects. The code '
                'works once and expires after '
                '${PairingCode.validity.inMinutes} minutes.',
                style: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
            ),
            const SizedBox(width: 12),
            Text(
              'Waiting for a guardian…',
              style: TextStyle(fontSize: 13.5, color: c.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: c.muted),
          ),
        ],
      ),
    );
  }
}
