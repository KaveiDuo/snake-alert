import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import 'common.dart';

const _amberText = Color(0xFFFFC46B);

/// Rebuilds every 20 seconds so countdowns and "x min ago" stay current.
class LiveClock extends StatefulWidget {
  final WidgetBuilder builder;
  const LiveClock({super.key, required this.builder});
  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Small pill saying where the response is: "Seen", "On the way", "Overdue"…
class StatusChip extends StatelessWidget {
  final Report r;
  const StatusChip(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String text, Color fg, Color bg) = r.flagged
        ? (Icons.priority_high_rounded, r.escalated ? 'ESCALATED' : 'OVERDUE', C.redText, C.redSoft)
        : switch (r.stage) {
            Stage.reported => (Icons.mark_email_unread_outlined, 'NOT OPENED', _amberText, const Color(0xFF2A1E0B)),
            Stage.seen => (Icons.done_all_rounded, 'SEEN', _amberText, const Color(0xFF2A1E0B)),
            Stage.onTheWay => (Icons.directions_walk_rounded, 'ON THE WAY', const Color(0xFF8AB4FF), const Color(0xFF142033)),
            Stage.onSite => (Icons.place_rounded, 'AT THE SPOT', const Color(0xFF8AB4FF), const Color(0xFF142033)),
            Stage.resolved when r.outcome == Outcome.notFound => (Icons.search_off_rounded, 'NOT FOUND', _amberText, const Color(0xFF2A1E0B)),
            Stage.resolved => (Icons.verified_rounded, 'SAFE', C.greenText, C.greenSoft),
          };
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text, style: ft(10.5, w: 700, color: fg, ls: 0.6)),
        ],
      ),
    );
  }
}

/// Five-dot progress bar used on the authority's report cards.
class StageBar extends StatelessWidget {
  final Report r;
  const StageBar(this.r, {super.key});
  static const labels = ['Reported', 'Seen', 'On the way', 'At spot', 'Safe'];

  @override
  Widget build(BuildContext context) {
    final done = r.stage.index;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) Expanded(child: Container(height: 2, color: i <= done ? C.green : const Color(0xFF333333))),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= done ? C.green : const Color(0xFF1C1C1C),
                  border: Border.all(color: i <= done ? C.green : const Color(0xFF444444), width: 2),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: i == 0 ? TextAlign.left : (i == 4 ? TextAlign.right : TextAlign.center),
                  style: ft(10.5, w: i == done ? 700 : 500, color: i <= done ? C.sub : C.faint),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The full response timeline students see on a sighting: every step with
/// its time, the location check at the spot, and the proof when resolved.
class ResponseTimeline extends StatelessWidget {
  final Report r;
  const ResponseTimeline(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final who = r.handlerName;
    final steps = <_StepData>[
      _StepData('Reported', '${r.reporter} · ${clock(r.time)}', true),
      _StepData(
        r.seenAt != null ? 'Seen by $who' : 'Waiting for the authority to open it',
        r.seenAt != null ? '${clock(r.seenAt!)} · ${mins(r.seenAt!.difference(r.time))} after the report' : 'Sent to the ${r.place} authority',
        r.seenAt != null,
      ),
      _StepData(
        r.onTheWayAt != null ? 'On the way' : 'Not on the way yet',
        r.onTheWayAt != null ? '$who set off at ${clock(r.onTheWayAt!)}' : 'You’ll be notified when they set off',
        r.onTheWayAt != null,
      ),
      if (r.rescuerCalledAt != null)
        _StepData('Snake catcher called', '$who called the snake catcher / wildlife team at ${clock(r.rescuerCalledAt!)}', true),
      _StepData(
        r.onSiteAt != null ? 'Reached the spot' : 'Reaching the spot',
        r.onSiteAt != null
            ? '${clock(r.onSiteAt!)} · ${r.locationVerified ? 'location verified, ${r.onSiteMetres!.round()} m from the pin' : 'location not verified (${r.onSiteMetres!.round()} m away)'}'
            : (r.overdue
                  ? 'Overdue: should have arrived by ${clock(r.time.add(respondWithin))}'
                  : 'Due by ${clock(r.time.add(respondWithin))} · ${mins(r.dueIn)} left'),
        r.onSiteAt != null,
        warn: r.onSiteAt == null && r.overdue,
        badge: r.onSiteAt != null && r.locationVerified ? Icons.gps_fixed_rounded : null,
      ),
      if (r.safe && r.outcome == Outcome.notFound)
        _StepData(
          'Searched · snake not found',
          '${clock(r.resolvedAt!)} · it may still be nearby, so stay alert here for the next ${cautionFor.inHours} hours',
          true,
          caution: true,
        )
      else
        _StepData(
          r.safe ? 'Marked safe' : 'Area checked and marked safe',
          r.safe ? '${clock(r.resolvedAt!)} · ${r.outcome!.label}' : 'After checking the spot',
          r.safe,
        ),
    ];
    final current = steps.indexWhere((s) => !s.done);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, st) in steps.indexed)
          _TimelineRow(
            st,
            isCurrent: i == current,
            last: i == steps.length - 1,
            nextDone: i + 1 < steps.length && steps[i + 1].done,
          ),
        if (r.safe) ...[
          const SizedBox(height: 2),
          Padding(padding: const EdgeInsets.only(left: 26), child: _Proof(r)),
        ],
      ],
    );
  }
}

/// What the authority recorded when closing: where they checked, how long
/// they were at the spot, and any photo or note.
class _Proof extends StatelessWidget {
  final Report r;
  const _Proof(this.r);

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: C.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: ft(12.5, color: C.sub, height: 1.35))),
        ],
      ),
    );
    final t = r.timeAtSpot;
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.proofPhoto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 64, height: 64, child: photoOf(r.proofPhoto!)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.searched.isNotEmpty) line(Icons.search_rounded, 'Checked: ${r.searched.join(', ')}'),
                if (t != null)
                  line(
                    r.locationVerified ? Icons.gps_fixed_rounded : Icons.timer_outlined,
                    'At the spot for ${mins(t)}${r.locationVerified ? ' · location verified' : ''}',
                  ),
                if (r.resolveNote.isNotEmpty) line(Icons.chat_bubble_outline_rounded, '“${r.resolveNote}”'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final String title, sub;
  final bool done;
  final bool warn;
  final bool caution;
  final IconData? badge;
  _StepData(this.title, this.sub, this.done, {this.warn = false, this.caution = false, this.badge});
}

class _TimelineRow extends StatelessWidget {
  final _StepData s;
  final bool isCurrent, last, nextDone;
  const _TimelineRow(this.s, {required this.isCurrent, required this.last, required this.nextDone});

  @override
  Widget build(BuildContext context) {
    final dot = s.caution ? C.amber : (s.done ? C.green : (s.warn ? C.red : (isCurrent ? C.amber : const Color(0xFF444444))));
    final titleColor = s.caution ? _amberText : (s.done ? C.text : (s.warn ? C.redText : (isCurrent ? _amberText : C.muted)));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: s.done || isCurrent || s.warn ? dot : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: dot, width: 2),
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 2, color: nextDone ? C.green.withValues(alpha: 0.6) : const Color(0xFF333333))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(s.title, style: ft(14.5, w: 600, color: titleColor))),
                      if (s.badge != null) ...[const SizedBox(width: 6), Icon(s.badge, size: 14, color: C.green)],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(s.sub, style: ft(12, color: s.warn ? const Color(0xFFE08A86) : C.muted, height: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
