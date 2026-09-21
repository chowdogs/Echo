import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/pairing.dart';
import '../state/controller_state.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_page_header.dart';

/// Shown on the *guardian's* device: connect to a patient by scanning their
/// QR code, or by typing the six-character code underneath it.
///
/// Both routes exist deliberately. A camera can be broken, dirty, or hard to
/// aim, and a guardian may be reading the code off a phone call rather than
/// holding the other device — so typing is a first-class path, not a fallback.
class ConnectPatientPage extends StatefulWidget {
  const ConnectPatientPage({super.key});

  @override
  State<ConnectPatientPage> createState() => _ConnectPatientPageState();
}

class _ConnectPatientPageState extends State<ConnectPatientPage> {
  /// Scanning is only offered where a camera plugin actually exists.
  static final bool _cameraAvailable =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  late bool _scanMode = _cameraAvailable;
  final TextEditingController _codeField = TextEditingController();
  MobileScannerController? _scanner;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    if (_cameraAvailable) _scanner = MobileScannerController();
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _codeField.dispose();
    super.dispose();
  }

  Future<void> _connect(String raw) async {
    // The scanner fires continuously; one accepted code is enough.
    if (_handled) return;
    _handled = true;

    final ControllerState controller = context.read<ControllerState>();
    final PatientLink? linked = await controller.connectWithCode(raw);

    if (!mounted) return;
    if (linked != null) {
      Navigator.of(context).pop(linked);
      return;
    }
    // Failed — let them try again.
    _handled = false;
  }

  void _onDetect(BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw == null) continue;
      final String? code = PairingCode.parse(raw);
      if (code != null) {
        _connect(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final ControllerState controller = context.watch<ControllerState>();

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: <Widget>[
          const SubPageHeader(
            title: 'Connect to a patient',
            subtitle: 'Scan their code, or type it in',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_cameraAvailable) ...<Widget>[
                    _ModeToggle(
                      scanMode: _scanMode,
                      onChanged: (bool scan) =>
                          setState(() => _scanMode = scan),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_scanMode && _cameraAvailable)
                    _ScannerBox(controller: _scanner!, onDetect: _onDetect)
                  else
                    _CodeEntry(
                      field: _codeField,
                      busy: controller.busy,
                      cameraAvailable: _cameraAvailable,
                      onSubmit: () => _connect(_codeField.text),
                    ),
                  if (controller.busy) ...<Widget>[
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Connecting — keep their screen open…',
                            style: TextStyle(fontSize: 13.5, color: c.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (controller.error != null) ...<Widget>[
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: c.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            controller.error!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: c.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 26),
                  Text(
                    'Ask the patient to open Settings → Controller access on '
                    'their device. Their screen must stay open while you '
                    'connect.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.scanMode, required this.onChanged});

  final bool scanMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    Widget option(String label, IconData icon, bool isScan) {
      final bool active = scanMode == isScan;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(isScan),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? c.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: active ? Colors.white : c.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: <Widget>[
          option('Scan QR', Icons.qr_code_scanner_rounded, true),
          option('Enter code', Icons.keyboard_rounded, false),
        ],
      ),
    );
  }
}

class _ScannerBox extends StatelessWidget {
  const _ScannerBox({required this.controller, required this.onDetect});

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Column(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              controller: controller,
              onDetect: onDetect,
              errorBuilder: (BuildContext context, MobileScannerException e) {
                return ColoredBox(
                  color: c.surface,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'The camera is unavailable. Switch to "Enter code" '
                        'and type the six characters instead.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: c.muted,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Point the camera at the code on the patient device',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: c.muted),
        ),
      ],
    );
  }
}

class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.field,
    required this.busy,
    required this.cameraAvailable,
    required this.onSubmit,
  });

  final TextEditingController field;
  final bool busy;
  final bool cameraAvailable;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!cameraAvailable) ...<Widget>[
          Text(
            'No camera on this device — enter the code shown on the patient '
            'device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: c.muted),
          ),
          const SizedBox(height: 18),
        ],
        TextField(
          controller: field,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autofocus: !cameraAvailable,
          enabled: !busy,
          onSubmitted: (_) => onSubmit(),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(PairingCode.length),
            // Codes are always capitals, so fix the case as they type rather
            // than rejecting a lowercase entry later.
            TextInputFormatter.withFunction(
              (TextEditingValue _, TextEditingValue next) =>
                  next.copyWith(text: next.text.toUpperCase()),
            ),
          ],
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: c.text,
          ),
          decoration: InputDecoration(
            hintText: 'AB1234',
            hintStyle: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: c.muted.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: c.accent, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Two letters, then four numbers',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: c.muted),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: busy ? null : onSubmit,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Connect',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
