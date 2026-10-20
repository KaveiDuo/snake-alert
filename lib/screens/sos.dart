import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Emergency SOS: hold the button for 1.5 s and the phone dialler opens with
/// the hospital number.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  static const hospital = '8277992838';
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        _dial();
        _hold.reset();
      }
    });

  // Slow "breathing" glow that invites a press; it settles while the button is held.
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    _hold.dispose();
    super.dispose();
  }

  Future<void> _dial() async {
    if (!await launchUrl(Uri.parse('tel:$hospital')) && mounted) toast(context, 'Could not open the dialler');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140A0A),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader('', backIcon: Icons.close_rounded, centerTitle: true),
            Expanded(child: _holdView()),
          ],
        ),
      ),
    );
  }

  Widget _holdView() => Padding(
    key: const ValueKey('hold'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Column(
      children: [
        // Title near the top; the button and its explanation sit in the middle.
        Text('EMERGENCY SOS', textAlign: TextAlign.center, style: ft(24, w: 800, ls: 1.5)),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTapDown: (_) => _hold.forward(),
                  onTapUp: (_) => _hold.isCompleted ? null : _hold.reverse(),
                  onTapCancel: () => _hold.isCompleted ? null : _hold.reverse(),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_hold, _breath]),
                    builder: (_, _) {
                      final b = Curves.easeInOut.transform(_breath.value) * (1 - _hold.value);
                      return SizedBox(
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
                              width: 180 - 10 * _hold.value + 8 * b,
                              height: 180 - 10 * _hold.value + 8 * b,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE5382D),
                                boxShadow: [
                                  BoxShadow(
                                    color: C.red.withValues(alpha: 0.35 + 0.3 * b),
                                    blurRadius: 30 + 34 * b,
                                    spreadRadius: 2 + 8 * b,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Who it calls (the title already says SOS).
                                  const Icon(Icons.phone_rounded, color: Colors.white, size: 52),
                                  const SizedBox(height: 8),
                                  Text('IITG Hospital', style: ft(19, w: 800, color: Colors.white, height: 1.1)),
                                  const SizedBox(height: 3),
                                  Text('82779 92838', style: ft(14.5, w: 600, color: Colors.white, ls: 0.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
                const SizedBox(height: 40), // keeps the button near the middle
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
