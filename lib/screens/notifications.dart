import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/response.dart';
import 'sighting_detail.dart';

/// Notifications, grouped so each snake report is one card: its latest update
/// is shown, and the earlier updates open from a drop-down.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';

  /// Second row of chips, shown under "Snake Alert".
  _SnakeFilter _snake = _SnakeFilter.all;
  final _open = <String>{};

  /// Every update a student gets about one report, oldest first. Anyone sees
  /// the report and how it ended; the reporter also sees each response step.
  static List<_Update> _updates(AppState s, Report r) {
    final mine = s.isMine(r);
    return [
      _Update(
        r.time,
        mine ? 'You reported it' : (r.venom == Venom.venomous ? 'Venomous snake reported' : 'Snake sighting reported'),
        mine ? 'Sent to the ${r.place} admin.' : 'Avoid the area until it is marked safe.',
      ),
      if (mine && r.seenAt != null) _Update(r.seenAt!, 'Your report was seen', '${r.handlerName} has opened it.'),
      if (mine && r.onTheWayAt != null) _Update(r.onTheWayAt!, 'Admin on the way', '${r.handlerName} is heading there.'),
      if (mine && r.rescuerCalledAt != null) _Update(r.rescuerCalledAt!, 'Snake catcher called', '${r.handlerName} called the snake catcher.'),
      if (mine && r.onSiteAt != null) _Update(r.onSiteAt!, 'Admin at the spot', '${r.handlerName} has reached the spot.'),
      if (r.safe)
        r.outcome == Outcome.notFound
            ? _Update(
                r.resolvedAt!,
                'Snake not found after search',
                mine ? 'Tap if you see it again.' : 'It may still be nearby. Stay alert.',
              )
            : _Update(
                r.resolvedAt!,
                'Area marked safe',
                mine && r.reporterConfirmed == null ? 'Tap to confirm it’s clear.' : 'Safe to pass.',
              ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cards = <_Card>[
      for (final r in s.reports) _Card(_updates(s, r).last.time, 'SNAKE ALERT', report: r),
      _Card(
        DateTime.now().subtract(const Duration(days: 1)),
        'GATELOG',
        title: 'Gatelog entry approved',
        body: "Your 'To City' request for 6 September was approved.",
      ),
      _Card(
        DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        'CAB SHARING',
        title: 'Someone joined your ride',
        body: 'Rohit K. joined your 6:30 AM cab to Guwahati Airport.',
      ),
    ]..sort((a, b) => b.time.compareTo(a.time));
    final snakeCards = cards.where((c) => c.report != null).toList();
    final shown = cards
        .where((c) => _filter == 'All' || c.source == _filter.toUpperCase())
        .where((c) => _filter != 'Snake Alert' || _snake.matches(c.report!))
        .toList();
    // Sections, so the student can tell their own reports from everyone else's.
    final sections = [
      ('YOUR REPORTS', shown.where((c) => c.report != null && s.isMine(c.report!)).toList()),
      ('ALERTS NEAR YOU', shown.where((c) => c.report != null && !s.isMine(c.report!)).toList()),
      ('OTHER', shown.where((c) => c.report == null).toList()),
    ];

    return DarkPage(
      header: const AppHeader('Notifications'),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in ['All', 'Snake Alert', 'Cab Sharing', 'Gatelog'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      showCheckmark: false,
                      label: Text(f, style: ft(13, w: 600, color: _filter == f ? C.greenInk : C.sub)),
                      selectedColor: C.green,
                      backgroundColor: C.card,
                      side: BorderSide(color: _filter == f ? C.green : C.line2),
                      shape: const StadiumBorder(),
                    ),
                  ),
              ],
            ),
          ),
          // Snake types, only under "Snake Alert".
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _filter != 'Snake Alert'
                ? const SizedBox(width: double.infinity)
                : SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      children: [
                        for (final f in _SnakeFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _TypeChip(
                              f,
                              count: snakeCards.where((c) => f.matches(c.report!)).length,
                              selected: _snake == f,
                              onTap: () => setState(() => _snake = _snake == f ? _SnakeFilter.all : f),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                for (final (title, list) in sections)
                  if (list.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 6, 0, 10),
                      child: Row(
                        children: [
                          if (title == 'YOUR REPORTS') ...[
                            const Icon(Icons.person_rounded, size: 15, color: Color(0xFF8AB4FF)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            title,
                            style: ft(11.5, w: 700, color: title == 'YOUR REPORTS' ? const Color(0xFF8AB4FF) : C.muted, ls: 1.2),
                          ),
                          const SizedBox(width: 6),
                          Text('${list.length}', style: ft(11.5, w: 600, color: C.faint)),
                        ],
                      ),
                    ),
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: c.report == null ? _plain(c) : _reportCard(context, s, c.report!),
                      ),
                    const SizedBox(height: 8),
                  ],
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Text(
                      _snake == _SnakeFilter.all ? 'No snake reports right now.' : 'No ${_snake.label.toLowerCase()} reports right now.',
                      textAlign: TextAlign.center,
                      style: ft(13.5, color: C.muted),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Snake Alert alerts can be turned off in Profile › Notification preferences.',
                  textAlign: TextAlign.center,
                  style: ft(11.5, color: C.faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plain(_Card c) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(c.source, style: ft(10.5, w: 700, color: C.muted, ls: 1)),
            Text('  ·  ${ago(c.time)}', style: ft(11, color: C.faint)),
          ],
        ),
        const SizedBox(height: 6),
        Text(c.title!, style: ft(15, w: 700)),
        const SizedBox(height: 3),
        Text(c.body!, style: ft(13, color: C.muted, height: 1.4)),
      ],
    ),
  );

  /// One card per report: the latest update, and the rest behind "n updates".
  Widget _reportCard(BuildContext context, AppState s, Report r) {
    final ups = _updates(s, r);
    final latest = ups.last;
    final open = _open.contains(r.id);
    final toggle = ups.length < 2
        ? null
        : InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => open ? _open.remove(r.id) : _open.add(r.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${ups.length} updates', style: ft(12.5, w: 600, color: C.sub)),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: C.sub),
                  ),
                ],
              ),
            ),
          );
    final mine = s.isMine(r);
    return Panel(
      padding: EdgeInsets.zero,
      // The student's own reports get a blue border and tint.
      color: mine ? const Color(0xFF141B27) : C.card,
      border: mine ? const Color(0xFF2E4A78) : null,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SightingDetailScreen(report: r))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: status and time on the left, the updates drop-down on the right.
            Row(
              children: [
                if (r.covered) StatusChip(r) else Text('SNAKE ALERT', style: ft(10.5, w: 700, color: C.green, ls: 1)),
                Text('  ·  ${ago(latest.time)}', style: ft(11, color: C.faint)),
                const Spacer(),
                ?toggle,
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SnakeThumb(r, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(latest.title, style: ft(15, w: 700)),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (s.isMine(r))
                              TextSpan(text: 'Your report · ', style: ft(13, w: 600, color: const Color(0xFF8AB4FF))),
                            TextSpan(text: '${r.title} · ${r.where}'),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ft(13, color: C.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !open
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 8, 0),
                      child: Column(
                        children: [
                          for (final (i, u) in ups.reversed.indexed) _UpdateRow(u, newest: i == 0, last: i == ups.length - 1),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Snake-type filter under "Snake Alert". "Open area" is anywhere with no
/// authority (fields, roads, lakes); the others are by venom.
enum _SnakeFilter {
  all('All snakes'),
  venomous('Venomous'),
  nonVenomous('Non-venomous'),
  unsure('Not sure'),
  openArea('Open area');

  final String label;
  const _SnakeFilter(this.label);

  bool matches(Report r) => switch (this) {
    _SnakeFilter.all => true,
    _SnakeFilter.venomous => r.venom == Venom.venomous,
    _SnakeFilter.nonVenomous => r.venom == Venom.nonVenomous,
    _SnakeFilter.unsure => r.venom == Venom.unsure,
    _SnakeFilter.openArea => !r.covered,
  };
}

/// Small chip for one snake type, with the map's pin colour and a count.
class _TypeChip extends StatelessWidget {
  final _SnakeFilter f;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(this.f, {required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dot = switch (f) {
      _SnakeFilter.all => null,
      _SnakeFilter.venomous => pinVenomous,
      _SnakeFilter.nonVenomous => pinNonVenomous,
      _SnakeFilter.unsure => pinUnsure,
      _SnakeFilter.openArea => const Color(0xFF8A8A8A),
    };
    return Material(
      color: selected ? const Color(0xFF2A2A2A) : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected ? const Color(0xFF555555) : C.line2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (f == _SnakeFilter.openArea)
                const Icon(Icons.park_outlined, size: 13, color: C.muted)
              else if (dot != null)
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              if (dot != null) const SizedBox(width: 6),
              Text(f.label, style: ft(12.5, w: selected ? 600 : 500, color: selected ? C.text : C.sub)),
              const SizedBox(width: 5),
              Text('$count', style: ft(12, w: 600, color: selected ? C.sub : C.faint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Update {
  final DateTime time;
  final String title, body;
  _Update(this.time, this.title, this.body);
}

class _Card {
  final DateTime time;
  final String source;
  final Report? report;
  final String? title, body;
  _Card(this.time, this.source, {this.report, this.title, this.body});
}

/// One earlier update in an opened notification: dot, time, title and text.
class _UpdateRow extends StatelessWidget {
  final _Update u;
  final bool newest, last;
  const _UpdateRow(this.u, {required this.newest, required this.last});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 12,
          child: Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(color: newest ? C.green : const Color(0xFF555555), shape: BoxShape.circle),
              ),
              if (!last) Expanded(child: Container(width: 1.5, color: const Color(0xFF333333))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(u.title, style: ft(13.5, w: 600, color: newest ? C.text : C.sub))),
                    Text(clock(u.time), style: ft(11.5, color: C.faint)),
                  ],
                ),
                const SizedBox(height: 1),
                Text(u.body, style: ft(12, color: C.muted, height: 1.35)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
