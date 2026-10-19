import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_state.dart';
import '../data/scanner.dart';
import '../data/species.dart';
import '../theme.dart';
import '../widgets/common.dart';

class IdentifyResult {
  final String photoPath;

  /// Campus species id, or null when the match isn't one of them.
  final String? speciesId;
  final String? name;
  /// Null when only the photo is attached (the report's answer stays as it is).
  final Venom? venom;
  const IdentifyResult(this.photoPath, {this.speciesId, this.name, this.venom});
}

/// "Scan a snake": take or pick a photo, then AI (free Gemini by default)
/// names the species. If the app has no scanner key at all, a demo match
/// (Banded Krait) is shown instead.
class IdentifyScreen extends StatefulWidget {
  final bool forReport;
  const IdentifyScreen({super.key, this.forReport = false});
  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> with SingleTickerProviderStateMixin {
  String? _photo;
  Uint8List? _bytes;
  String _demoId = 'banded_krait';
  bool _scanning = false;
  bool _demo = false;
  ScanResult? _result;
  String? _error;
  int _pick = 0;
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    Scanner.warmUp(); // connect to the scanner while a photo is being picked
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _start(String photo, Future<Uint8List> Function() load, String demoId) async {
    setState(() {
      _photo = photo;
      _demoId = demoId;
      _scanning = true;
      _result = null;
      _error = null;
      _pick = 0;
    });
    _scan.repeat(reverse: true, period: const Duration(milliseconds: 900));
    // Real scans show their result as soon as it arrives; the demo keeps a
    // short scan so the animation is visible.
    ScanResult? result;
    String? error;
    final key = await Scanner.activeKey();
    _demo = key == null;
    if (key == null) {
      result = _demoResult(demoId);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    } else {
      try {
        _bytes ??= await load();
        result = await Scanner.identify(_bytes!, key);
      } on ScanException catch (e) {
        error = e.message;
      } catch (_) {
        error = 'Something went wrong while scanning. Try again.';
      }
    }
    if (!mounted) return;
    _scan.stop();
    setState(() {
      _scanning = false;
      _result = result;
      _error = error;
    });
  }

  ScanResult _demoResult(String id) {
    final others = ['wolf', 'cobra', 'keelback'].where((x) => x != id).take(2).toList();
    ScanMatch m(String id, int c) => ScanMatch(speciesId: id, name: speciesById(id).name, venomous: speciesById(id).venomous, confidence: c);
    return ScanResult(isSnake: true, matches: [m(id, 76), m(others[0], 18), m(others[1], 6)]);
  }

  Future<void> _pickImage(ImageSource src) async {
    // 1024 px is plenty to identify a snake and uploads much faster on mobile data.
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 75);
    if (x == null) return;
    _bytes = null;
    _start(x.path, x.readAsBytes, 'banded_krait');
  }

  void _retake() => setState(() {
    _photo = null;
    _bytes = null;
    _result = null;
    _error = null;
  });

  /// The whole photo, never cropped, on a blurred copy of itself.
  Widget _photoBox(String path) => Stack(
    fit: StackFit.expand,
    children: [
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: photoOf(path, fit: BoxFit.cover),
      ),
      Container(color: Colors.black.withValues(alpha: 0.3)),
      photoOf(path, fit: BoxFit.contain),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final title = _photo == null ? 'Scan a snake' : 'Identify snake';
    return DarkPage(
      header: AppHeader(title, backIcon: Icons.close_rounded),
      body: _photo == null ? _chooser() : (_scanning ? _scanner() : _resultView()),
    );
  }

  /// First screen: a scan frame, the two ways to get a photo, and three tips.
  Widget _chooser() => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight - 28),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scan frame: what the photo should look like.
              AspectRatio(
                aspectRatio: 1.15,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: C.line),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: Padding(padding: EdgeInsets.all(22), child: _ScanCorners())),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: C.greenSoft, shape: BoxShape.circle),
                              child: const Icon(Icons.center_focus_strong_outlined, color: C.green, size: 30),
                            ),
                            const SizedBox(height: 14),
                            Text('Photograph the snake', style: ft(17, w: 700)),
                            const SizedBox(height: 4),
                            Text('We’ll tell you what it is in a few seconds', style: ft(13, color: C.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Btn('Take a photo', icon: Icons.photo_camera_outlined, onTap: () => _pickImage(ImageSource.camera)),
              const SizedBox(height: 10),
              Btn('Choose from gallery', kind: BtnKind.ghost, icon: Icons.photo_library_outlined, onTap: () => _pickImage(ImageSource.gallery)),
              const SizedBox(height: 22),
              Text('FOR THE BEST RESULT', style: ft(11.5, w: 700, color: C.muted, ls: 1.2)),
              const SizedBox(height: 10),
              const _Tip(Icons.social_distance_outlined, 'Stay 3 m back and zoom in'),
              const _Tip(Icons.crop_free_rounded, 'Get the head and body pattern in the frame'),
              const _Tip(Icons.wb_sunny_outlined, 'Good light, hold steady, no blur'),
              const Spacer(),
              const SizedBox(height: 12),
              FutureBuilder<String?>(
                future: Scanner.activeKey(),
                builder: (context, snap) => snap.connectionState != ConnectionState.done
                    ? const SizedBox.shrink()
                    : Text(
                        snap.data == null
                            ? 'Demo mode: add a scanner key in Profile → Snake scanner key to identify photos for real.'
                            : 'Identified by AI · keep your distance whatever the result',
                        textAlign: TextAlign.center,
                        style: ft(12, color: snap.data == null ? C.amber : C.faint, height: 1.4),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _scanner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _photoBox(_photo!),
          AnimatedBuilder(
            animation: _scan,
            builder: (context, _) => Align(
              alignment: Alignment(0, -0.9 + 1.8 * _scan.value),
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: C.green,
                  boxShadow: [BoxShadow(color: C.green.withValues(alpha: 0.7), blurRadius: 18, spreadRadius: 2)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Text(
              'Matching against campus species…',
              textAlign: TextAlign.center,
              style: ft(13.5, w: 600, color: Colors.white).copyWith(shadows: const [Shadow(blurRadius: 8)]),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _resultView() {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(aspectRatio: 1.1, child: _photoBox(_photo!)),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Panel(
            border: const Color(0xFF5A2424),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: C.redText),
                const SizedBox(width: 12),
                Expanded(child: Text(_error!, style: ft(14, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Btn('Try again', onTap: () => _start(_photo!, () async => _bytes!, _demoId)),
        ] else if (r != null && !r.isSnake) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No snake found', style: ft(17, w: 700)),
                const SizedBox(height: 4),
                Text(r.note ?? 'The scanner couldn’t see a snake in this photo.', style: ft(13, color: C.muted, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (widget.forReport)
            Btn(
              'Use photo anyway',
              kind: BtnKind.ghost,
              onTap: () => Navigator.pop(context, IdentifyResult(_photo!, venom: Venom.unsure)),
            ),
        ] else if (r != null)
          ..._matches(r),
        const SizedBox(height: 8),
        Btn('Retake photo', kind: BtnKind.ghost, onTap: _retake),
        if (widget.forReport && _result != null && _result!.isSnake)
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, IdentifyResult(_photo!)),
              child: Text('Just attach the photo', style: ft(13, w: 600, color: C.muted)),
            ),
          ),
      ],
    );
  }

  List<Widget> _matches(ScanResult r) {
    final top = r.matches[_pick.clamp(0, r.matches.length - 1)];
    final others = [for (final (i, m) in r.matches.indexed) if (i != _pick) (i, m)];
    return [
      Panel(
        child: Row(
          children: [
            _thumb(top, 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _venomTag(top.venomous),
                  const SizedBox(height: 6),
                  Text(top.name, style: ft(17, w: 700)),
                  if (top.latin != null) Text(top.latin!, style: ft(12, color: C.muted).copyWith(fontStyle: FontStyle.italic)),
                  // Any species is a valid answer; just note when it's new for campus.
                  if (top.sp == null) Text('Not recorded on campus before', style: ft(12, color: C.muted)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: top.confidence / 100,
                            minHeight: 5,
                            color: _certainty(top.confidence).$2,
                            backgroundColor: const Color(0xFF2A2A2A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // The AI's own percentages aren't reliable (it was 90–95% sure of
                      // some wrong answers in testing), so show plain words instead.
                      Text(_certainty(top.confidence).$1, style: ft(12.5, w: 700, color: _certainty(top.confidence).$2)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (_lookAlike(top) case (final Species danger, final String tip)) ...[
        const SizedBox(height: 10),
        Panel(
          border: const Color(0xFF5A2424),
          color: const Color(0xFF1E1212),
          padding: const EdgeInsets.all(12),
          onTap: () => setState(() {
            // Put the venomous look-alike first so "Use this in my report" picks it.
            final i = r.matches.indexWhere((m) => m.speciesId == danger.id);
            if (i >= 0) {
              _pick = i;
            } else {
              r.matches.insert(0, ScanMatch(speciesId: danger.id, name: danger.name, latin: danger.latin, venomous: true, confidence: 0));
              _pick = 0;
            }
          }),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 48, height: 48, child: Image.asset(danger.photo, fit: BoxFit.cover)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Often confused with '),
                          TextSpan(text: danger.name, style: ft(13.5, w: 700, color: C.redText)),
                          const TextSpan(text: ' (venomous)'),
                        ],
                      ),
                      style: ft(13.5, w: 600),
                    ),
                    const SizedBox(height: 3),
                    Text('$tip If unsure, treat it as venomous.', style: ft(12, color: const Color(0xFFD9A8A6), height: 1.4)),
                    const SizedBox(height: 4),
                    Text('Tap if it looks like this one', style: ft(11.5, w: 600, color: C.redText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (top.confidence < 65) ...[
        const SizedBox(height: 10),
        Text(
          'The scanner isn’t sure. A clearer photo of the head and body pattern helps, or report it as “Not sure”.',
          style: ft(12.5, color: const Color(0xFFFFC46B), height: 1.4),
        ),
      ],
      const SizedBox(height: 10),
      if (r.note != null && r.note!.isNotEmpty) ...[
        Text(r.note!, style: ft(12.5, color: C.sub, height: 1.4)),
        const SizedBox(height: 6),
      ],
      Text(
        _demo
            ? 'Demo match, not a real scan. Add a scanner key in Profile → Snake scanner key to identify photos for real.'
            : 'AI match, not a diagnosis. Keep your distance and treat any snake you’re unsure of as venomous.',
        style: ft(12, color: _demo ? C.amber : C.muted, height: 1.4),
      ),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('OTHER POSSIBLE MATCHES', style: ft(11.5, w: 700, color: C.muted, ls: 1.2)),
        const SizedBox(height: 8),
        for (final (i, o) in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(10),
              onTap: () => setState(() => _pick = i),
              child: Row(
                children: [
                  _thumb(o, 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.name, style: ft(14.5, w: 600)),
                        Text(
                          o.venomous == null ? 'Venom unknown' : (o.venomous! ? 'Venomous' : 'Non-venomous'),
                          style: ft(12, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: C.muted),
                ],
              ),
            ),
          ),
      ],
      const SizedBox(height: 10),
      if (widget.forReport)
        Btn(
          'Use this in my report',
          onTap: () => Navigator.pop(
            context,
            IdentifyResult(
              _photo!,
              speciesId: top.speciesId,
              name: top.name,
              venom: top.venomous == null ? Venom.unsure : (top.venomous! ? Venom.venomous : Venom.nonVenomous),
            ),
          ),
        ),
    ];
  }

  /// Plain-language certainty for the AI's confidence.
  static (String, Color) _certainty(int c) => c >= 85
      ? ('Likely match', C.green)
      : c >= 65
      ? ('Possible match', const Color(0xFFFFC46B))
      : ('Not sure', const Color(0xFFFF8A8E));

  /// The venomous look-alike to warn about, when the match is a harmless snake
  /// that is often confused with one (and it isn't already the chosen match).
  static (Species, String)? _lookAlike(ScanMatch m) {
    if (m.venomous != false || m.speciesId == null) return null;
    final la = venomousLookAlikes[m.speciesId];
    return la == null ? null : (speciesById(la.$1), la.$2);
  }

  Widget _venomTag(bool? venomous) => switch (venomous) {
    true => const Tag('VENOMOUS', fg: C.redText, bg: C.redSoft),
    false => const Tag('NON-VENOMOUS', fg: C.greenText, bg: C.greenSoft),
    null => const Tag('NOT SURE', fg: Color(0xFFFFC46B), bg: Color(0xFF2A1E0B)),
  };

  Widget _thumb(ScanMatch m, double size) => ClipRRect(
    borderRadius: BorderRadius.circular(size > 50 ? 12 : 10),
    child: SizedBox(
      width: size,
      height: size,
      // Campus species show their reference photo; any other species shows the
      // student's own photo.
      child: m.sp != null ? Image.asset(m.sp!.photo, fit: BoxFit.cover) : photoOf(_photo!),
    ),
  );
}

/// One tip line on the scan screen.
class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: C.greenText),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: ft(13.5, color: C.sub))),
      ],
    ),
  );
}

/// Green corner brackets of a camera viewfinder.
class _ScanCorners extends StatelessWidget {
  const _ScanCorners();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CornersPainter());
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.green
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0, r = 14.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)]) {
      final path = Path()
        ..moveTo(x, y + dy * (l + r))
        ..lineTo(x, y + dy * r)
        ..quadraticBezierTo(x, y, x + dx * r, y)
        ..lineTo(x + dx * (l + r), y);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
