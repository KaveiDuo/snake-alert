import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/response.dart';
import 'profile.dart';
import 'sighting_detail.dart';

/// Hostel authority console: only this hostel's reports. Opening it marks new
/// reports as seen. Each report then moves one step at a time — on the way,
/// at the spot (location checked), safe (outcome and photo required) — and
/// students see every step. Reports not reached within [respondWithin] are
/// flagged to campus security.
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
      if (mounted) AppScope.read(context).markSeen(AppScope.read(context).hostelReports);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = s.hostelReports;
    final shown = switch (s.consoleFilter) {
      ConsoleFilter.all => all,
      ConsoleFilter.open => all.where((r) => !r.safe).toList(),
      ConsoleFilter.overdue => all.where((r) => r.flagged).toList(),
    };
    // Flagged first, then open by age, then resolved.
    shown.sort((a, b) {
      int rank(Report r) => r.flagged ? 0 : (r.safe ? 2 : 1);
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : (a.safe ? b.time.compareTo(a.time) : a.time.compareTo(b.time));
    });
    final avg = s.avgArrival;
    return DarkPage(
      body: LiveClock(
        builder: (context) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorityProfile())),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset('assets/images/avatar_authority.jpg', width: 44, height: 44, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.authorityHostel, style: ft(19, w: 700)),
                            Text('${AppState.kamengAuthority} · Hostel authority', style: ft(12, color: C.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _Stat(
                    '${s.hostelOpen}',
                    'Open',
                    s.hostelOpen > 0 ? C.amber : C.green,
                    accent: C.amber,
                    selected: s.consoleFilter == ConsoleFilter.open,
                    onTap: () => s.toggleFilter(ConsoleFilter.open),
                  ),
                  const SizedBox(width: 8),
                  _Stat(
                    '${s.hostelFlagged}',
                    'Overdue',
                    s.hostelFlagged > 0 ? C.redText : C.muted,
                    accent: C.red,
                    selected: s.consoleFilter == ConsoleFilter.overdue,
                    onTap: () => s.toggleFilter(ConsoleFilter.overdue),
                  ),
                  const SizedBox(width: 8),
                  _Stat(avg == null ? '—' : '${avg.inMinutes} min', 'Avg. arrival', C.text),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (s.consoleFilter != ConsoleFilter.all)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
                      child: Text(
                        s.consoleFilter == ConsoleFilter.open
                            ? 'Showing open reports only · tap “Open” again to show all'
                            : 'Showing overdue reports only · tap “Overdue” again to show all',
                        style: ft(12, color: C.muted),
                      ),
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_outlined, color: C.green, size: 48),
                          const SizedBox(height: 12),
                          Text('All clear', style: ft(20, w: 700)),
                          const SizedBox(height: 4),
                          Text(
                            s.consoleFilter == ConsoleFilter.overdue
                                ? 'No overdue reports for ${s.authorityHostel}.'
                                : 'No open reports for ${s.authorityHostel}.',
                            style: ft(13.5, color: C.muted),
                          ),
                        ],
                      ),
                    ),
                  for (final r in shown)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReportCard(r)),
                    ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 18, color: C.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Students see every step you take here, with the time. Tap “I’ve reached the spot” when you '
                            'arrive: your location is checked against the pin. Marking an area safe needs what you found '
                            'and a photo from the spot, and the reporter is asked to confirm. Reports not reached within '
                            '${respondWithin.inMinutes} min are flagged to campus security.',
                            style: ft(12, color: C.muted, height: 1.5),
                          ),
                        ),
                      ],
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

/// Summary tile at the top of the console. With [onTap] it filters the list
/// (shown by its [accent] colour and a ✕ while selected).
class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;
  const _Stat(this.value, this.label, this.color, {this.accent = C.amber, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: selected ? Color.alphaBlend(accent.withValues(alpha: 0.14), C.card) : C.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? accent : C.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(value, style: ft(19, w: 700, color: color)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: ft(11.5, color: selected ? C.sub : C.muted)),
                  if (selected) ...[const SizedBox(width: 4), Icon(Icons.close_rounded, size: 12, color: accent)],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  final Report r;
  const _ReportCard(this.r);

  void _open(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => SightingDetailScreen(report: r)));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final (String label, IconData icon, VoidCallback onTap, BtnKind kind) = switch (r.stage) {
      Stage.reported || Stage.seen => (
        'I’m on my way',
        Icons.directions_walk_rounded,
        () {
          s.setOnTheWay(r);
          toast(context, '${r.reporter} has been told you’re on the way');
        },
        BtnKind.primary,
      ),
      Stage.onTheWay => (
        'I’ve reached the spot',
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
        BtnKind.primary,
      ),
      Stage.onSite => ('Mark area safe', Icons.verified_outlined, () => _resolveSheet(context, r), BtnKind.primary),
      Stage.resolved => ('Reopen report', Icons.replay_rounded, () => s.reopen(r), BtnKind.ghost),
    };

    return Panel(
      border: r.flagged ? const Color(0xFF5A2424) : (r.safe ? const Color(0xFF22392A) : C.line2),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _open(context),
            child: Row(
              children: [
                SnakeThumb(r, size: 60),
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
              ],
            ),
          ),
          if (r.note.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text('“${r.note}”', style: ft(13.5, color: const Color(0xFFDCDCDC), height: 1.45)),
          ],
          const SizedBox(height: 7),
          Text('Reported by ${r.reporter} · ${ago(r.time)}', style: ft(12, color: const Color(0xFF7A7A7A))),
          const SizedBox(height: 14),
          StageBar(r),
          const SizedBox(height: 12),
          _Deadline(r),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Btn(label, kind: kind, icon: icon, height: 50, onTap: onTap)),
              const SizedBox(width: 9),
              Material(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _open(context),
                  child: const SizedBox(width: 56, height: 50, child: Icon(Icons.location_on_outlined, color: C.sub)),
                ),
              ),
            ],
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
        '${r.reporter} says the snake is still there · flagged to campus security',
      ),
      _ when r.overdue => (
        Icons.timer_off_outlined,
        C.redText,
        'Overdue by ${mins(-r.dueIn)} · flagged to campus security',
      ),
      _ when r.stage == Stage.onSite => (
        r.locationVerified ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
        r.locationVerified ? C.greenText : const Color(0xFFFFC46B),
        r.locationVerified
            ? 'At the spot since ${clock(r.onSiteAt!)} · location verified'
            : 'At the spot since ${clock(r.onSiteAt!)} · ${r.onSiteMetres!.round()} m from the pin, not verified',
      ),
      _ when r.safe => (
        r.reporterConfirmed == false ? Icons.report_rounded : Icons.check_circle_outline_rounded,
        C.greenText,
        'Resolved in ${mins(r.resolvedAt!.difference(r.time))} · ${switch (r.reporterConfirmed) {
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
        Expanded(child: Text(text, style: ft(12.5, w: 600, color: color, height: 1.35))),
      ],
    );
  }
}

/// "Mark area safe": what happened, plus a photo from the spot as proof.
Future<void> _resolveSheet(BuildContext context, Report r) async {
  Outcome? outcome;
  String? photo;
  final note = TextEditingController();
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

        final ready = outcome != null && photo != null;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
                const SizedBox(height: 14),
                Text('Mark area safe', style: ft(20, w: 700)),
                const SizedBox(height: 4),
                Text(
                  '${r.reporter} and students nearby will see what you found and your photo.',
                  style: ft(13, color: C.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Text('WHAT DID YOU FIND?', style: ft(11.5, w: 700, color: C.muted, ls: 1.2)),
                const SizedBox(height: 8),
                for (final o in Outcome.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: outcome == o ? C.green : C.line2,
                      onTap: () => set(() => outcome = o),
                      child: Row(
                        children: [
                          Icon(
                            outcome == o ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 20,
                            color: outcome == o ? C.green : C.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(o.label, style: ft(14))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('PHOTO FROM THE SPOT (REQUIRED)', style: ft(11.5, w: 700, color: C.muted, ls: 1.2)),
                const SizedBox(height: 8),
                if (photo != null)
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(width: 72, height: 72, child: photoOf(photo!)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Photo added', style: ft(14, w: 600, color: C.greenText))),
                      TextButton(
                        onPressed: () => set(() => photo = null),
                        child: Text('Change', style: ft(13, w: 600, color: C.sub)),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Btn(
                          'Take photo',
                          kind: BtnKind.ghost,
                          icon: Icons.photo_camera_outlined,
                          height: 46,
                          onTap: () => pick(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Btn(
                          'Gallery',
                          kind: BtnKind.ghost,
                          icon: Icons.photo_library_outlined,
                          height: 46,
                          onTap: () => pick(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => set(() => photo = r.sp?.photo ?? 'assets/snakes/wolf.jpg'),
                      child: Text('Use a sample photo (demo)', style: ft(12.5, color: C.muted)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  maxLines: 2,
                  style: ft(14),
                  decoration: InputDecoration(
                    hintText: 'Add a note for students (optional)',
                    hintStyle: ft(14, color: C.muted),
                    filled: true,
                    fillColor: C.card2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Btn(
                  ready ? 'Mark area safe' : (outcome == null ? 'Choose what you found' : 'Add a photo to continue'),
                  icon: ready ? Icons.verified_rounded : null,
                  onTap: ready
                      ? () {
                          AppScope.read(context).resolve(r, outcome: outcome!, proofPhoto: photo!, note: note.text);
                          Navigator.pop(ctx);
                          toast(context, 'Marked safe · ${r.reporter} has been asked to confirm');
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
      header: const AppHeader('Profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: [
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
