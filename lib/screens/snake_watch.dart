import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/campus_map.dart';
import '../widgets/common.dart';
import 'report.dart';
import 'sighting_detail.dart';

/// Campus map. Tapping the map only drops a pin (tap again to move it); the
/// report starts when you press "Report snake sighting".
class SnakeWatchScreen extends StatefulWidget {
  const SnakeWatchScreen({super.key});
  @override
  State<SnakeWatchScreen> createState() => _SnakeWatchScreenState();
}

class _SnakeWatchScreenState extends State<SnakeWatchScreen> {
  Loc? _picked;

  Future<void> _report({Loc? at}) async {
    AppScope.read(context).startDraft(at: at);
    // Keep the pin visible while the report slides in; clear it afterwards.
    await Navigator.push(context, slideUpRoute(const ReportScreen()));
    if (mounted) setState(() => _picked = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final picked = _picked;
    return DarkPage(
      header: AppHeader(
        'Snake Alert',
        subtitle: s.activeCount == 1 ? '1 active report on campus' : '${s.activeCount} active reports on campus',
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CampusMap(
                      dark: s.mapDark,
                      // Areas marked safe drop off the students' map.
                      reports: s.openReports,
                      onToggleTheme: s.toggleMap,
                      onTapReport: (r) => Navigator.push(context, MaterialPageRoute(builder: (_) => SightingDetailScreen(report: r))),
                      onTapMap: (p) => setState(() => _picked = s.locFromMap(p)),
                      selected: picked?.pos,
                      controlsPadding: const EdgeInsets.fromLTRB(10, 10, 10, 44),
                      topHint: _Hint(
                        picked == null ? 'Tap the map to drop a pin where you saw a snake' : 'Tap again to move the pin',
                        dark: s.mapDark,
                      ),
                    ),
                  ),
                  Positioned(left: 10, bottom: 10, right: 10, child: _Legend(dark: s.mapDark)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (picked != null)
              _PickedCard(
                loc: picked,
                onReport: () => _report(at: picked),
                onCancel: () => setState(() => _picked = null),
              )
            else
              Material(
                color: C.red,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _report(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
                    child: Row(
                      children: [
                        const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Report a sighting', style: ft(17, w: 600, color: Colors.white)),
                              Text(
                                'Uses your current location · you can change it',
                                style: ft(12.5, color: Colors.white.withValues(alpha: 0.85)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white),
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

/// Shows where the dropped pin is and starts the report from there.
class _PickedCard extends StatelessWidget {
  final Loc loc;
  final VoidCallback onReport;
  final VoidCallback onCancel;
  const _PickedCard({required this.loc, required this.onReport, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: loc.outside ? C.redSoft : (loc.covered ? C.greenSoft : const Color(0xFF2A1E0B)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  loc.outside ? Icons.block_rounded : (loc.covered ? Icons.location_on_outlined : Icons.park_outlined),
                  color: loc.outside ? C.redText : (loc.covered ? C.green : C.amber),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.name, style: ft(16, w: 700)),
                    const SizedBox(height: 2),
                    Text(
                      loc.outside
                          ? 'Snake Alert only takes reports inside the campus. Move the pin onto campus.'
                          : loc.covered
                          ? 'Inside ${loc.name} premises · the ${loc.name} authority covers this spot'
                          : 'Open area · pin only. No authority is notified; students nearby still see it',
                      style: ft(12.5, color: C.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, color: C.muted, size: 20),
                tooltip: 'Remove pin',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Btn('Report snake sighting', kind: BtnKind.danger, icon: Icons.add_rounded, height: 48, onTap: loc.outside ? null : onReport),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  final bool dark;
  const _Hint(this.text, {required this.dark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: dark ? const Color(0xE61C1C1C) : const Color(0xF2FFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: dark ? C.line2 : const Color(0xFFDDDDDD)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: ft(12, color: dark ? C.text : const Color(0xFF222222)),
    ),
  );
}

class _Legend extends StatelessWidget {
  final bool dark;
  const _Legend({required this.dark});
  @override
  Widget build(BuildContext context) {
    final items = [('Venomous', pinVenomous), ('Non-venomous', pinNonVenomous), ('Unsure', pinUnsure), ('You', C.blue)];
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: dark ? const Color(0xE61C1C1C) : const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? C.line2 : const Color(0xFFDDDDDD)),
        ),
        child: Wrap(
          spacing: 7,
          runSpacing: 4,
          children: [
            for (final (l, c) in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  l == 'You'
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        )
                      : LocationPin(color: c, width: 9, shadow: false),
                  const SizedBox(width: 4),
                  Text(l, style: ft(10.5, color: dark ? C.text : const Color(0xFF222222))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
