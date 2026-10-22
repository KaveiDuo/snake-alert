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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.onestopGreen, C.onestopMint],
          ),
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
  static const _prefsKey = 'sign_in_as';

  /// null = Student; otherwise the admin post.
  AdminRole? _post;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_prefsKey);
      final post = AdminRole.values.where((r) => r.name == saved).firstOrNull;
      if (mounted && post != _post) setState(() => _post = post);
    } catch (_) {}
  }

  void _pick(AdminRole? post) {
    if (post == _post) return;
    setState(() => _post = post);
    SharedPreferences.getInstance().then((p) => p.setString(_prefsKey, post?.name ?? 'student')).catchError((_) => false);
  }

  void _continue() {
    if (_post != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthorityPhoneScreen(post: _post)));
    } else {
      Navigator.of(context).pushReplacement(_fade(const AuthenticatingScreen(), 450));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = _post != null;
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
            _RoleSwitch(post: _post, onChanged: _pick),
            const SizedBox(height: 12),
            _OnestopButton(
              color: C.onestopGreen,
              onTap: _continue,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(admin),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(admin ? 'Sign in with phone number' : 'Sign in with Outlook', style: mont(16)),
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
                switch (_post) {
                  null => 'For students and faculty with an @iitg.ac.in ID',
                  AdminRole.housekeeping => 'For registered housekeeping staff · code by SMS',
                  AdminRole.security => 'For registered security guards · code by SMS',
                  AdminRole.warden => 'For registered wardens · code by SMS',
                },
                key: ValueKey(_post),
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

/// Four-way switch: Student | Housekeeping | Security | Warden, each a small
/// icon over a short label so it stays one compact row. The white pill slides
/// under the chosen one.
class _RoleSwitch extends StatelessWidget {
  final AdminRole? post;
  final ValueChanged<AdminRole?> onChanged;
  const _RoleSwitch({required this.post, required this.onChanged});

  static const _options = <(AdminRole?, String, IconData)>[
    (null, 'Student', Icons.school_outlined),
    (AdminRole.housekeeping, 'Housekeeping', Icons.cleaning_services_outlined),
    (AdminRole.security, 'Security', Icons.local_police_outlined),
    (AdminRole.warden, 'Warden', Icons.badge_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _options.indexWhere((o) => o.$1 == post);
    return Container(
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
            alignment: Alignment(-1 + 2 * index / (_options.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / _options.length,
              child: Container(
                height: 54,
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
              for (final (p, label, icon) in _options)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: p == post,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(p),
                      child: SizedBox(
                        height: 54,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 19, color: p == post ? C.onestopGreen : C.onestopInk.withValues(alpha: 0.55)),
                            const SizedBox(height: 3),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  style: mont(11.5, color: p == post ? C.onestopInk : C.onestopInk.withValues(alpha: 0.6)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnestopButton extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  const _OnestopButton({required this.color, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            // No retry button: it made signing in look like it had failed.
            const SizedBox(height: 99),
            Image.asset('assets/images/swc.png', height: 32),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
