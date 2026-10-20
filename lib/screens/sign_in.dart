import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_state.dart';
import '../theme.dart';
import 'authority_sign_in.dart';
import 'home_shell.dart';

/// Onestop-style gradient background (matches welcome_header.dart in the Onestop app).
class OnestopBackground extends StatelessWidget {
  final Widget child;
  const OnestopBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.onestopGreen, C.onestopMint]),
        ),
        // Fills the screen on normal phones and scrolls on very short ones.
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Sign-in: a Student / Hostel authority switch, then one button for that
/// role (Outlook for students, phone number for authorities). The last role
/// picked on this phone is remembered.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const _prefsKey = 'sign_in_as_authority';
  bool _authority = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getBool(_prefsKey) ?? false;
      if (mounted && saved != _authority) setState(() => _authority = saved);
    } catch (_) {}
  }

  void _pick(bool authority) {
    if (authority == _authority) return;
    setState(() => _authority = authority);
    SharedPreferences.getInstance().then((p) => p.setBool(_prefsKey, authority)).catchError((_) => false);
  }

  void _continue() {
    if (_authority) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthorityPhoneScreen()));
    } else {
      Navigator.of(context).pushReplacement(_fade(const AuthenticatingScreen(), 450));
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnestopBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 64),
            Hero(tag: 'logo', child: Image.asset('assets/images/app_logo_dark.png', width: 80, height: 80)),
            const SizedBox(height: 24),
            Text('Welcome to the\nall new Onestop', textAlign: TextAlign.center, style: geist(38, height: 1, ls: -1.5)),
            const Spacer(),
            _RoleSwitch(authority: _authority, onChanged: _pick),
            const SizedBox(height: 12),
            _OnestopButton(
              color: C.onestopGreen,
              onTap: _continue,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(_authority),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_authority ? 'Sign in with phone number' : 'Sign in with Outlook', style: mont(16)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _authority
                    ? 'For registered hostel authorities · code by SMS'
                    : 'For students and faculty with an @iitg.ac.in ID',
                key: ValueKey(_authority),
                textAlign: TextAlign.center,
                style: geist(12, color: C.onestopInk.withValues(alpha: 0.6), ls: -0.2),
              ),
            ),
            const SizedBox(height: 18),
            Image.asset('assets/images/swc.png', height: 32),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Two-way switch: Student | Hostel authority. The white pill slides under the
/// chosen side.
class _RoleSwitch extends StatelessWidget {
  final bool authority;
  final ValueChanged<bool> onChanged;
  const _RoleSwitch({required this.authority, required this.onChanged});

  Widget _side(String label, IconData icon, bool selected, VoidCallback onTap) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? C.onestopGreen : C.onestopInk.withValues(alpha: 0.55)),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: mont(14, color: selected ? C.onestopInk : C.onestopInk.withValues(alpha: 0.6))),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
    ),
    child: Stack(
      children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: authority ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
        Row(
          children: [
            _side('Student', Icons.school_outlined, !authority, () => onChanged(false)),
            _side('Hostel authority', Icons.shield_outlined, authority, () => onChanged(true)),
          ],
        ),
      ],
    ),
  );
}

class _OnestopButton extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final BorderSide? side;
  const _OnestopButton({required this.color, required this.child, required this.onTap, this.side});

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: side ?? BorderSide.none),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: child),
    ),
  );
}

PageRouteBuilder<T> _fade<T>(Widget page, int ms) => PageRouteBuilder<T>(
  transitionDuration: Duration(milliseconds: ms),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, c) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
    child: c,
  ),
);

/// Simulated Outlook sign-in: "Authenticating" types in (~0.6 s), then Home fades in.
class AuthenticatingScreen extends StatefulWidget {
  const AuthenticatingScreen({super.key});
  @override
  State<AuthenticatingScreen> createState() => _AuthenticatingScreenState();
}

class _AuthenticatingScreenState extends State<AuthenticatingScreen> with TickerProviderStateMixin {
  static const word = 'Authenticating';
  late final AnimationController _type = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);
  late final Timer _dots;
  int _dotCount = 0;
  Timer? _done;

  @override
  void initState() {
    super.initState();
    _dots = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_type.isCompleted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
    _go();
  }

  void _go() {
    _done?.cancel();
    _done = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      AppScope.read(context).setRole(Role.student);
      Navigator.of(context).pushReplacement(_fade(const HomeShell(), 600));
    });
  }

  @override
  void dispose() {
    _type.dispose();
    _pulse.dispose();
    _dots.cancel();
    _done?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnestopBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 64),
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
              child: Hero(tag: 'logo', child: Image.asset('assets/images/app_logo_dark.png', width: 80, height: 80)),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _type,
              builder: (_, _) {
                final n = (word.length * _type.value).round();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 26),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: word.substring(0, n)),
                          TextSpan(
                            text: word.substring(n),
                            style: const TextStyle(color: Colors.transparent),
                          ),
                        ],
                      ),
                      style: geist(30, height: 1, ls: -1.5),
                    ),
                    SizedBox(width: 26, child: Text('.' * _dotCount, style: geist(30, height: 1, ls: -1.5))),
                  ],
                );
              },
            ),
            const Spacer(),
            const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: C.onestopGreen, strokeWidth: 4)),
            const SizedBox(height: 40),
            Text('Complete the login in your browser.', style: geist(16, color: C.onestopInk.withValues(alpha: 0.8), ls: -0.76)),
            const SizedBox(height: 24),
            _OnestopButton(
              color: Colors.white,
              side: const BorderSide(color: C.onestopGreen),
              onTap: _go,
              child: Center(
                child: Text('Try again', style: mont(16, color: C.onestopGreen)),
              ),
            ),
            const SizedBox(height: 15),
            Image.asset('assets/images/swc.png', height: 32),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
