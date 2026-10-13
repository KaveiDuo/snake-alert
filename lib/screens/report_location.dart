import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/campus_map.dart';
import '../widgets/common.dart';
import 'sighting_detail.dart';

/// Where a report is: the campus map framed on its pin and on you, with
/// walking directions in Google Maps.
class ReportLocationScreen extends StatelessWidget {
  final Report report;
  const ReportLocationScreen({super.key, required this.report});

  Future<void> _directions(BuildContext context) async {
    final p = report.pos;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}&travelmode=walking');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && context.mounted) {
      toast(context, 'Could not open Google Maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = report;
    final d = s.metresFromYou(r.pos);
    return DarkPage(
      header: AppHeader(r.title, subtitle: r.where),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: CampusMap(
                  dark: s.mapDark,
                  reports: [r],
                  focus: r.pos,
                  onToggleTheme: s.toggleMap,
                  onTapReport: (_) => Navigator.push(context, MaterialPageRoute(builder: (_) => SightingDetailScreen(report: r))),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: pinColor(r).withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: Icon(Icons.place_rounded, color: pinColor(r)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.where, style: ft(15, w: 600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          'About ${(d / 10).round() * 10} m from you · about ${(d / 80).ceil()} min on foot',
                          style: ft(12.5, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Btn('Get directions', icon: Icons.directions_walk_rounded, onTap: () => _directions(context)),
          ],
        ),
      ),
    );
  }
}
