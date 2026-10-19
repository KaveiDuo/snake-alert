import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/app_state.dart';
import '../data/kv_buildings.dart';
import '../data/sports_areas.dart';
import '../data/quarters_buildings.dart';
import '../data/zones.dart';
import '../theme.dart';
import 'common.dart';
import 'pitch_tiles.dart';

/// Teardrop "location" pin with a white outline and a white centre dot.
/// The tip of the pin points at the reported spot.
class LocationPin extends StatelessWidget {
  final Color color;
  final double width;
  final bool shadow;
  const LocationPin({super.key, required this.color, this.width = 26, this.shadow = true});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, width * 1.3), painter: _PinPainter(color, shadow));
}

class _PinPainter extends CustomPainter {
  final Color color;
  final bool shadow;
  _PinPainter(this.color, this.shadow);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, r = w / 2;
    final path = Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * 0.36, h * 0.8, 0, h * 0.62, 0, r)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..cubicTo(w, h * 0.62, w * 0.64, h * 0.8, w / 2, h)
      ..close();
    if (shadow) canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08,
    );
    canvas.drawCircle(Offset(w / 2, r), w * 0.17, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.color != color || old.shadow != shadow;
}

/// Small name labels for the quarters and KV buildings we draw ourselves
/// (OpenStreetMap's tiles label everything else). Shown only when zoomed in.
class _BuildingLabels extends StatelessWidget {
  final bool dark;
  const _BuildingLabels({required this.dark});

  static const _named = {
    'A-type Quarters',
    'B-type Quarters',
    'C-type Quarters',
    'D-type Quarters',
    'E-type Quarters',
    'F-type Quarters',
    'Professors Quarters',
    'Tower Block',
    'B-type Community Hall',
    'D-type Community Hall',
    'Kendriya Vidyalaya (KV)',
    'KV Staff Quarters',
  };

  static final List<(String, LatLng)> _labels = [
    for (final z in campusZones)
      if (_named.contains(z.name))
        for (final o in z.outlines)
          (
            z.name == 'Kendriya Vidyalaya (KV)' ? 'Kendriya Vidyalaya' : z.name,
            LatLng(
              o.map((p) => p.latitude).reduce((a, b) => a + b) / o.length,
              o.map((p) => p.longitude).reduce((a, b) => a + b) / o.length,
            ),
          ),
  ];

  @override
  Widget build(BuildContext context) {
    if (MapCamera.of(context).zoom < 16.3) return const SizedBox.shrink();
    final halo = dark ? Colors.black : Colors.white;
    return MarkerLayer(
      markers: [
        for (final (name, at) in _labels)
          Marker(
            point: at,
            width: 130,
            height: 26,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: ft(10, w: 600, color: dark ? const Color(0xFFBDB2A8) : const Color(0xFF6B5B4E), height: 1.1).copyWith(
                    shadows: [
                      for (final o in const [Offset(1, 1), Offset(-1, -1), Offset(1, -1), Offset(-1, 1)]) Shadow(color: halo, offset: o),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Red hospital badge just above the tiles' "IITG Hospital" label. The tiles
/// only draw their own hospital symbol when zoomed out (tile zoom 15), so this
/// shows from there on in.
class _HospitalIcon extends StatelessWidget {
  const _HospitalIcon();

  static final LatLng _at = () {
    final o = campusZones.firstWhere((z) => z.name == 'IITG Hospital').outlines.first;
    return LatLng(
      o.map((p) => p.latitude).reduce((a, b) => a + b) / o.length,
      o.map((p) => p.longitude).reduce((a, b) => a + b) / o.length,
    );
  }();

  @override
  Widget build(BuildContext context) {
    if (MapCamera.of(context).zoom < 15.5) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        Marker(
          point: _at,
          width: 26,
          height: 26,
          // Sit above the label, which the tiles centre on the building.
          alignment: const Alignment(0, -2.2),
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5383B),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hides the darker outline the tiles draw around light-green sports grounds
/// by tracing it in the grounds' own colour. Only when zoomed in: further out
/// the outline is barely visible and the line would cut through the tiles'
/// campus-name label.
class _GroundOutlines extends StatelessWidget {
  final Color color;
  const _GroundOutlines({required this.color});

  @override
  Widget build(BuildContext context) {
    if (MapCamera.of(context).zoom < 16.5) return const SizedBox.shrink();
    return PolygonLayer(
      polygons: [for (final pts in sportsGroundShapes) Polygon(points: pts, borderColor: color, borderStrokeWidth: 3)],
    );
  }
}

/// Live campus map (OpenStreetMap tiles). Pinch/drag to move,
/// + / − to zoom, tap a pin to open it, tap anywhere else to pick that spot.
class CampusMap extends StatefulWidget {
  final bool dark;
  final List<Report> reports;
  final LatLng? selected;

  /// Opens framed on this spot and on you, without dropping a pin.
  final LatLng? focus;
  final void Function(LatLng point)? onTapMap;
  final void Function(Report r)? onTapReport;
  final EdgeInsets controlsPadding;
  final Widget? topHint;
  final VoidCallback? onToggleTheme;
  const CampusMap({
    super.key,
    required this.dark,
    this.reports = const [],
    this.selected,
    this.focus,
    this.onTapMap,
    this.onTapReport,
    this.controlsPadding = const EdgeInsets.all(10),
    this.topHint,
    this.onToggleTheme,
  });

  @override
  State<CampusMap> createState() => CampusMapState();
}

class CampusMapState extends State<CampusMap> with TickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  AnimationController? _move;
  final _tiles = PitchRecolorTileProvider();

  /// Colour of the tiles' own light-green sports grounds (#DFFCE2), and what
  /// it turns into under the dark-mode tile filter, so covered outlines blend
  /// in with them.
  Color get _groundFill => widget.dark ? const Color(0xFF001300) : const Color(0xFFDFFCE2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).startGps();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _move?.dispose();
    super.dispose();
  }

  /// Smoothly moves/zooms the camera.
  void _animateTo(LatLng dest, double zoom) {
    _move?.dispose();
    final cam = _map.camera;
    final lat = Tween(begin: cam.center.latitude, end: dest.latitude);
    final lng = Tween(begin: cam.center.longitude, end: dest.longitude);
    final z = Tween(begin: cam.zoom, end: zoom);
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    final a = CurvedAnimation(parent: c, curve: Curves.easeInOut);
    c.addListener(() => _map.move(LatLng(lat.evaluate(a), lng.evaluate(a)), z.evaluate(a)));
    _move = c..forward();
  }

  void zoom(double by) {
    final cam = _map.camera;
    _animateTo(cam.center, (cam.zoom + by).clamp(14.5, 19.0));
  }

  void centerOn(LatLng p) => _animateTo(p, _map.camera.zoom < 17 ? 17 : _map.camera.zoom);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: widget.dark ? const Color(0xFF1A1A1A) : const Color(0xFFEDEBE6),
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: widget.selected ?? widget.focus ?? const LatLng(26.1888, 91.6962),
                  initialZoom: widget.selected != null || widget.focus != null ? 17.2 : 15.6,
                  // Open zoomed so the focused spot, or every report, fits on screen with you.
                  initialCameraFit: widget.selected == null && (widget.focus != null || widget.reports.isNotEmpty)
                      ? CameraFit.coordinates(
                          coordinates: widget.focus != null ? [widget.focus!, s.you] : [for (final r in widget.reports) r.pos, s.you],
                          padding: const EdgeInsets.fromLTRB(50, 100, 70, 90),
                          maxZoom: widget.focus != null ? 18 : 17.5,
                        )
                      : null,
                  minZoom: 14.5,
                  maxZoom: 19,
                  cameraConstraint: CameraConstraint.containCenter(bounds: campusBounds),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, p) => widget.onTapMap?.call(p),
                ),
                children: [
                  // Standard OpenStreetMap tiles (free, no key). Night mode
                  // darkens them with flutter_map's dark-mode tile filter.
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'in.iitg.onestop.snake_watch',
                    tileProvider: _tiles,
                    maxZoom: 19,
                    tileBuilder: widget.dark ? darkModeTileBuilder : null,
                  ),
                  // KV buildings aren't in OpenStreetMap yet, so draw them in the
                  // same style as the map's other buildings.
                  _GroundOutlines(color: _groundFill),
                  PolygonLayer(
                    polygons: [
                      // Faculty & staff quarters: a little more see-through than KV.
                      for (final pts in quartersBuildingShapes)
                        Polygon(
                          points: pts,
                          color: (widget.dark ? const Color(0xFF3B3835) : const Color(0xFFD9D0C9)).withValues(alpha: 0.6),
                          borderColor: (widget.dark ? const Color(0xFF4A4541) : const Color(0xFFC4B6AB)).withValues(alpha: 0.6),
                          borderStrokeWidth: 1,
                        ),
                      for (final pts in kvBuildingShapes)
                        Polygon(
                          points: pts,
                          color: widget.dark ? const Color(0xFF3B3835) : const Color(0xFFD9D0C9),
                          borderColor: widget.dark ? const Color(0xFF4A4541) : const Color(0xFFC4B6AB),
                          borderStrokeWidth: 1,
                        ),
                      for (final pts in kvWaterShapes)
                        Polygon(points: pts, color: widget.dark ? const Color(0xFF1F3440) : const Color(0xFFAAD3DF)),
                    ],
                  ),
                  _BuildingLabels(dark: widget.dark),
                  const _HospitalIcon(),
                  MarkerLayer(
                    markers: [
                      Marker(point: s.you, width: 44, height: 44, child: _you(s.gps)),
                      for (final r in widget.reports)
                        Marker(
                          point: r.pos,
                          width: 48,
                          height: _pinH + 8,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(onTap: () => widget.onTapReport?.call(r), child: _pin(r)),
                        ),
                      if (widget.selected != null)
                        Marker(
                          point: widget.selected!,
                          width: 30,
                          height: 39,
                          alignment: Alignment.topCenter,
                          child: const LocationPin(color: pinDropped, width: 30),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.topHint != null) Positioned(left: 10, top: 10, right: 58, child: widget.topHint!),
          Positioned(
            right: widget.controlsPadding.right,
            top: widget.controlsPadding.top,
            child: Column(
              children: [_ctl(Icons.add_rounded, () => zoom(1)), const SizedBox(height: 6), _ctl(Icons.remove_rounded, () => zoom(-1))],
            ),
          ),
          Positioned(
            right: widget.controlsPadding.right,
            bottom: widget.controlsPadding.bottom + 14,
            child: Column(
              children: [
                _ctl(s.gps == GpsState.onCampus ? Icons.my_location_rounded : Icons.location_searching_rounded, () {
                  centerOn(s.you);
                  if (s.gps == GpsState.offCampus) toast(context, 'You’re not on campus — showing a demo location near Kameng');
                  if (s.gps == GpsState.denied) toast(context, 'Location is off — showing a demo location near Kameng');
                }, color: C.blue),
                if (widget.onToggleTheme != null) ...[
                  const SizedBox(height: 8),
                  _ctl(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, widget.onToggleTheme!),
                ],
              ],
            ),
          ),
          Positioned(
            right: 4,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: (widget.dark ? Colors.black : Colors.white).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('© OpenStreetMap contributors', style: ft(9, color: widget.dark ? C.muted : const Color(0xFF555555))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctl(IconData icon, VoidCallback onTap, {Color? color}) => Material(
    color: widget.dark ? const Color(0xE61C1C1C) : const Color(0xF2FFFFFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: widget.dark ? C.line2 : const Color(0xFFDDDDDD)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: color ?? (widget.dark ? C.text : const Color(0xFF222222)))),
    ),
  );

  static const _pinW = 26.0, _pinH = _pinW * 1.3;

  Widget _pin(Report r) {
    final c = pinColor(r);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) {
        final t = _pulse.value;
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            if (!r.safe)
              Positioned(
                top: _pinH - (4 + 5 * t),
                child: Container(
                  width: 8 + 34 * t,
                  height: 8 + 10 * t,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(21 + 17 * t, 5 + 5 * t)),
                    color: c.withValues(alpha: 0.45 * (1 - t)),
                  ),
                ),
              ),
            LocationPin(color: c, width: _pinW),
          ],
        );
      },
    );
  }

  Widget _you(GpsState gps) {
    final live = gps == GpsState.onCampus;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: C.blue.withValues(alpha: live ? 0.18 : 0.10),
        border: Border.all(color: C.blue.withValues(alpha: live ? 0.45 : 0.25)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: live ? C.blue : C.blue.withValues(alpha: 0.6),
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}
