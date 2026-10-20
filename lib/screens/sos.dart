import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Emergency SOS: hold the button for 1.5 s to "call". The demo shows the
/// calling screen; "Call now" opens the phone dialler with the hospital number.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  static const hospital = '8277992838';
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) setState(() => _calling = true);
    });
  bool _calling = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _dial() async {
    if (!await launchUrl(Uri.parse('tel:$hospital')) && mounted) toast(context, 'Could not open the dialler');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final last = s.latestOpen;
    return Scaffold(
      backgroundColor: const Color(0xFF140A0A),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(_calling ? 'Emergency SOS' : '', backIcon: Icons.close_rounded, centerTitle: true),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _calling ? _callingView(last) : _holdView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _holdView() => Padding(
    key: const ValueKey('hold'),
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
    // The button, with its explanation underneath, sits in the middle of the screen.
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title sits with the button, not up in the bar.
          Text('EMERGENCY SOS', textAlign: TextAlign.center, style: ft(24, w: 800, ls: 1.5)),
          const SizedBox(height: 100),
          GestureDetector(
            onTapDown: (_) => _hold.forward(),
            onTapUp: (_) => _hold.isCompleted ? null : _hold.reverse(),
            onTapCancel: () => _hold.isCompleted ? null : _hold.reverse(),
            child: AnimatedBuilder(
              animation: _hold,
              builder: (_, _) => SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: _hold.value,
                        strokeWidth: 5,
                        color: Colors.white,
                        backgroundColor: const Color(0x33FF453A),
                      ),
                    ),
                    Container(
                      width: 180 - 10 * _hold.value,
                      height: 180 - 10 * _hold.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE5382D),
                        boxShadow: [BoxShadow(color: C.red.withValues(alpha: 0.45), blurRadius: 40, spreadRadius: 4)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Who it calls (the title already says SOS).
                          const Icon(Icons.phone_rounded, color: Colors.white, size: 36),
                          const SizedBox(height: 8),
                          Text('IITG Hospital', style: ft(19, w: 800, color: Colors.white, height: 1.1)),
                          const SizedBox(height: 3),
                          Text('82779 92838', style: ft(14.5, w: 600, color: Colors.white, ls: 0.3)),
                          const SizedBox(height: 6),
                          Text('24×7 · hold to call', style: ft(11, color: Colors.white.withValues(alpha: 0.78))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 72),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              'Hold to call. Your location is shared with the hospital and campus security.',
              textAlign: TextAlign.center,
              style: ft(13.5, color: C.muted, height: 1.5),
            ),
          ),
          const SizedBox(height: 104), // keeps the button just below the middle
        ],
      ),
    ),
  );

  Widget _callingView(Report? last) => ListView(
    key: const ValueKey('call'),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    children: [
      Center(
        child: Container(
          width: 110,
          height: 110,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE5382D)),
          child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 46),
        ),
      ),
      const SizedBox(height: 18),
      Text('Calling IITG Hospital', textAlign: TextAlign.center, style: ft(22, w: 700)),
      const SizedBox(height: 4),
      Text(
        'Emergency line · connecting…',
        textAlign: TextAlign.center,
        style: ft(13, color: C.muted),
      ),
      const SizedBox(height: 22),
      for (final t in [
        'Hospital alerted with your location',
        'Security control room alerted',
        if (last != null) 'Last report attached: ${last.title}, ${last.place}',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            color: const Color(0xFF1E1212),
            border: const Color(0xFF3A1D1B),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.check_rounded, color: C.green, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: ft(13.5))),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      Panel(
        color: const Color(0xFF1E1212),
        border: const Color(0xFF3A1D1B),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHILE YOU WAIT', style: ft(11, w: 700, color: C.amber, ls: 1)),
            const SizedBox(height: 8),
            Text(
              'Keep the person still and calm · Remove rings and tight clothing · Keep the bitten limb below heart level · Do not cut, suck, or apply a tourniquet',
              style: ft(13, color: C.sub, height: 1.55),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Btn('Call now (opens dialler)', kind: BtnKind.danger, icon: Icons.phone_rounded, onTap: _dial),
      const SizedBox(height: 10),
      Btn(
        'End call',
        kind: BtnKind.ghost,
        onTap: () {
          _hold.reset();
          setState(() => _calling = false);
        },
      ),
    ],
  );
}
