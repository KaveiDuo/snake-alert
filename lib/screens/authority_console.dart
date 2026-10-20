import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/response.dart';
import 'profile.dart';
import 'report_location.dart';
import 'sighting_detail.dart';

/// The authority's app: Reports (the console) and Profile, switched with the
/// bottom bar like the student app.
class AuthorityShell extends StatefulWidget {
  const AuthorityShell({super.key});
  @override
  State<AuthorityShell> createState() => _AuthorityShellState();
}

class _AuthorityShellState extends State<AuthorityShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: IndexedStack(index: _tab, children: const [AuthorityConsole(), AuthorityProfile()]),
    bottomNavigationBar: AppTabBar(
      index: _tab,
      onTap: (i) => setState(() => _tab = i),
      items: const [
        (Icons.assignment_outlined, Icons.assignment_rounded, 'Reports'),
        (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
      ],
    ),
  );
}

/// Hostel authority console: only this hostel's reports, split into Open and
/// Resolved and filterable by type. Opening it marks new reports as seen. Each report then moves one step at a time — on the way,
/// at the spot (location checked), safe (outcome and photo required) — and
/// students see every step. Reports not reached within [respondWithin] are
/// flagged to the hostel security guard.
class AuthorityConsole extends StatefulWidget {
  const AuthorityConsole({super.key});
  @override
  State<AuthorityConsole> createState() => _AuthorityConsoleState();
}

class _AuthorityConsoleState extends State<AuthorityConsole> {
  @override
  void initState() {
    super.initState();
    // The authority has now seen every report in their list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context);
      s.markSeen(s.hostelReports);
      s.followApproaches(); // "At the spot" fills in when they get there
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final resolvedTab = s.consoleTab == ConsoleTab.resolved;
    final inTab = s.hostelReports.where((r) => r.safe == resolvedTab).toList();
    final shown = inTab.where(s.consoleFilter.matches).toList()
      // Open: flagged first, then oldest first. Resolved: newest first.
      ..sort((a, b) {
        if (resolvedTab) return b.time.compareTo(a.time);
        final c = (a.flagged ? 0 : 1).compareTo(b.flagged ? 0 : 1);
        return c != 0 ? c : a.time.compareTo(b.time);
      });
    final openCount = s.hostelReports.where((r) => !r.safe).length;
    final filters = [
      ConsoleFilter.all,
      ConsoleFilter.venomous,
      ConsoleFilter.nonVenomous,
      ConsoleFilter.unsure,
      if (!resolvedTab && inTab.any((r) => r.flagged)) ConsoleFilter.overdue,
    ];
    return DarkPage(
      body: LiveClock(
        builder: (context) => Column(
          children: [
            // Whose reports these are, with the rules (ⓘ); name and role are in the Profile tab.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
              child: Row(
                children: [
                  Expanded(child: Text(s.authorityHostel, style: ft(23, w: 700))),
                  IconButton(
                    tooltip: 'How Snake Alert works for authorities',
                    onPressed: () => _rulesSheet(context),
                    icon: const Icon(Icons.info_outline_rounded, color: C.sub, size: 26),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Segmented(
                open: openCount,
                resolved: s.hostelReports.length - openCount,
                resolvedSelected: resolvedTab,
                onChanged: s.setConsoleTab,
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                children: [
                  for (final f in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        f,
                        count: inTab.where(f.matches).length,
                        selected: s.consoleFilter == f,
                        onTap: () => s.setConsoleFilter(f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          Icon(resolvedTab ? Icons.inventory_2_outlined : Icons.verified_outlined, color: C.green, size: 48),
                          const SizedBox(height: 12),
                          Text(resolvedTab ? 'Nothing here yet' : 'All clear', style: ft(20, w: 700)),
                          const SizedBox(height: 4),
                          Text(
                            '${resolvedTab ? 'No resolved' : 'No open'} ${s.consoleFilter == ConsoleFilter.all ? '' : '${s.consoleFilter.label.toLowerCase()} '}reports for ${s.authorityHostel}.',
                            textAlign: TextAlign.center,
                            style: ft(13.5, color: C.muted),
                          ),
                        ],
                      ),
                    ),
                  for (final r in shown)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReportCard(r, key: ValueKey(r.id)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Open / Resolved switch with a count badge on each side.
class _Segmented extends StatelessWidget {
  final int open, resolved;
  final bool resolvedSelected;
  final ValueChanged<ConsoleTab> onChanged;
  const _Segmented({required this.open, required this.resolved, required this.resolvedSelected, required this.onChanged});

  Widget _side(String label, int count, bool selected, Color badgeBg, Color badgeFg, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: ft(14.5, w: selected ? 600 : 500, color: selected ? C.text : C.muted),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 19),
              height: 19,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? badgeBg : badgeBg.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: ft(11, w: 700, color: selected ? badgeFg : badgeFg.withValues(alpha: 0.6))),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF0B0B0B),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: C.line2),
    ),
    child: Row(
      children: [
        _side('Open', open, !resolvedSelected, const Color(0xFFE5383B), Colors.white, () => onChanged(ConsoleTab.open)),
        _side(
          'Resolved',
          resolved,
          resolvedSelected,
          resolvedSelected ? C.greenSoft : const Color(0xFF2E2E2E),
          resolvedSelected ? C.greenText : C.sub,
          () => onChanged(ConsoleTab.resolved),
        ),
      ],
    ),
  );
}

/// One report-type filter: All, Overdue, Venomous, Non-venomous, Not sure.
class _FilterChip extends StatelessWidget {
  final ConsoleFilter f;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.f, {required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dot = switch (f) {
      ConsoleFilter.all => null,
      ConsoleFilter.overdue => C.red,
      ConsoleFilter.venomous => pinVenomous,
      ConsoleFilter.nonVenomous => pinNonVenomous,
      ConsoleFilter.unsure => pinUnsure,
    };
    return Material(
      color: selected ? const Color(0xFF2A2A2A) : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected ? const Color(0xFF555555) : C.line2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (f == ConsoleFilter.overdue)
                const Icon(Icons.priority_high_rounded, size: 14, color: C.redText)
              else if (dot != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              if (dot != null) const SizedBox(width: 6),
              Text(
                f.label,
                style: ft(
                  13,
                  w: selected ? 600 : 500,
                  color: f == ConsoleFilter.overdue ? C.redText : (selected ? C.text : C.sub),
                ),
              ),
              const SizedBox(width: 6),
              Text('$count', style: ft(12.5, w: 600, color: selected ? C.sub : C.faint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ⓘ button: how the response steps work and what students see.
void _rulesSheet(BuildContext context) {
  Widget rule(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: C.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ft(14.5, w: 600)),
              const SizedBox(height: 2),
              Text(body, style: ft(12.5, color: C.muted, height: 1.45)),
            ],
          ),
        ),
      ],
    ),
  );
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('How it works', style: ft(20, w: 700)),
            const SizedBox(height: 4),
            Text('Students see every step you take here, with the time.', style: ft(13, color: C.muted)),
            const SizedBox(height: 18),
            rule(Icons.done_all_rounded, 'Seen', 'Opening this screen tells the reporter you’ve read their report.'),
            rule(Icons.directions_walk_rounded, 'On the way', 'Tap “I’m on my way” when you or a guard sets off.'),
            rule(
              Icons.gps_fixed_rounded,
              'At the spot',
              'Tap “I’ve reached the spot” when you arrive. Your location is checked against the pin.',
            ),
            rule(
              Icons.photo_camera_outlined,
              'Mark area safe',
              'Say what you found and add a photo from the spot. The reporter is then asked to confirm it’s clear.',
            ),
            rule(
              Icons.call_rounded,
              'Call rescuer',
              'For a big or venomous snake, tap “Call rescuer” to phone the snake catcher / wildlife department. Students see that help was called.',
            ),
            rule(
              Icons.timer_off_outlined,
              'Overdue',
              'Reports not reached within ${respondWithin.inMinutes} min, or that the reporter says are still there, are flagged to the hostel security guard.',
            ),
            const SizedBox(height: 4),
            Btn('Got it', kind: BtnKind.ghost, height: 48, onTap: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    ),
  );
}

/// A report in the console. Collapsed it shows only what and where, with the
/// status chips (overdue / escalated stay visible). Tapping the top row (or the
/// chevron) reveals the note, reporter, progress, deadline and the action buttons.
class _ReportCard extends StatefulWidget {
  final Report r;
  const _ReportCard(this.r, {super.key});
  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _open = false;

  void _details(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SightingDetailScreen(report: widget.r)));

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final s = AppScope.read(context);
    final (String label, IconData icon, VoidCallback onTap) = switch (r.stage) {
      Stage.reported || Stage.seen => (
        'On my way',
        Icons.directions_walk_rounded,
        () {
          s.setOnTheWay(r);
          toast(context, '${r.reporter} has been told you’re on the way');
        },
      ),
      Stage.onTheWay => (
        'Reached',
        Icons.place_rounded,
        () {
          s.arrive(r);
          toast(
            context,
            r.locationVerified
                ? 'Arrival recorded · location verified (${r.onSiteMetres!.round()} m from the pin)'
                : 'Arrival recorded · you’re ${r.onSiteMetres!.round()} m from the pin, so it shows as not verified',
          );
        },
      ),
      Stage.onSite => ('Mark safe', Icons.verified_user_outlined, () => _resolveSheet(context, r)),
      Stage.resolved => ('Reopen', Icons.replay_rounded, () => s.reopen(r)),
    };
    final called = r.rescuerCalledAt != null;
    return Panel(
      border: r.flagged ? const Color(0xFF5A2424) : (r.safe ? const Color(0xFF22392A) : C.line2),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                SnakeThumb(r, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 6, runSpacing: 4, children: [_venomTag(r), StatusChip(r)]),
                      const SizedBox(height: 5),
                      Text(r.title, style: ft(17, w: 700)),
                      Text(r.where, style: ft(12.5, color: const Color(0xFFB0B0B0))),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: Color(0xFF262626), shape: BoxShape.circle),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: C.sub, size: 22),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('“${r.note}”', style: ft(13.5, color: const Color(0xFFDCDCDC), height: 1.45)),
                      ],
                      const SizedBox(height: 7),
                      Text('Reported by ${r.reporter} · ${ago(r.time)}', style: ft(12, color: const Color(0xFF7A7A7A))),
                      const SizedBox(height: 14),
                      StageBar(r),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _details(context),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero),
                          child: Text('View full report  ›', style: ft(13, w: 600, color: C.green)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Deadline(r),
                      const SizedBox(height: 12),
                      // One row: call the snake catcher, the next step, the map.
                      Row(
                        children: [
                          if (!r.safe) ...[
                            Expanded(
                              flex: 5,
                              child: _Pill(
                                called ? 'Called' : 'Call rescuer',
                                called ? Icons.phone_callback_rounded : Icons.call_rounded,
                                // The snake catcher / wildlife department, for big or dangerous snakes.
                                // Red until called; grey once it has been done.
                                bg: called ? const Color(0xFF262626) : const Color(0xFFE5484D),
                                fg: called ? C.sub : Colors.white,
                                onTap: () async {
                                  s.callRescuer(r);
                                  if (!await launchUrl(Uri.parse('tel:$rescuerPhone')) && context.mounted) {
                                    toast(context, 'Could not open the dialler');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            flex: 5,
                            child: r.safe
                                ? _Pill(label, icon, bg: const Color(0xFF262626), fg: C.sub, onTap: onTap)
                                : _Pill(
                                    label,
                                    icon,
                                    bg: const Color(0xFF173A24),
                                    fg: C.greenText,
                                    border: const Color(0xFF245A36),
                                    onTap: onTap,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: _Pill(
                              'Map',
                              Icons.location_on_outlined,
                              bg: const Color(0xFF262626),
                              fg: C.text,
                              onTap: () =>
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReportLocationScreen(report: r))),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _venomTag(Report r) => switch (r.venom) {
    Venom.venomous => const Tag('VENOMOUS', fg: C.redText, bg: C.redSoft),
    Venom.nonVenomous => const Tag('NON-VENOMOUS', fg: C.greenText, bg: C.greenSoft),
    Venom.unsure => const Tag('NOT SURE', fg: Color(0xFFFFC46B), bg: Color(0xFF2A1E0B)),
  };
}

/// Compact rounded button used in the report cards' action row.
class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg;
  final Color? border;
  final VoidCallback onTap;
  const _Pill(this.label, this.icon, {required this.bg, required this.fg, this.border, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: bg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: border == null ? BorderSide.none : BorderSide(color: border!),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ft(14, w: 600, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The line under the progress bar: time left to reach the spot, the overdue
/// warning, the location check, or how the report was resolved.
class _Deadline extends StatelessWidget {
  final Report r;
  const _Deadline(this.r);

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = switch (r) {
      _ when r.escalated && !r.safe => (
        Icons.report_rounded,
        C.redText,
        '${r.reporter} says the snake is still there · flagged to the hostel security guard',
      ),
      _ when r.overdue => (
        Icons.timer_off_outlined,
        C.redText,
        'Overdue by ${mins(-r.dueIn)} · flagged to the hostel security guard',
      ),
      _ when r.stage == Stage.onTheWay && r.distanceLeft != null => (
        Icons.near_me_rounded,
        const Color(0xFF8AB4FF),
        '${r.distanceLeft!.round()} m away · arrival is detected automatically',
      ),
      _ when r.stage == Stage.onSite => (
        r.locationVerified ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
        r.locationVerified ? C.greenText : const Color(0xFFFFC46B),
        r.locationVerified
            ? 'At the spot since ${clock(r.onSiteAt!)} · ${r.arrivedAuto ? 'detected from your location' : 'location verified'}'
            : 'At the spot since ${clock(r.onSiteAt!)} · ${r.onSiteMetres!.round()} m from the pin, not verified',
      ),
      _ when r.safe => (
        r.outcome == Outcome.notFound
            ? Icons.search_off_rounded
            : (r.reporterConfirmed == false ? Icons.report_rounded : Icons.check_circle_outline_rounded),
        r.outcome == Outcome.notFound ? const Color(0xFFFFC46B) : C.greenText,
        '${r.outcome == Outcome.notFound ? 'Closed as not found' : 'Resolved'} in ${mins(r.resolvedAt!.difference(r.time))} · ${switch (r.reporterConfirmed) {
          true => '${r.reporter} confirmed it’s clear',
          false => '${r.reporter} disputed it',
          null => 'waiting for ${r.reporter} to confirm',
        }}',
      ),
      _ => (Icons.timer_outlined, const Color(0xFFFFC46B), 'Reach the spot within ${mins(r.dueIn)}'),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, style: ft(12.5, w: 600, color: color, height: 1.35)),
        ),
      ],
    );
  }
}

/// Closing a report, by tapping only: what happened, where they checked, and
/// optionally a photo or a written note. Arrival time and the location check
/// are recorded automatically and shared with students as proof.
Future<void> _resolveSheet(BuildContext context, Report r) async {
  Outcome? outcome;
  final checked = <String>{};
  String? photo;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        Future<void> pick(ImageSource src) async {
          final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
          if (x != null) set(() => photo = x.path);
        }

        // A photo taken at the spot is the proof, so camera only (plus a sample for the demo).
        Future<void> addPhoto() async {
          final choice = await showModalBottomSheet<int>(
            context: ctx,
            backgroundColor: C.card2,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (c) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, icon, label) in [
                      (0, Icons.photo_camera_outlined, 'Take a photo'),
                      (2, Icons.image_outlined, 'Use a sample photo (demo)'),
                    ])
                      ListTile(
                        leading: Icon(icon, color: C.sub),
                        title: Text(label, style: ft(15, w: 500)),
                        onTap: () => Navigator.pop(c, i),
                      ),
                  ],
                ),
              ),
            ),
          );
          switch (choice) {
            case 0:
              await pick(ImageSource.camera);
            case 2:
              set(() => photo = r.sp?.photo ?? 'assets/snakes/wolf.jpg');
          }
        }

        final notFound = outcome == Outcome.notFound;
        final ready = outcome != null && (!notFound || checked.isNotEmpty) && photo != null;
        final onSite = DateTime.now().difference(r.onSiteAt ?? DateTime.now());
        const amber = Color(0xFFFFC46B);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('What happened?', style: ft(22, w: 700)),
                const SizedBox(height: 4),
                Text('Tap one. ${r.reporter} and students nearby will see it.', style: ft(13, color: C.muted, height: 1.4)),
                const SizedBox(height: 10),
                // Proof that's shared automatically, so nothing has to be typed.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: r.locationVerified ? C.greenSoft : const Color(0xFF2A1E0B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.locationVerified ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                        size: 15,
                        color: r.locationVerified ? C.greenText : amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'At the spot ${mins(onSite)} · ${r.locationVerified ? 'location verified' : 'location not verified'}',
                        style: ft(12, w: 600, color: r.locationVerified ? C.greenText : amber),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final o in Outcome.values) ...[
                  _OutcomeTile(o, selected: outcome == o, onTap: () => set(() => outcome = o)),
                  const SizedBox(height: 8),
                ],
                // Only for "Not found": where they looked, and what students are told.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !notFound
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Where did you check?', style: ft(15, w: 700)),
                              const SizedBox(height: 2),
                              Text('Tap every place you looked', style: ft(12.5, color: checked.isEmpty ? amber : C.muted)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final spot in searchSpots)
                                    FilterChip(
                                      label: Text(
                                        spot,
                                        style: ft(13.5, w: 600, color: checked.contains(spot) ? C.greenInk : C.sub),
                                      ),
                                      selected: checked.contains(spot),
                                      showCheckmark: true,
                                      checkmarkColor: C.greenInk,
                                      selectedColor: C.green,
                                      backgroundColor: C.card2,
                                      side: BorderSide(color: checked.contains(spot) ? C.green : C.line2),
                                      shape: const StadiumBorder(),
                                      onSelected: (on) => set(() => on ? checked.add(spot) : checked.remove(spot)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 16, color: amber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Students are told it may still be nearby and to stay alert for 24 hours.',
                                      style: ft(12.5, color: amber, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                // Required: a photo from the spot shows the authority was there.
                Text('Photo of the spot', style: ft(15, w: 700)),
                const SizedBox(height: 2),
                Text('Required · shows students you were there', style: ft(12.5, color: photo == null ? amber : C.muted)),
                const SizedBox(height: 10),
                _PhotoProof(photo: photo, onAdd: addPhoto),
                const SizedBox(height: 18),
                Btn(
                  switch (outcome) {
                    null => 'Choose what happened',
                    Outcome.notFound when checked.isEmpty => 'Tap where you checked',
                    _ when photo == null => 'Add a photo to finish',
                    Outcome.notFound => 'Close as not found',
                    _ => 'Mark area safe',
                  },
                  icon: ready ? (notFound ? Icons.search_off_rounded : Icons.verified_rounded) : null,
                  onTap: ready
                      ? () {
                          AppScope.read(context).resolve(
                            r,
                            outcome: outcome!,
                            searched: [
                              for (final spot in searchSpots)
                                if (checked.contains(spot)) spot,
                            ],
                            proofPhoto: photo,
                          );
                          Navigator.pop(ctx);
                          toast(
                            context,
                            notFound
                                ? 'Closed as not found · students told to stay alert'
                                : 'Marked safe · ${r.reporter} has been asked to confirm',
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// One outcome as a full-width row: big icon, short label, one line of help
/// and a round tick, so it can be chosen without reading much.
class _OutcomeTile extends StatelessWidget {
  final Outcome o;
  final bool selected;
  final VoidCallback onTap;
  const _OutcomeTile(this.o, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget svg(String name, Color c) =>
        SvgPicture.asset('assets/icons/$name.svg', width: 27, height: 27, colorFilter: ColorFilter.mode(c, BlendMode.srcIn));
    final (Widget Function(Color) icon, Color color, String help) = switch (o) {
      Outcome.chased => ((c) => svg('chased_away', c), C.green, 'Into the forest, away from people'),
      Outcome.rescuer => ((c) => Icon(Icons.health_and_safety_outlined, size: 22, color: c), C.green, 'A snake rescuer took it'),
      Outcome.leftArea => ((c) => svg('went_away', c), C.green, 'Left on its own'),
      Outcome.notFound => ((c) => Icon(Icons.search_off_rounded, size: 22, color: c), const Color(0xFFFFC46B), 'Searched, couldn’t find it'),
    };
    return Material(
      color: selected ? Color.alphaBlend(color.withValues(alpha: 0.12), C.card2) : C.card2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? color : C.line2, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Center(child: icon(color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.short, style: ft(15, w: 700)),
                    Text(help, style: ft(12.5, color: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : Colors.transparent,
                  border: Border.all(color: selected ? color : const Color(0xFF4A4A4A), width: 2),
                ),
                child: selected ? const Icon(Icons.check_rounded, size: 14, color: Color(0xFF0E0E0E)) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The required photo on the resolve sheet: a big "take a photo" target, then
/// the photo itself with Retake.
class _PhotoProof extends StatelessWidget {
  final String? photo;
  final VoidCallback onAdd;
  const _PhotoProof({required this.photo, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return Material(
        color: C.card2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF5A4520), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onAdd,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_camera_rounded, size: 24, color: Color(0xFFFFC46B)),
                const SizedBox(width: 10),
                Text('Take a photo', style: ft(15.5, w: 700, color: const Color(0xFFFFC46B))),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: C.greenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF245A36)),
      ),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 56, height: 56, child: photoOf(photo!))),
          const SizedBox(width: 12),
          const Icon(Icons.check_circle_rounded, size: 18, color: C.greenText),
          const SizedBox(width: 6),
          Expanded(child: Text('Photo added', style: ft(14.5, w: 600, color: C.greenText))),
          TextButton(
            onPressed: onAdd,
            child: Text('Retake', style: ft(13.5, w: 600, color: C.sub)),
          ),
        ],
      ),
    );
  }
}

class AuthorityProfile extends StatelessWidget {
  const AuthorityProfile({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final avg = s.avgArrival;
    Widget stat(String v, String l, Color c) => Expanded(
      child: Column(
        children: [
          Text(v, style: ft(22, w: 700, color: c)),
          const SizedBox(height: 4),
          Text(
            l,
            style: ft(12, color: C.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    return DarkPage(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          // A tab, so no back button.
          Text('Profile', style: ft(24, w: 700)),
          const SizedBox(height: 16),
          IdCard(
            avatar: ClipOval(child: Image.asset('assets/images/avatar_authority.jpg', width: 88, height: 88, fit: BoxFit.cover)),
            name: AppState.kamengAuthority,
            lines: ['Hostel authority · ${s.authorityHostel}'],
          ),
          const SizedBox(height: 22),
          Text('Snake Alert · ${s.authorityHostel}', style: ft(17, w: 600)),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                stat('${s.hostelOpen}', 'Open now', C.redText),
                Container(width: 1, height: 40, color: C.line),
                stat('${s.safeThisWeek}', 'Marked safe this week', C.green),
                Container(width: 1, height: 40, color: C.line),
                stat(avg == null ? '—' : '${avg.inMinutes} min', 'Avg. arrival', C.text),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Details', style: ft(17, w: 600)),
          const SizedBox(height: 12),
          InfoCard([
            InfoRow(
              Icons.call_outlined,
              'Registered phone',
              '+91 98765 43210',
              editable: false,
              trailing: const Tag('VERIFIED', fg: C.green, bg: C.greenSoft),
            ),
            const InfoRow(Icons.person_outline_rounded, 'Role', 'Hostel authority', editable: false),
            InfoRow(Icons.apartment_outlined, 'Hostel', s.authorityHostel.replaceAll(' Hostel', ''), editable: false),
            const InfoRow(Icons.apartment_outlined, 'Office', 'Kameng Hostel · Ground floor'),
          ]),
          const SizedBox(height: 22),
          const ProfileActions(),
        ],
      ),
    );
  }
}
