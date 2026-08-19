import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// The sign-in screen: register a new account or log into an existing one.
///
/// It only triggers the action on [AuthController]; the app's root watches the
/// auth status and swaps to the main app once login succeeds.
class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isRegister = false;
  String? _validationError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final String email = _email.text.trim();
    final String password = _password.text;

    if (!email.contains('@') || email.length < 3) {
      setState(() => _validationError = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _validationError = 'Password must be at least 6 characters.',
      );
      return;
    }
    setState(() => _validationError = null);

    final AuthController auth = context.read<AuthController>();
    if (_isRegister) {
      auth.register(email, password);
    } else {
      auth.login(email, password);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _validationError = null;
    });
    context.read<AuthController>().clearError();
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final AuthController auth = context.watch<AuthController>();
    final String? error = _validationError ?? auth.error;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: EchoLogoMark(size: 56)),
                  const SizedBox(height: 20),
                  Text(
                    _isRegister ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegister
                        ? 'Your board will be saved to your account.'
                        : 'Log in to load your saved board.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: c.muted),
                  ),
                  const SizedBox(height: 28),
                  _Field(
                    controller: _email,
                    colors: c,
                    hint: 'Email',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    colors: c,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: c.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(fontSize: 13, color: c.danger),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  _PrimaryButton(
                    label: _isRegister ? 'Register' : 'Log in',
                    busy: auth.busy,
                    onTap: auth.busy ? null : _submit,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: auth.busy ? null : _toggleMode,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13.5, color: c.muted),
                          children: <InlineSpan>[
                            TextSpan(
                              text: _isRegister
                                  ? 'Already have an account? '
                                  : "Don't have an account? ",
                            ),
                            TextSpan(
                              text: _isRegister ? 'Log in' : 'Register',
                              style: TextStyle(
                                color: c.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.colors,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final EchoColors colors;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: onSubmitted != null
          ? TextInputAction.done
          : TextInputAction.next,
      onSubmitted: onSubmitted,
      style: TextStyle(color: colors.text, fontSize: 15),
      cursorColor: colors.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.muted, fontSize: 14),
        prefixIcon: Icon(icon, color: colors.muted),
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.accent, width: 1.6),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: kBrandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
