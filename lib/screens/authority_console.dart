import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Timer? _poll;
  OverlayEntry? _alert;

  @override
  void initState() {
    super.initState();
    // Escalations reach the admin as an alert, wherever they are in the app
    // (a real build would send a push notification with an alarm sound).
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _alert?.remove();
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final s = AppScope.read(context);
    final fresh = s.takeNewEscalations();
    if (fresh.isEmpty) return;
    HapticFeedback.heavyImpact();
    _alert?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.paddingOf(ctx).top + 8,
        left: 12,
        right: 12,
        child: _EscalationAlert(
          reports: fresh,
          role: s.adminRole,
          onTap: () {
            entry.remove();
            if (_alert == entry) _alert = null;
            setState(() => _tab = 0);
          },
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    _alert = entry;
    Timer(const Duration(seconds: 7), () {
      if (_alert == entry) {
        entry.remove();
        _alert = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // re-check right away when the role changes
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    return _scaffold();
  }

  Widget _scaffold() => Scaffold(
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
      if (s.adminRole != AdminRole.warden) s.markSeen(s.adminReports);
      s.followApproaches(); // "At the spot" fills in when they get there
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final resolvedTab = s.consoleTab == ConsoleTab.resolved;
    // Housekeeping sees every report; the security guard and the warden only
    // the ones escalated to them (and any they took).
    final mine = s.adminReports;
    final inTab = mine.where((r) => r.safe == resolvedTab).toList();
    final shown = inTab.where(s.consoleFilter.matches).toList()
      // Open: flagged first, then oldest first. Resolved: newest first.
      ..sort((a, b) {
        if (resolvedTab) return b.time.compareTo(a.time);
        final me = (a.needs(s.adminRole) ? 0 : 1).compareTo(b.needs(s.adminRole) ? 0 : 1);
        if (me != 0) return me;
        final c = (a.flagged ? 0 : 1).compareTo(b.flagged ? 0 : 1);
        return c != 0 ? c : a.time.compareTo(b.time);
      });
    final openCount = mine.where((r) => !r.safe).length;
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
                  // Who is signed in: the role decides which escalations alert you.
                  _RolePill(s.adminRole, onTap: () => _pickRole(context)),
                  IconButton(
                    tooltip: 'How Snake Alert works for admins',
                    onPressed: () => _rulesSheet(context),
                    icon: const Icon(Icons.info_outline_rounded, color: C.sub, size: 26),
                  ),
                ],
              ),
            ),
            if (!resolvedTab && s.escalatedToMe.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _EscalatedBanner(count: s.escalatedToMe.length, role: s.adminRole),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Segmented(
                open: openCount,
                resolved: mine.length - openCount,
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
                            s.adminRole != AdminRole.housekeeping && s.consoleFilter == ConsoleFilter.all
                                ? '${resolvedTab ? 'No resolved reports' : 'Nothing is overdue'} for you right now. Reports reach the ${s.adminRole.label.toLowerCase()} only if nobody gets to the spot in ${s.adminRole == AdminRole.warden ? escalateEvery.inMinutes * 2 : escalateEvery.inMinutes} min.'
                                : '${resolvedTab ? 'No resolved' : 'No open'} ${s.consoleFilter == ConsoleFilter.all ? '' : '${s.consoleFilter.label.toLowerCase()} '}reports for ${s.authorityHostel}.',
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
              'Who is alerted',
              'New reports go to Housekeeping first. Not reached within ${escalateEvery.inMinutes} min, or the reporter says it’s still there: the security guard is alerted. After ${escalateEvery.inMinutes * 2} min: the warden too. Tap “On my way” to take a report, so the others see who has it.',
            ),
            rule(
              Icons.supervisor_account_outlined,
              'The warden follows up',
              'The warden doesn’t go to the spot. They see who was alerted and when, call Housekeeping or Security to ask why, and can send both a reminder.',
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _venomTag(r),
                          StatusChip(r),
                          if (!r.safe && r.level != AdminRole.housekeeping)
                            Tag(r.level == AdminRole.warden ? '→ WARDEN' : '→ SECURITY', fg: C.redText, bg: C.redSoft),
                        ],
                      ),
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
                      // The warden oversees: who was alerted, and calls / reminders to them.
                      if (s.adminRole == AdminRole.warden)
                        _WardenPanel(r)
                      else
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
        '${r.reporter} says the snake is still there · escalated to ${_ladder(r.level)}',
      ),
      _ when r.overdue => (
        Icons.timer_off_outlined,
        C.redText,
        AppScope.read(context).adminRole == AdminRole.warden
            ? 'Overdue by ${mins(-r.dueIn)} · nobody has reached the spot'
            : 'Overdue by ${mins(-r.dueIn)} · escalated to ${_ladder(r.level)}',
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
    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, style: ft(12.5, w: 600, color: color, height: 1.35)),
        ),
      ],
    );
    final role = AppScope.read(context).adminRole;
    final reminder = r.remindedAt != null && role != AdminRole.warden && !r.safe && r.stage.index < Stage.onSite.index;
    // Once escalated: has anyone taken it yet?
    if (r.safe || (r.level == AdminRole.housekeeping && !reminder)) return line;
    final taken = r.stage.index >= Stage.onTheWay.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        if (role == AdminRole.security && r.stage.index < Stage.onSite.index) ...[const SizedBox(height: 6), _BeforeYou(r)],
        if (reminder) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 16, color: C.redText),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Reminder from the warden at ${clock(r.remindedAt!)} · please go now',
                  style: ft(12.5, w: 700, color: C.redText, height: 1.35),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(taken ? Icons.how_to_reg_rounded : Icons.person_off_outlined, size: 16, color: taken ? C.greenText : C.sub),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                taken
                    ? 'Taken by ${r.handlerName}'
                    : (AppScope.read(context).adminRole == AdminRole.warden
                          ? 'Not taken yet · call the team below'
                          : 'Not taken yet · tap “On my way” to take it'),
                style: ft(12.5, w: 600, color: taken ? C.greenText : C.sub, height: 1.35),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _ladder(AdminRole l) => l == AdminRole.warden ? 'the security guard and the warden' : 'the security guard';
}

IconData _roleIcon(AdminRole r) => switch (r) {
  AdminRole.housekeeping => Icons.cleaning_services_outlined,
  AdminRole.security => Icons.local_police_outlined,
  AdminRole.warden => Icons.badge_outlined,
};

String _roleHelp(AdminRole r) => switch (r) {
  AdminRole.housekeeping => 'Gets every new report first and sees all reports',
  AdminRole.security =>
    'Backup: sees reports Housekeeping didn’t reach in ${escalateEvery.inMinutes} min (or the reporter says are still there), checks with them, then goes',
  AdminRole.warden => 'Oversees: sees reports nobody reached in ${escalateEvery.inMinutes * 2} min and follows up with the team',
};

/// Small pill next to the hostel name showing who is signed in.
class _RolePill extends StatelessWidget {
  final AdminRole role;
  final VoidCallback onTap;
  const _RolePill(this.role, {required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: C.card,
    shape: StadiumBorder(side: BorderSide(color: C.line2)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_roleIcon(role), size: 15, color: C.green),
            const SizedBox(width: 6),
            Text(role.label, style: ft(12.5, w: 600, color: C.sub)),
            const Icon(Icons.expand_more_rounded, size: 18, color: C.muted),
          ],
        ),
      ),
    ),
  );
}

/// Demo: choose which admin you are, to see what each one is alerted about.
void _pickRole(BuildContext context) {
  final s = AppScope.read(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text('Signed in as', style: ft(20, w: 700)),
            const SizedBox(height: 4),
            Text(
              'Everyone uses the same portal. Your role decides who is alerted, and when.',
              style: ft(13, color: C.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            for (final (i, r) in AdminRole.values.indexed) ...[
              Material(
                color: r == s.adminRole ? C.greenSoft : C.card2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: r == s.adminRole ? C.green : C.line2, width: r == s.adminRole ? 1.5 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    s.setAdminRole(r);
                    Navigator.pop(ctx);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: C.bg,
                          child: Text('${i + 1}', style: ft(13, w: 700, color: C.green)),
                        ),
                        const SizedBox(width: 12),
                        Icon(_roleIcon(r), size: 22, color: C.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r.label} · ${r.person}', style: ft(15, w: 700)),
                              Text(_roleHelp(r), style: ft(12.5, color: C.muted, height: 1.35)),
                            ],
                          ),
                        ),
                        if (r == s.adminRole) const Icon(Icons.check_circle_rounded, color: C.green, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Red strip above the list: reports escalated to the signed-in admin.
class _EscalatedBanner extends StatelessWidget {
  final int count;
  final AdminRole role;
  const _EscalatedBanner({required this.count, required this.role});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: C.redSoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF5A2424)),
    ),
    child: Row(
      children: [
        const Icon(Icons.notifications_active_rounded, color: C.redText, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Escalated to you · $count', style: ft(15, w: 700, color: C.redText)),
              const SizedBox(height: 2),
              Text(
                role == AdminRole.warden
                    ? 'Nobody reached the spot in ${escalateEvery.inMinutes * 2} min. Call the team, find out why, and get someone there.'
                    : 'Housekeeping hasn’t reached these in ${escalateEvery.inMinutes} min. Check with them, or go yourself and tap “On my way”.',
                style: ft(12.5, color: const Color(0xFFF2B8B5), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Pops in at the top when a report is escalated to you (stands in for a push
/// notification with an alarm in a real build).
class _EscalationAlert extends StatelessWidget {
  final List<Report> reports;
  final AdminRole role;
  final VoidCallback onTap;
  const _EscalationAlert({required this.reports, required this.role, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final r = reports.first;
    final reminded = r.remindedAt != null && role != AdminRole.warden;
    final why = reminded
        ? 'Reminder from the warden · please go now'
        : r.escalated
        ? '${r.reporter} says it’s still there'
        : 'Not reached in ${r.level == AdminRole.warden ? escalateEvery.inMinutes * 2 : escalateEvery.inMinutes} min';
    return Material(
      color: const Color(0xFF2A1414),
      elevation: 10,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF7A2E2E)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Escalated to you · ${role.label}', style: ft(12, w: 700, color: C.redText, ls: 0.3)),
                    const SizedBox(height: 2),
                    Text('${r.title} · ${r.where}', style: ft(14.5, w: 700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '$why${reports.length > 1 ? ' · +${reports.length - 1} more' : ''}',
                      style: ft(12.5, color: C.sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.sub),
            ],
          ),
        ),
      ),
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
            padding: EdgeInsets.fromLTRB(18, 12, 18, 20 + MediaQuery.paddingOf(ctx).bottom),
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
      Outcome.notFound => (
        (c) => Icon(Icons.search_off_rounded, size: 22, color: c),
        const Color(0xFFFFC46B),
        'Searched, couldn’t find it',
      ),
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
                    Text(
                      help,
                      style: ft(12.5, color: C.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 56, height: 56, child: photoOf(photo!)),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.check_circle_rounded, size: 18, color: C.greenText),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Photo added', style: ft(14.5, w: 600, color: C.greenText)),
          ),
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
            avatar: s.adminRole == AdminRole.warden
                ? ClipOval(child: Image.asset('assets/images/avatar_authority.jpg', width: 88, height: 88, fit: BoxFit.cover))
                : Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(color: Color(0xFF2A2A2A), shape: BoxShape.circle),
                    child: Icon(_roleIcon(s.adminRole), color: C.muted, size: 40),
                  ),
            name: s.adminRole.person,
            lines: ['${s.adminRole.label} · ${s.authorityHostel}'],
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
            InfoRow(
              _roleIcon(s.adminRole),
              'Role',
              s.adminRole.label,
              editable: false,
              trailing: GestureDetector(
                onTap: () => _pickRole(context),
                child: Text('Switch', style: ft(14, w: 600, color: C.green)),
              ),
            ),
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

/// The warden's view of an overdue report: who was alerted and how they
/// responded, plus calls and a reminder to Housekeeping and Security. The
/// warden doesn't go to the spot themselves.
class _WardenPanel extends StatelessWidget {
  final Report r;
  const _WardenPanel(this.r);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    String response(AdminRole who) => _response(r, who);

    Widget step(AdminRole who) {
      final ok = r.handlerRole == who && r.onTheWayAt != null;
      final calls = r.wardenCalls.where((c) => c.$1 == who).toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_roleIcon(who), size: 18, color: ok ? C.greenText : C.redText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${who.label} · ${who.person}', style: ft(13.5, w: 700)),
                  Text(
                    'Alerted ${clock(r.alertedAt(who))} · ${response(who)}',
                    style: ft(12.5, color: ok ? C.greenText : C.redText, height: 1.35),
                  ),
                  if (calls.isNotEmpty)
                    Text(
                      'You called ${calls.length == 1 ? 'at ${clock(calls.last.$2)}' : '${calls.length} times, last ${clock(calls.last.$2)}'}',
                      style: ft(12, color: C.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Future<void> call(AdminRole who) async {
      s.logWardenCall(r, who);
      if (!await launchUrl(Uri.parse('tel:$authorityPhone')) && context.mounted) toast(context, 'Could not open the dialler');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
          decoration: BoxDecoration(
            color: C.card2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.line2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHO WAS ALERTED', style: ft(11, w: 700, color: C.muted, ls: 1.1)),
              const SizedBox(height: 10),
              step(AdminRole.housekeeping),
              step(AdminRole.security),
            ],
          ),
        ),
        if (!r.safe) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Pill(
                  'Call housekeeping',
                  Icons.call_rounded,
                  bg: const Color(0xFF262626),
                  fg: C.text,
                  onTap: () => call(AdminRole.housekeeping),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  'Call security',
                  Icons.call_rounded,
                  bg: const Color(0xFF262626),
                  fg: C.text,
                  onTap: () => call(AdminRole.security),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _Pill(
              r.remindedAt == null ? 'Send reminder to both' : 'Reminder sent ${clock(r.remindedAt!)} · send again',
              Icons.campaign_rounded,
              bg: const Color(0xFFE5484D),
              fg: Colors.white,
              onTap: () {
                s.remind(r);
                toast(context, 'Reminder sent to ${AdminRole.housekeeping.person} and ${AdminRole.security.person}');
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// How someone on the ladder responded to a report, for the warden and the security guard.
String _response(Report r, AdminRole who) {
  if (r.handlerRole == who && r.onTheWayAt != null) {
    return r.onSiteAt != null
        ? 'Took it · reached the spot ${clock(r.onSiteAt!)}'
        : 'Took it ${clock(r.onTheWayAt!)} · on the way';
  }
  if (who == AdminRole.housekeeping && r.seenAt != null) return 'Opened it ${clock(r.seenAt!)} · didn’t go';
  return 'No response';
}

/// For the security guard: what Housekeeping did before the report reached
/// them, and a quick call to check whether they're already going.
class _BeforeYou extends StatelessWidget {
  final Report r;
  const _BeforeYou(this.r);
  @override
  Widget build(BuildContext context) {
    const hk = AdminRole.housekeeping;
    final going = r.handlerRole == hk && r.onTheWayAt != null;
    final color = going ? C.greenText : const Color(0xFFFFC46B);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: C.card2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line2),
      ),
      child: Row(
        children: [
          Icon(Icons.cleaning_services_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Before you · ${hk.label}', style: ft(12.5, w: 700)),
                Text(
                  '${hk.person} · ${_response(r, hk)[0].toLowerCase()}${_response(r, hk).substring(1)}',
                  style: ft(12, w: 600, color: color, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              if (!await launchUrl(Uri.parse('tel:$authorityPhone')) && context.mounted) {
                toast(context, 'Could not open the dialler');
              }
            },
            style: TextButton.styleFrom(foregroundColor: C.green, padding: const EdgeInsets.symmetric(horizontal: 10)),
            icon: const Icon(Icons.call_rounded, size: 16),
            label: Text('Call ${hk.person.split(' ').last}', style: ft(13, w: 700, color: C.green)),
          ),
        ],
      ),
    );
  }
}
