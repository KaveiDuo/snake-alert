import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'authority_console.dart';

class _Steps extends StatelessWidget {
  final int done;
  const _Steps(this.done);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 2; i++) ...[
        if (i > 0) const SizedBox(width: 7),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            decoration: BoxDecoration(
              color: i < done ? C.green : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ],
  );
}

const _smallPrint = 'Only registered admins can sign in. Students use their Outlook ID as usual.';

/// Step 1 — choose your post (Housekeeping, Security or Warden), then enter
/// your own registered phone number. Each post has several employees, each
/// with their own number.
class AuthorityPhoneScreen extends StatefulWidget {
  /// Chosen on the first sign-in screen; when null, the post is chosen here.
  final AdminRole? post;
  const AuthorityPhoneScreen({super.key, this.post});
  @override
  State<AuthorityPhoneScreen> createState() => _AuthorityPhoneScreenState();
}

IconData _postIcon(AdminRole r) => switch (r) {
  AdminRole.housekeeping => Icons.cleaning_services_outlined,
  AdminRole.security => Icons.local_police_outlined,
  AdminRole.warden => Icons.badge_outlined,
};

class _AuthorityPhoneScreenState extends State<AuthorityPhoneScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late AdminRole _post = widget.post ?? AdminRole.housekeeping;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _digits => _ctrl.text.replaceAll(RegExp(r'\D'), '').length;
  Staff? get _who => _digits == 10 ? Staff.byPhone(_ctrl.text) : null;
  bool get _ok => _who != null && _who!.post == _post;

  void _choose(AdminRole r) => setState(() {
    _post = r;
    _ctrl.clear();
  });

  @override
  Widget build(BuildContext context) {
    final active = _ctrl.text.isNotEmpty || _focus.hasFocus;
    final who = _who;
    return DarkPage(
      header: AppHeader(widget.post == null ? 'Admin sign-in' : '${_post.label} sign-in'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          const _Steps(1),
          if (widget.post == null) ...[
            const SizedBox(height: 20),
            Text('Sign in as', style: ft(22, w: 700)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (i, r) in AdminRole.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: _post == r ? C.greenSoft : C.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: _post == r ? C.green : C.line, width: _post == r ? 1.5 : 1),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _choose(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            children: [
                              Icon(_postIcon(r), color: _post == r ? C.green : C.sub, size: 24),
                              const SizedBox(height: 6),
                              Text(
                                r == AdminRole.security ? 'Security' : r.label,
                                style: ft(13.5, w: 600, color: _post == r ? C.greenText : C.sub),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text('Your phone number', style: ft(widget.post == null ? 16 : 22, w: 700)),
          const SizedBox(height: 6),
          Text(
            'The number the Hostel Affairs office has on record for you. No Outlook ID needed.',
            style: ft(13, color: C.muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 54,
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: active ? C.green : C.line, width: active ? 1.5 : 1),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Text('+91', style: ft(15, color: active ? C.sub : C.muted)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    keyboardType: TextInputType.phone,
                    cursorColor: C.green,
                    style: ft(15),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(11)],
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '98765 43210',
                      hintStyle: ft(15, color: const Color(0xFF757575)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_digits == 10)
            Row(
              children: [
                Icon(
                  _ok ? Icons.verified_user_outlined : Icons.error_outline_rounded,
                  size: 16,
                  color: _ok ? C.greenText : C.redText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    who == null
                        ? 'This number isn’t registered as an admin. Ask the Hostel Affairs office to add it.'
                        : (_ok
                              ? 'Registered: ${who.name} · ${who.post.label}'
                              : 'This number is registered for ${who.post.label}, not ${_post.label}.'),
                    style: ft(12.5, w: 600, color: _ok ? C.greenText : C.redText, height: 1.35),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Btn(
            'Send code on SMS',
            onTap: _ok
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AuthorityCodeScreen(phone: _ctrl.text, account: who!),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 22),
          Text(_smallPrint, style: ft(11, color: C.faint, height: 1.6)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Step 2 — the SMS code fills itself in, turns green, then signs in.
class AuthorityCodeScreen extends StatefulWidget {
  final String phone;
  final Staff account;
  const AuthorityCodeScreen({super.key, required this.phone, required this.account});
  @override
  State<AuthorityCodeScreen> createState() => _AuthorityCodeScreenState();
}

class _AuthorityCodeScreenState extends State<AuthorityCodeScreen> {
  static const code = '482917';
  int _filled = 0;
  bool _verified = false;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _timers.add(
      Timer(const Duration(milliseconds: 400), () {
        _timers.add(
          Timer.periodic(const Duration(milliseconds: 140), (t) {
            if (!mounted) return t.cancel();
            setState(() => _filled++);
            if (_filled >= 6) {
              t.cancel();
              _timers.add(
                Timer(const Duration(milliseconds: 250), () {
                  if (mounted) setState(() => _verified = true);
                  _timers.add(Timer(const Duration(milliseconds: 650), _signIn));
                }),
              );
            }
          }),
        );
      }),
    );
  }

  void _signIn() {
    if (!mounted) return;
    final s = AppScope.read(context);
    s.signInAs(widget.account); // signed in to this employee's own account
    s.setRole(Role.authority);
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const AuthorityShell(),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DarkPage(
      header: AppHeader('${widget.account.post.label} sign-in'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          const _Steps(2),
          const SizedBox(height: 20),
          Text('Enter the 6-digit code', style: ft(22, w: 700)),
          const SizedBox(height: 10),
          Text('Sent to +91 ${widget.phone} · valid 10 min', style: ft(13, color: C.muted)),
          const SizedBox(height: 4),
          Text('Signing in as ${widget.account.name} · ${widget.account.post.label}', style: ft(13, w: 600, color: C.greenText)),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 65,
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _verified ? C.green : (_filled > 0 ? const Color(0xFF3A3A3A) : C.line),
                width: _verified ? 1.5 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 6; i++)
                      SizedBox(
                        width: 34,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 140),
                          transitionBuilder: (c, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a),
                              child: c,
                            ),
                          ),
                          child: Text(
                            i < _filled ? code[i] : '-',
                            key: ValueKey('$i-${i < _filled}-$_verified'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: i < _filled ? (_verified ? C.green : C.text) : const Color(0xFF757575),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_verified)
                  const Positioned(
                    right: 18,
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.green)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _verified ? 1 : 0,
            child: Row(
              children: [
                const Icon(Icons.check_rounded, color: C.green, size: 16),
                const SizedBox(width: 6),
                Text('Code auto-filled from SMS', style: ft(12.5, w: 600, color: C.green)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Btn('Verify', onTap: _filled >= 6 ? _signIn : null),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Change number', style: ft(13.5, w: 600, color: C.muted)),
            ),
          ),
          const SizedBox(height: 14),
          Text(_smallPrint, style: ft(11, color: C.faint, height: 1.6)),
        ],
      ),
    );
  }
}
