import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/response.dart';
import 'notifications.dart';
import 'profile.dart';
import 'snake_watch.dart';
import 'sos.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Floating SOS button with a soft red glow that slowly pulses.
class _GlowingSos extends StatefulWidget {
  final VoidCallback onTap;
  const _GlowingSos({required this.onTap});
  @override
  State<_GlowingSos> createState() => _GlowingSosState();
}

class _GlowingSosState extends State<_GlowingSos> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: C.red.withValues(alpha: 0.5 + 0.3 * t), blurRadius: 18 + 16 * t, spreadRadius: 2 + 6 * t),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        backgroundColor: C.red,
        elevation: 0,
        shape: const CircleBorder(),
        onPressed: widget.onTap,
        child: Text('SOS', style: ft(15, w: 800, color: Colors.white)),
      ),
    );
  }
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [const _HomeTab(), const _NotInDemo('Food'), const _NotInDemo('Travel'), const StudentProfile()];
    return Scaffold(
      backgroundColor: C.bg,
      body: IndexedStack(index: _tab, children: tabs),
      floatingActionButton: _tab == 0
          ? _GlowingSos(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())))
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161616),
          border: Border(top: BorderSide(color: Color(0xFF232323))),
        ),
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            for (final (i, icon, activeIcon, label) in [
              (0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              (1, Icons.restaurant_outlined, Icons.restaurant, 'Food'),
              (2, Icons.directions_bus_outlined, Icons.directions_bus, 'Travel'),
              (3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
            ])
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(color: _tab == i ? C.greenSoft : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_tab == i ? activeIcon : icon, size: 22, color: _tab == i ? C.green : C.sub),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: ft(11, w: _tab == i ? 600 : 400, color: _tab == i ? C.green : C.sub),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotInDemo extends StatelessWidget {
  final String name;
  const _NotInDemo(this.name);
  @override
  Widget build(BuildContext context) => DarkPage(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: ft(22, w: 700)),
            const SizedBox(height: 8),
            Text(
              '$name isn’t part of this Snake Alert demo.',
              textAlign: TextAlign.center,
              style: ft(14, color: C.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  void _soon(BuildContext c, String what) => toast(c, '$what isn’t part of this demo');

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final latest = s.latestOpen;
    return DarkPage(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              const SizedBox(width: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'One', style: ft(28, w: 700)),
                    TextSpan(
                      text: '.',
                      style: ft(28, w: 700, color: C.green),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              RoundButton(
                Icons.notifications_none_rounded,
                size: 42,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                badge: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: C.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: C.card2, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Snake Alert alert card
          Panel(
            border: s.activeCount > 0 ? const Color(0xFF3A2E14) : C.line,
            padding: EdgeInsets.zero,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SnakeWatchScreen())),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.activeCount > 0) Container(width: 3, color: C.amber),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🐍', style: TextStyle(fontSize: 17)),
                              const SizedBox(width: 8),
                              Text('Snake Alert', style: ft(17, w: 700)),
                              Text('  ·  ', style: ft(13, color: C.muted)),
                              Text(
                                s.activeCount > 0 ? '${s.activeCount} ACTIVE' : 'ALL CLEAR',
                                style: ft(12.5, w: 700, color: s.activeCount > 0 ? C.amber : C.green, ls: 0.6),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right_rounded, color: C.muted),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (latest != null) ...[
                            Text(
                              '${latest.treatAsVenomous ? (latest.venom == Venom.venomous ? 'Venomous snake' : 'Snake') : 'Non-venomous snake'} near ${latest.place.replaceAll(' Hostel', '')}',
                              style: ft(17, color: C.text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${latest.spot.isEmpty ? latest.place : latest.spot} · ${ago(latest.time)}',
                              style: ft(13, color: C.muted),
                            ),
                            if (latest.covered) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  StatusChip(latest),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      latest.flagged ? 'Hostel security guard alerted' : latest.statusLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ft(12.5, w: 600, color: latest.flagged ? C.redText : C.sub),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ] else
                            Text('No active reports on campus', style: ft(15, color: C.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Panel(
            onTap: () => _soon(context, 'Time Table'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 17)),
                    const SizedBox(width: 8),
                    Text('Time Table', style: ft(17, w: 700)),
                    Text('  ·  7TH SEPTEMBER', style: ft(12, color: C.muted, ls: 0.6)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: C.muted),
                  ],
                ),
                const SizedBox(height: 8),
                Text('No upcoming classes', style: ft(17, color: C.muted)),
              ],
            ),
          ),
          const SizedBox(height: 11),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Panel(
                    onTap: () => _soon(context, 'Food'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset('assets/icons/food.svg', width: 22, height: 22),
                            const SizedBox(width: 8),
                            Text('Food', style: ft(17, w: 700)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('DINNER · ENDS 9:30 PM', style: ft(10.5, color: C.muted, ls: 0.6)),
                        const SizedBox(height: 8),
                        for (final item in ['1. Veg Kofta / Egg curry', '2. Alo pata gobi matar', '3. Chana Dal fry', '4. Rice', '5. Roti'])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(item, style: ft(13.5, color: C.sub)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset('assets/icons/gate_log.svg', width: 22, height: 22),
                            const SizedBox(width: 8),
                            Text('Gatelog', style: ft(17, w: 700)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final g in ['To City', 'To Khoka', 'Others'])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              onPressed: () => _soon(context, 'Gatelog'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: C.line2),
                                shape: const StadiumBorder(),
                                minimumSize: const Size.fromHeight(38),
                              ),
                              child: Text(g, style: ft(14, color: C.green)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Quick Access', style: ft(22, w: 700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            children: [
              // Each icon is an emoji or the name of an Onestop icon in assets/icons/.
              for (final (icon, label) in [
                ('🐍', 'Snake Alert'),
                ('gate_log.svg', 'GateLog'),
                ('lib_token.svg', 'Library Token'),
                ('contacts.svg', 'Contacts'),
                ('cab_sharing.svg', 'Cab Sharing'),
                ('irbs.svg', 'SAC Room Booking'),
                ('complaints.svg', 'Complaints'),
                ('lnf.svg', 'Lost and Found'),
                ('bns.svg', 'Buy and Sell'),
                ('gc.svg', 'GC Score Board'),
                ('medical.svg', 'Medical Section'),
                ('LAN.svg', 'LAN'),
              ])
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (label == 'Snake Alert') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SnakeWatchScreen()));
                    } else {
                      _soon(context, label);
                    }
                  },
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: icon.endsWith('.svg')
                            ? SvgPicture.asset('assets/icons/$icon', fit: BoxFit.contain)
                            : Center(child: Text(icon, style: const TextStyle(fontSize: 34))),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: ft(12.5, color: C.sub),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Quick Links', style: ft(22, w: 700)),
          const SizedBox(height: 12),
          // Only links whose real address is known open a page; the rest aren't in the demo.
          for (final (label, url) in [
            ('Bus Route', null),
            ('GateLog Feedback', null),
            ('Academic SSO', 'https://online.iitg.ac.in/sso'),
            ('Academic Calendar', null),
            ('Placement Stats', null),
            ('Guest House', null),
            ('SWC Website', 'https://swc.iitg.ac.in'),
            ('QuickLink', null),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                onTap: () async {
                  if (url == null) return _soon(context, label);
                  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && context.mounted) {
                    toast(context, 'Could not open $label');
                  }
                },
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: ft(15.5, w: 600))),
                    Transform.rotate(
                      angle: -0.785,
                      child: const Icon(Icons.arrow_forward_rounded, color: C.muted, size: 16),
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
