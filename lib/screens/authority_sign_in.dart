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
            decoration: BoxDecoration(color: i < done ? C.green : const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    ],
  );
}

const _smallPrint = 'Only registered hostel authorities can sign in. Students use their Outlook ID as usual.';

/// Step 1 — phone number. The demo types the number in by itself after 0.5 s;
/// you can also type your own.
class AuthorityPhoneScreen extends StatefulWidget {
  const AuthorityPhoneScreen({super.key});
  @override
  State<AuthorityPhoneScreen> createState() => _AuthorityPhoneScreenState();
}

class _AuthorityPhoneScreenState extends State<AuthorityPhoneScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _typer;
  bool _userTyped = false;

  @override
  void initState() {
    super.initState();
    const demo = '98765 43210';
    var i = 0;
    _typer = Timer.periodic(const Duration(milliseconds: 75), (t) {
      if (_userTyped || !mounted) return t.cancel();
      if (t.tick < 7) return; // ~0.5 s pause before "typing"
      i++;
      _ctrl.value = TextEditingValue(
        text: demo.substring(0, i),
        selection: TextSelection.collapsed(offset: i),
      );
      if (i >= demo.length) t.cancel();
    });
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _digits => _ctrl.text.replaceAll(RegExp(r'\D'), '').length;

  @override
  Widget build(BuildContext context) {
    final active = _ctrl.text.isNotEmpty || _focus.hasFocus;
    return DarkPage(
      header: const AppHeader('Hostel authority sign-in'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          const _Steps(1),
          const SizedBox(height: 20),
          Text("What's your phone number?", style: ft(22, w: 700)),
          const SizedBox(height: 10),
          Text(
            "Use the number the Hostel Affairs office has on record for you. Hostel authorities don't need an Outlook ID.",
            style: ft(13, color: C.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
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
                    onChanged: (_) => _userTyped = true,
                    onTap: () => _userTyped = true,
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
          const SizedBox(height: 16),
          Btn(
            'Send code on SMS',
            onTap: _digits == 10
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthorityCodeScreen(phone: _ctrl.text)))
                : null,
          ),
          const SizedBox(height: 22),
          Text(_smallPrint, style: ft(11, color: C.faint, height: 1.6)),
        ],
      ),
    );
  }
}

/// Step 2 — the SMS code fills itself in, turns green, then signs in.
class AuthorityCodeScreen extends StatefulWidget {
  final String phone;
  const AuthorityCodeScreen({super.key, required this.phone});
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
    AppScope.read(context).setRole(Role.authority);
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
      header: const AppHeader('Hostel authority sign-in'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          const _Steps(2),
          const SizedBox(height: 20),
          Text('Enter the 6-digit code', style: ft(22, w: 700)),
          const SizedBox(height: 10),
          Text('Sent to +91 ${widget.phone} · valid 10 min', style: ft(13, color: C.muted)),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 65,
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _verified ? C.green : (_filled > 0 ? const Color(0xFF3A3A3A) : C.line), width: _verified ? 1.5 : 1),
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
