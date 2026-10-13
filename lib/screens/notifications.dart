import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sighting_detail.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final items = <_Item>[
      for (final r in s.reports)
        _Item(
          'SNAKE ALERT',
          r.time,
          r.safe
              ? (r.outcome == Outcome.notFound ? 'Snake not found after search' : 'Area marked safe')
              : (r.venom == Venom.venomous ? 'Venomous snake reported' : 'Snake sighting reported'),
          r.safe
              ? (r.outcome == Outcome.notFound
                    ? '${r.where} was searched but the snake wasn’t found. Stay alert nearby.'
                    : '${r.where} has been checked and marked safe. Safe to pass.')
              : '${r.title} spotted near ${r.where}. Avoid the area until it is marked safe.',
          report: r,
        ),
      // Updates on the student's own reports, one per response step.
      for (final r in s.reports.where(s.isMine))
        for (final (at, title, body) in [
          if (r.seenAt != null) (r.seenAt!, 'Your report was seen', '${r.handlerName} has opened your report on ${r.title}.'),
          if (r.onTheWayAt != null) (r.onTheWayAt!, 'Authority on the way', '${r.handlerName} is heading to ${r.where}.'),
          if (r.rescuerCalledAt != null)
            (r.rescuerCalledAt!, 'Snake catcher called', '${r.handlerName} has called the snake catcher for ${r.where}.'),
          if (r.onSiteAt != null) (r.onSiteAt!, 'Authority at the spot', '${r.handlerName} has reached ${r.where}.'),
          if (r.safe && r.reporterConfirmed == null)
            r.outcome == Outcome.notFound
                ? (r.resolvedAt!, 'Have you seen the snake again?', 'It wasn’t found at ${r.where}. Tap if it’s still there.')
                : (r.resolvedAt!, 'Is the area clear now?', '${r.where} was marked safe. Tap to confirm, or tell us if the snake is still there.'),
        ])
          _Item('SNAKE ALERT', at, title, body, report: r),
      _Item(
        'GATELOG',
        DateTime.now().subtract(const Duration(days: 1)),
        'Gatelog entry approved',
        "Your 'To City' request for 6 September was approved.",
      ),
      _Item(
        'CAB SHARING',
        DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        'Someone joined your ride',
        'Rohit K. joined your 6:30 AM cab to Guwahati Airport.',
      ),
    ]..sort((a, b) => b.time.compareTo(a.time));
    final shown = items.where((i) => _filter == 'All' || i.source == _filter.toUpperCase()).toList();

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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                for (final i in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      onTap: i.report == null
                          ? null
                          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SightingDetailScreen(report: i.report!))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(i.source, style: ft(10.5, w: 700, color: i.report == null ? C.muted : C.green, ls: 1)),
                              Text('  ·  ${ago(i.time)}', style: ft(11, color: C.faint)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(i.title, style: ft(15, w: 700)),
                          const SizedBox(height: 3),
                          Text(i.body, style: ft(13, color: C.muted, height: 1.4)),
                        ],
                      ),
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
}

class _Item {
  final String source, title, body;
  final DateTime time;
  final Report? report;
  _Item(this.source, this.time, this.title, this.body, {this.report});
}
