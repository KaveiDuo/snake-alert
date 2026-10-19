import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../data/places.dart';
import '../data/species.dart';
import '../theme.dart';
import '../widgets/campus_map.dart';
import '../widgets/common.dart';
import '../widgets/response.dart';
import '../widgets/scroll_arrows.dart';
import '../widgets/snake_camera.dart';
import 'identify.dart';
import 'sighting_detail.dart';
import 'snake_watch.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Timer? _finding;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    if (s.draft.loc == null) {
      // Simulated GPS fix.
      _finding = Timer(const Duration(milliseconds: 1300), () {
        if (mounted && s.draft.loc == null) s.setDraftLoc(s.currentLoc);
      });
    }
  }

  @override
  void dispose() {
    _finding?.cancel();
    _note.dispose();
    CameraWarmup.release();
    super.dispose();
  }

  Future<void> _changeLocation() async {
    final loc = await showModalBottomSheet<Loc>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationSheet(),
    );
    if (loc != null && mounted) AppScope.read(context).setDraftLoc(loc);
  }

  void _submit() {
    final s = AppScope.read(context);
    s.draft.note = _note.text.trim();
    final r = s.submit();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReportedScreen(report: r)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.draft;
    final loc = d.loc;
    final step = loc == null ? 0 : (d.venom == null ? 1 : 2);
    return DarkPage(
      header: const AppHeader('Report a sighting'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= step ? C.green : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C170C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF3A2E14)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: C.amber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Keep 3 m back. Do not approach or try to move the snake.',
                          style: ft(12.5, color: const Color(0xFFD9B86A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _WhereCard(loc: loc, onChange: _changeLocation),
                const SizedBox(height: 20),
                if (loc != null && d.venom == null) ...[
                  Text('Is it venomous?', style: ft(20, w: 700)),
                  const SizedBox(height: 6),
                  Text('Choose the closest match. You can change it later.', style: ft(13, color: C.muted)),
                  const SizedBox(height: 14),
                  _VenomOption(Venom.venomous, 'Venomous', 'Cobra, krait, viper or similar', pinVenomous),
                  _VenomOption(Venom.nonVenomous, 'Non‑venomous', 'Rat snake, keelback, wolf snake…', pinNonVenomous),
                  _VenomOption(Venom.unsure, 'Not sure', 'We alert everyone as venomous to be safe', pinUnsure),
                ],
                if (loc != null && d.venom != null) ...[
                  // "Which snake?" is showing: get the camera ready for the scanner.
                  if (d.photoPath == null) _WarmCamera(),
                  _SummaryRow(venom: d.venom!, onChange: () => setState(() => d.venom = null)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Which snake?', style: ft(20, w: 700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(8)),
                        child: Text('optional', style: ft(11, color: C.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Helps the authority prepare.', style: ft(13, color: C.muted)),
                  const SizedBox(height: 14),
                  if (d.photoPath != null)
                    _PhotoAttached(
                      path: d.photoPath!,
                      matchedId: d.matchedId,
                      matchedName: d.matchedName,
                      scanning: d.scanning,
                      onRemove: () => s.setPhoto(null),
                    )
                  else
                    // One way in: the scanner (take or pick a photo, identified automatically).
                    // The scan result can also attach just the photo.
                    _PhotoAction(() async {
                      final res = await Navigator.push<IdentifyResult>(
                        context,
                        // Quick fade so the scanner appears straight away.
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 140),
                          reverseTransitionDuration: const Duration(milliseconds: 140),
                          pageBuilder: (_, _, _) => const IdentifyScreen(forReport: true),
                          transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
                        ),
                      );
                      if (res != null) s.setPhoto(res.photoPath, matchedId: res.speciesId, matchedName: res.name, venom: res.venom);
                    }),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 132,
                    // ‹ › arrows show there are more snakes to either side.
                    child: ScrollArrows(
                      children: [
                        for (final sp in species.where((x) => d.venom == Venom.unsure || x.venomous == (d.venom == Venom.venomous)))
                          _SpeciesCard(sp: sp, selected: d.speciesId == sp.id, onTap: () => s.setSpecies(sp.id)),
                        _CouldntTell(selected: d.speciesId == null, onTap: () => s.setSpecies(null)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _note,
                    minLines: 1,
                    maxLines: 3,
                    style: ft(14),
                    cursorColor: C.green,
                    decoration: InputDecoration(
                      hintText: 'Add a note — where exactly, what it did (optional)',
                      hintStyle: ft(13.5, color: C.faint),
                      filled: true,
                      fillColor: C.card,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: C.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: C.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: C.green),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: C.line)),
            ),
            child: Column(
              children: [
                Btn('Report sighting', kind: BtnKind.danger, onTap: loc != null && d.venom != null ? _submit : null),
                const SizedBox(height: 8),
                Text(
                  loc == null
                      ? 'Waiting for your location…'
                      : d.venom == null
                      ? 'Answer the question above to continue'
                      : loc.covered
                      ? 'Alerts the ${loc.authority} and students nearby'
                      : 'Pin only · alerts students nearby, no authority for open areas',
                  style: ft(11.5, color: C.muted),
                  textAlign: TextAlign.center,
                ),
                if (d.venom != null) Text('Posted as Ananya S. · ${s.studentEmail}', style: ft(11, color: C.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhereCard extends StatelessWidget {
  final Loc? loc;
  final VoidCallback onChange;
  const _WhereCard({required this.loc, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final l = loc;
    final icon = l == null
        ? null
        : l.source.startsWith('Detected') || l.source.startsWith('Demo location')
        ? Icons.my_location_rounded
        : l.source.startsWith('Pinned')
        ? Icons.push_pin_outlined
        : Icons.list_alt_rounded;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: C.greenSoft, shape: BoxShape.circle),
            child: l == null
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2, color: C.green),
                  )
                : const Icon(Icons.location_on_outlined, color: C.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l?.name ?? 'Finding your location…', style: ft(16, w: 700)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (icon != null) ...[Icon(icon, size: 13, color: C.green), const SizedBox(width: 5)],
                    Flexible(
                      child: Text(l?.source ?? 'Using your phone’s GPS', style: ft(12.5, color: l == null ? C.muted : C.green)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(l == null ? 'Choose place' : 'Change', style: ft(14, w: 600, color: C.green)),
          ),
        ],
      ),
    );
  }
}

class _VenomOption extends StatelessWidget {
  final Venom v;
  final String title, sub;
  final Color dot;
  const _VenomOption(this.v, this.title, this.sub, this.dot);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      onTap: () => AppScope.read(context).setVenom(v),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ft(15.5, w: 600)),
                const SizedBox(height: 2),
                Text(sub, style: ft(12.5, color: C.muted)),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4A4A4A), width: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final Venom venom;
  final VoidCallback onChange;
  const _SummaryRow({required this.venom, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (venom) {
      Venom.venomous => ('Venomous', pinVenomous),
      Venom.nonVenomous => ('Non-venomous', pinNonVenomous),
      Venom.unsure => ('Not sure', pinUnsure),
    };
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: ft(15, w: 600))),
          TextButton(
            onPressed: onChange,
            child: Text('Change', style: ft(14, w: 600, color: C.green)),
          ),
        ],
      ),
    );
  }
}

/// "Scan to identify": opens the scanner, where the student takes a photo or
/// picks one from the gallery and the snake is identified straight away.
class _PhotoAction extends StatelessWidget {
  final VoidCallback onTap;
  const _PhotoAction(this.onTap);
  @override
  Widget build(BuildContext context) => Material(
    color: C.greenSoft,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF245A36)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.green.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.center_focus_strong_outlined, size: 20, color: C.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan to identify', style: ft(15, w: 700, color: C.greenText)),
                  const SizedBox(height: 2),
                  Text('Take a photo or pick from gallery', style: ft(12, color: C.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.greenText),
          ],
        ),
      ),
    ),
  );
}

class _PhotoAttached extends StatelessWidget {
  final String path;
  final String? matchedId;
  final String? matchedName;
  final bool scanning;
  final VoidCallback onRemove;
  const _PhotoAttached({required this.path, required this.matchedId, this.matchedName, this.scanning = false, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      border: const Color(0xFF245A36),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 52, height: 52, child: photoOf(path)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Photo attached', style: ft(14.5, w: 600)),
                if (matchedId != null) Text('Matched ${speciesById(matchedId!).name}', style: ft(12.5, color: C.green)),
                if (matchedId == null && matchedName != null) Text('Matched $matchedName', style: ft(12.5, color: C.green)),
                if (scanning)
                  Row(
                    children: [
                      const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.6, color: C.amber)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Identifying… you can report now', style: ft(12.5, color: C.amber))),
                    ],
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRemove,
            child: Text('Remove', style: ft(13, w: 600, color: C.redText)),
          ),
        ],
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final Species sp;
  final bool selected;
  final VoidCallback onTap;
  const _SpeciesCard({required this.sp, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? C.green : Colors.transparent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(width: 92, height: 72, child: Image.asset(sp.photo, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sp.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ft(12, w: selected ? 700 : 500, color: selected ? C.green : C.text, height: 1.2),
          ),
          Text(
            sp.latin,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ft(10, color: C.faint).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    ),
  );
}

class _CouldntTell extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _CouldntTell({required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 76,
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? C.green : C.line, width: selected ? 2 : 1),
            ),
            alignment: Alignment.center,
            child: Text('?', style: ft(28, w: 700, color: C.muted)),
          ),
          const SizedBox(height: 5),
          Text(
            "Couldn't tell",
            style: ft(12, w: selected ? 700 : 500, color: selected ? C.green : C.text),
          ),
          Text('no photo needed', style: ft(10, color: C.faint)),
        ],
      ),
    ),
  );
}

/// "Select location" bottom sheet with working search.
class LocationSheet extends StatefulWidget {
  const LocationSheet({super.key});
  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final q = _q.toLowerCase();
    // Tapping the dimmed area above the sheet closes it (the draggable sheet
    // fills the whole modal, so the normal barrier tap never reaches it).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, scroll) => GestureDetector(
          onTap: () {}, // taps inside the sheet don't close it
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1B1B1B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: C.line2)),
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Select location', style: ft(20, w: 700))),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF262626)),
                      icon: const Icon(Icons.close_rounded, color: C.sub, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: ft(14.5),
                  cursorColor: C.green,
                  decoration: InputDecoration(
                    hintText: 'Search hostels and campus places',
                    hintStyle: ft(14, color: C.faint),
                    prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
                    filled: true,
                    fillColor: const Color(0xFF262626),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                if (q.isEmpty) ...[
                  _SheetAction(Icons.my_location_rounded, 'Use my current location', () => Navigator.pop(context, s.currentLoc)),
                  const SizedBox(height: 10),
                  _SheetAction(Icons.map_outlined, 'Pick the exact spot on the map', () async {
                    final loc = await Navigator.push<Loc>(context, MaterialPageRoute(builder: (_) => PickOnMapScreen(start: s.draft.loc)));
                    if (loc != null && context.mounted) Navigator.pop(context, loc);
                  }),
                ],
                for (final g in placeGroups) ...[
                  if (g.places.any((p) => p.label.toLowerCase().contains(q))) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 22, 0, 6),
                      child: Row(
                        children: [
                          Text(g.title, style: ft(11.5, w: 700, color: C.muted, ls: 1.2)),
                          if (!g.covered) ...[const SizedBox(width: 8), Text('· pin only, no authority', style: ft(11, color: C.faint))],
                        ],
                      ),
                    ),
                    for (final p in g.places.where((p) => p.label.toLowerCase().contains(q)))
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, s.locFromList(p, g.covered)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: C.muted, size: 20),
                              const SizedBox(width: 14),
                              Expanded(child: Text(p.label, style: ft(15.5))),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetAction(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
    color: C.greenSoft,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF245A36)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: C.green, size: 20),
            const SizedBox(width: 12),
            Text(label, style: ft(15, w: 600, color: C.greenText)),
          ],
        ),
      ),
    ),
  );
}

/// Tap anywhere on the map to drop the pin. Only Kameng Hostel's boundary is
/// drawn in this demo, so taps outside it count as an open area.
class PickOnMapScreen extends StatefulWidget {
  final Loc? start;
  const PickOnMapScreen({super.key, this.start});
  @override
  State<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends State<PickOnMapScreen> {
  late Loc _loc = widget.start ?? AppScope.read(context).currentLoc;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return DarkPage(
      header: const AppHeader('Pick the exact spot'),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CampusMap(
                dark: s.mapDark,
                selected: _loc.pos,
                onToggleTheme: s.toggleMap,
                onTapMap: (p) => setState(() => _loc = s.locFromMap(p)),
                topHint: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: s.mapDark ? const Color(0xE61C1C1C) : const Color(0xF2FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: s.mapDark ? C.line2 : const Color(0xFFDDDDDD)),
                  ),
                  child: Text(
                    'Tap the map to mark exactly where you saw it',
                    textAlign: TextAlign.center,
                    style: ft(12, color: s.mapDark ? C.text : const Color(0xFF222222)),
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF141A16),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: C.line2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _loc.outside ? C.redSoft : (_loc.covered ? C.greenSoft : const Color(0xFF2A1E0B)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _loc.outside ? Icons.block_rounded : (_loc.covered ? Icons.location_on_outlined : Icons.park_outlined),
                        color: _loc.outside ? C.redText : (_loc.covered ? C.green : C.amber),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_loc.name, style: ft(17, w: 700)),
                          const SizedBox(height: 3),
                          Text(
                            _loc.outside
                                ? 'Snake Alert only takes reports inside the campus. Move the pin onto campus.'
                                : _loc.covered
                                ? 'Inside ${_loc.name} premises · the ${_loc.name} authority covers this spot'
                                : 'Open area · pin only. No authority is notified; students nearby still see it',
                            style: ft(12.5, color: C.muted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Btn('Use this spot', onTap: _loc.outside ? null : () => Navigator.pop(context, _loc)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportedScreen extends StatefulWidget {
  final Report report;
  const ReportedScreen({super.key, required this.report});
  @override
  State<ReportedScreen> createState() => _ReportedScreenState();
}

class _ReportedScreenState extends State<ReportedScreen> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _a.dispose();
    _ripple.dispose();
    super.dispose();
  }

  /// Green check with two rings and a soft glow (matches Figma "13 · Sighting reported").
  Widget _hero() => SizedBox(
    width: 230,
    height: 230,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // A faint ring that keeps rippling outward
        AnimatedBuilder(
          animation: _ripple,
          builder: (_, _) {
            final t = Curves.easeOut.transform(_ripple.value);
            return Container(
              width: 150 + 80 * t,
              height: 150 + 80 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: C.green.withValues(alpha: 0.35 * (1 - t)), width: 1.5),
              ),
            );
          },
        ),
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: C.green.withValues(alpha: 0.16), width: 1.5),
          ),
        ),
        Container(
          width: 156,
          height: 156,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.green.withValues(alpha: 0.06),
            border: Border.all(color: C.green.withValues(alpha: 0.38), width: 2),
          ),
        ),
        ScaleTransition(
          scale: CurvedAnimation(parent: _a, curve: Curves.elasticOut),
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: C.green,
              boxShadow: [BoxShadow(color: C.green.withValues(alpha: 0.45), blurRadius: 36, spreadRadius: 2)],
            ),
            child: const Icon(Icons.check_rounded, color: C.greenInk, size: 56),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // follow the authority's response live
    final r = widget.report;
    return DarkPage(
      body: Stack(
        children: [
          // Soft green glow behind the check
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(0, -0.32),
                child: Container(
                  width: 520,
                  height: 520,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [C.green.withValues(alpha: 0.30), C.green.withValues(alpha: 0.0)]),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            // Extra bottom space so the buttons sit comfortably above the edge.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: Column(
              children: [
                const Spacer(flex: 4),
                _hero(),
                const SizedBox(height: 22),
                Text('Sighting reported', style: ft(30, w: 700)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Students nearby have been notified and can see your pin on Snake Alert.',
                    textAlign: TextAlign.center,
                    style: ft(14.5, color: C.muted, height: 1.45),
                  ),
                ),
                const Spacer(flex: 3),
                // Who handles it: the hostel's authority (in their console), or
                // nobody for open areas, where the pin expires by itself.
                Panel(
                  border: r.covered ? const Color(0xFF245A36) : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.covered ? Icons.verified_user_outlined : Icons.schedule_rounded, color: C.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.covered ? 'Sent to the ${r.place} authority' : '${r.place} · open area', style: ft(13.5, w: 600)),
                            const SizedBox(height: 4),
                            Text(
                              r.covered
                                  ? 'They must reach the spot within ${respondWithin.inMinutes} min and send a photo when it’s safe. You’ll see every step.'
                                  : 'No authority is notified for open areas. Students nearby can see your pin, and it clears itself after 2–3 days.',
                              style: ft(12.5, color: C.muted, height: 1.4),
                            ),
                            if (r.covered) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SightingDetailScreen(report: r))),
                                child: Row(
                                  children: [
                                    StatusChip(r),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        r.statusLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ft(12.5, w: 600, color: C.sub),
                                      ),
                                    ),
                                    Text('Track', style: ft(12.5, w: 700, color: C.green)),
                                    const Icon(Icons.chevron_right_rounded, size: 18, color: C.green),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.covered) ...[
                  const SizedBox(height: 12),
                  Btn(
                    'Call the authority now',
                    kind: BtnKind.danger,
                    icon: Icons.call_rounded,
                    height: 50,
                    onTap: () async {
                      if (!await launchUrl(Uri.parse('tel:$authorityPhone')) && context.mounted) {
                        toast(context, 'Could not open the dialler');
                      }
                    },
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Btn('Home', kind: BtnKind.ghost, height: 48, onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Btn(
                        'Snake Alert',
                        kind: BtnKind.ghost,
                        height: 48,
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.popUntil((r) => r.isFirst);
                          nav.push(MaterialPageRoute(builder: (_) => const SnakeWatchScreen()));
                        },
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
}

/// Invisible: starts the camera in the background once, so the scanner opens
/// with a live view straight away (see CameraWarmup).
class _WarmCamera extends StatefulWidget {
  @override
  State<_WarmCamera> createState() => _WarmCameraState();
}

class _WarmCameraState extends State<_WarmCamera> {
  @override
  void initState() {
    super.initState();
    CameraWarmup.prepare();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
