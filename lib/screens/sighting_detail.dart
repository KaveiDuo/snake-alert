import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/response.dart';
import 'report_location.dart';

class SightingDetailScreen extends StatelessWidget {
  final Report report;
  const SightingDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild when the report is marked safe
    final r = report;
    final photo = r.photoPath != null
        ? photoOf(r.photoPath!)
        : (r.sp != null ? Image.asset(r.sp!.photo, fit: BoxFit.cover) : null);
    final d = AppScope.read(context).metresFromYou(r.pos);
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                photo ??
                    Container(
                      color: const Color(0xFF1E1E1E),
                      child: Icon(Icons.help_outline_rounded, size: 80, color: pinColor(r)),
                    ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x00000000), Color(0xF20F0F0F)],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: MediaQuery.of(context).padding.top + 8,
                  child: RoundButton(Icons.chevron_left_rounded, onTap: () => Navigator.pop(context)),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tag.forReport(r),
                      const SizedBox(height: 8),
                      Text(r.title, style: ft(26, w: 700)),
                      Text(r.where, style: ft(13.5, color: C.sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportLocationScreen(report: r))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF142033),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF203556)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_outlined, size: 15, color: C.blue),
                        const SizedBox(width: 6),
                        Text('About ${(d / 10).round() * 10} m from you', style: ft(13, w: 600, color: const Color(0xFF8AB4FF))),
                        Text('  ·  View on map', style: ft(13, w: 700, color: C.blue)),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: C.blue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (r.note.isNotEmpty)
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('“${r.note}”', style: ft(14.5, color: C.text, height: 1.45)),
                        const SizedBox(height: 8),
                        Text('Reported by ${r.reporter} · ${ago(r.time)}', style: ft(12, color: C.muted)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                if (r.covered)
                  LiveClock(builder: (context) => _Response(r))
                else ...[
                  Text('STATUS', style: ft(11.5, w: 700, color: C.muted, ls: 1.2)),
                  const SizedBox(height: 12),
                  _Step('Reported', '${r.reporter} · ${ago(r.time)}', C.green, true),
                  _Step('Students nearby notified', '412 students within 500 m', C.green, true),
                  _Step(
                    'Open area · pin only, no authority',
                    r.safe ? 'Marked safe' : 'The pin clears itself after 2–3 days',
                    r.safe ? C.green : C.amber,
                    false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How the responsible authority is handling the report, step by step, with
/// the overdue warning, a call button and — for the reporter — the final
/// "Is the area clear now?" check.
class _Response extends StatelessWidget {
  final Report r;
  const _Response(this.r);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('AUTHORITY RESPONSE', style: ft(11.5, w: 700, color: C.muted, ls: 1.2)),
            const Spacer(),
            StatusChip(r),
          ],
        ),
        const SizedBox(height: 12),
        if (r.flagged) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.redSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF5A2424)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_rounded, color: C.redText, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.escalated
                        ? 'The reporter says the snake is still there. The hostel security guard has been alerted.'
                        : 'Nobody has reached the spot within ${respondWithin.inMinutes} minutes. The hostel security guard has been alerted.',
                    style: ft(13, color: const Color(0xFFF2B8B5), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        ResponseTimeline(r),
        if (r.safe && s.isMine(r)) ...[
          const SizedBox(height: 12),
          if (r.reporterConfirmed == null)
            Panel(
              border: const Color(0xFF245A36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.outcome == Outcome.notFound ? 'Have you seen the snake again?' : 'Is the area clear now?', style: ft(15.5, w: 700)),
                  const SizedBox(height: 4),
                  Text(
                    r.outcome == Outcome.notFound
                        ? 'The authority searched but couldn’t find it. If you see it again, tap “Snake still here”: the report reopens and the hostel security guard is alerted.'
                        : 'You reported this snake. Tell us if it’s really gone. If it’s still there, the report reopens and the hostel security guard is alerted.',
                    style: ft(12.5, color: C.muted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Btn(
                          r.outcome == Outcome.notFound ? 'Not seen again' : 'Yes, it’s clear',
                          height: 46,
                          onTap: () {
                            s.confirmSafe(r);
                            toast(context, 'Thanks for confirming');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Btn(
                          'Snake still here',
                          kind: BtnKind.danger,
                          height: 46,
                          onTap: () {
                            s.reopen(r, byReporter: true);
                            toast(context, 'Report reopened · hostel security guard alerted');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (r.reporterConfirmed == true)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: C.greenText),
                const SizedBox(width: 6),
                Text(
                  r.outcome == Outcome.notFound ? 'You haven’t seen it again' : 'You confirmed the area is clear',
                  style: ft(13, w: 600, color: C.greenText),
                ),
              ],
            ),
        ],
        if (!r.safe) ...[
          const SizedBox(height: 12),
          Btn(
            'Call the authority now',
            icon: Icons.call_rounded,
            height: 48,
            onTap: () async {
              if (!await launchUrl(Uri.parse('tel:$authorityPhone')) && context.mounted) {
                toast(context, 'Could not open the dialler');
              }
            },
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String title, sub;
  final Color color;
  final bool line;
  const _Step(this.title, this.sub, this.color, this.line);
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (line) Expanded(child: Container(width: 2, color: C.green.withValues(alpha: 0.5))),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ft(14.5, w: 600, color: color == C.amber ? const Color(0xFFFFC46B) : C.text)),
                const SizedBox(height: 2),
                Text(sub, style: ft(12, color: C.muted)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
