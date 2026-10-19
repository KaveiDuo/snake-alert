import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme.dart';

/// Starts the camera before the scanner opens, so it shows a live view at once.
/// The report form calls [prepare] when it reaches "Which snake?"; the scanner
/// [take]s the ready camera. Unused cameras are released after a minute or when
/// the form closes. Skipped in the browser, where starting the camera would ask
/// for permission before the student chose to scan.
class CameraWarmup {
  static Future<List<CameraDescription>>? _cams;
  static CameraController? _ready;
  static Future<void>? _preparing;
  static Timer? _expire;

  /// The phone's cameras, looked up once.
  static Future<List<CameraDescription>> cameras() =>
      _cams ??= availableCameras().catchError((Object e) {
        _cams = null; // try again next time
        throw e;
      });

  static CameraController _newController(List<CameraDescription> cams) {
    final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    return CameraController(back, ResolutionPreset.high, enableAudio: false);
  }

  static Future<void> prepare() {
    if (kIsWeb || _ready != null) return Future.value();
    return _preparing ??= () async {
      try {
        final cams = await cameras();
        if (cams.isEmpty) return;
        final c = _newController(cams);
        await c.initialize();
        _ready = c;
        _expire?.cancel();
        _expire = Timer(const Duration(minutes: 1), release);
      } catch (_) {
        // The scanner will try again (and show any problem) when it opens.
      } finally {
        _preparing = null;
      }
    }();
  }

  /// Hands over the warmed-up camera, if there is a working one.
  static CameraController? take() {
    final c = _ready;
    _ready = null;
    _expire?.cancel();
    if (c != null && c.value.isInitialized && !c.value.hasError) return c;
    c?.dispose();
    return null;
  }

  static void release() {
    _expire?.cancel();
    final c = _ready;
    _ready = null;
    c?.dispose();
  }
}

/// Full-screen live camera for scanning a snake: a framed viewfinder with the
/// outside dimmed, a round shutter button, Album (gallery) and Light (torch),
/// plus pinch / 1×–2× zoom so students can stay back. Falls back to a message
/// with Album when there is no camera or permission was refused.
class SnakeCamera extends StatefulWidget {
  final void Function(XFile photo) onCaptured;
  final VoidCallback onAlbum;
  final VoidCallback onClose;

  /// Small line under the controls (e.g. demo-mode note).
  final Widget? footer;
  const SnakeCamera({super.key, required this.onCaptured, required this.onAlbum, required this.onClose, this.footer});

  @override
  State<SnakeCamera> createState() => _SnakeCameraState();
}

class _SnakeCameraState extends State<SnakeCamera> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cam;
  String? _problem;
  bool _starting = true, _torch = false, _torchAvailable = true, _busy = false;
  double _zoom = 1, _minZoom = 1, _maxZoom = 1, _pinchStart = 1;
  late final AnimationController _line = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A warmed-up camera is shown on the very first frame.
    final warm = CameraWarmup.take();
    if (warm != null) {
      _cam = warm;
      _starting = false;
      _zoomRange(warm);
    } else {
      _open();
    }
  }

  Future<void> _zoomRange(CameraController c) async {
    try {
      _minZoom = await c.getMinZoomLevel();
      _maxZoom = (await c.getMaxZoomLevel()).clamp(1, 8).toDouble();
      _zoom = _minZoom;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _line.dispose();
    _cam?.dispose();
    super.dispose();
  }

  // Release the camera while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final c = _cam;
      _cam = null;
      _torch = false;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _cam == null && _problem == null) {
      _open();
    }
  }

  Future<void> _open() async {
    setState(() {
      _starting = true;
      _problem = null;
    });
    try {
      // Use the camera warmed up by the report form when there is one.
      var c = CameraWarmup.take();
      if (c == null) {
        final cams = await CameraWarmup.cameras();
        if (cams.isEmpty) throw CameraException('none', 'No camera found');
        c = CameraWarmup._newController(cams);
        await c.initialize();
      }
      try {
        _minZoom = await c.getMinZoomLevel();
        _maxZoom = (await c.getMaxZoomLevel()).clamp(1, 8).toDouble();
      } catch (_) {
        _minZoom = _maxZoom = 1;
      }
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _cam = c;
        _zoom = _minZoom;
        _starting = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _problem = (e.code.contains('Denied') || e.code.contains('denied'))
            ? 'Camera permission is off. Allow it in your phone’s settings, or pick a photo from your album.'
            : 'No camera available here. Pick a photo from your album instead.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _problem = 'The camera couldn’t start. Pick a photo from your album instead.';
      });
    }
  }

  Future<void> _shoot() async {
    final c = _cam;
    if (c == null || _busy || !c.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final x = await c.takePicture();
      if (_torch) {
        try {
          await c.setFlashMode(FlashMode.off);
        } catch (_) {}
      }
      widget.onCaptured(x);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t take the photo. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTorch() async {
    final c = _cam;
    if (c == null) return;
    try {
      await c.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      setState(() => _torch = !_torch);
    } catch (_) {
      setState(() => _torchAvailable = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Light isn’t available on this device')));
      }
    }
  }

  Future<void> _setZoom(double z) async {
    final c = _cam;
    if (c == null || _maxZoom <= _minZoom) return;
    final v = z.clamp(_minZoom, _maxZoom).toDouble();
    setState(() => _zoom = v);
    try {
      await c.setZoomLevel(v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, box) {
          final pad = MediaQuery.of(context).padding;
          final side = (box.maxWidth - 48).clamp(200.0, 420.0);
          final frame = Rect.fromCenter(
            center: Offset(box.maxWidth / 2, pad.top + 72 + side * 0.62),
            width: side,
            height: side * 1.05,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              // Live camera (or a dark background while it starts / if unavailable).
              if (ready)
                GestureDetector(
                  onScaleStart: (_) => _pinchStart = _zoom,
                  onScaleUpdate: (d) => _setZoom(_pinchStart * d.scale),
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: c.value.previewSize?.height ?? box.maxWidth,
                        height: c.value.previewSize?.width ?? box.maxHeight,
                        child: CameraPreview(c),
                      ),
                    ),
                  ),
                )
              else
                const ColoredBox(color: Color(0xFF0B0B0B)),
              // Dim everything outside the frame, then draw the frame corners.
              IgnorePointer(child: CustomPaint(painter: _FramePainter(frame, dim: ready))),
              if (ready)
                Positioned.fromRect(
                  rect: frame.deflate(14),
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _line,
                      builder: (_, _) => Align(
                        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_line.value)),
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [C.green.withValues(alpha: 0), C.green, C.green.withValues(alpha: 0)]),
                            boxShadow: [BoxShadow(color: C.green.withValues(alpha: 0.6), blurRadius: 10)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Starting / unavailable states inside the frame.
              if (!ready)
                Positioned.fromRect(
                  rect: frame.deflate(24),
                  child: Center(
                    child: _starting
                        ? const CircularProgressIndicator(color: C.green, strokeWidth: 2.5)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.no_photography_outlined, color: C.muted, size: 40),
                              const SizedBox(height: 12),
                              Text(_problem ?? '', textAlign: TextAlign.center, style: ft(13.5, color: C.sub, height: 1.45)),
                              const SizedBox(height: 14),
                              OutlinedButton(
                                onPressed: _open,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: C.greenText,
                                  side: const BorderSide(color: Color(0xFF245A36)),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text('Try again', style: ft(13.5, w: 600, color: C.greenText)),
                              ),
                            ],
                          ),
                  ),
                ),
              // Top bar.
              Positioned(
                top: pad.top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _RoundIcon(Icons.close_rounded, widget.onClose),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Scan a snake', style: ft(18, w: 700, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('Fit the snake inside the frame', style: ft(12.5, color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              // Zoom chip just under the frame.
              if (ready && _maxZoom >= 2)
                Positioned(
                  top: frame.bottom + 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final z in [1.0, 2.0])
                            GestureDetector(
                              onTap: () => _setZoom(z),
                              child: Container(
                                width: 40,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: (_zoom - z).abs() < 0.25 ? const Color(0x33FFFFFF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${z.toInt()}×',
                                  style: ft(12.5, w: 700, color: (_zoom - z).abs() < 0.25 ? C.green : Colors.white70),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Bottom controls: Album · shutter · Light.
              Positioned(
                left: 0,
                right: 0,
                bottom: pad.bottom + 22,
                child: Column(
                  children: [
                    Text('Stay 3 m back — pinch or tap 2× to zoom', style: ft(12.5, color: Colors.white70)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _SideButton(Icons.photo_library_outlined, 'Album', widget.onAlbum)),
                        _Shutter(enabled: ready && !_busy, onTap: _shoot),
                        Expanded(
                          child: _SideButton(
                            _torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_outlined,
                            'Light',
                            ready && _torchAvailable ? _toggleTorch : null,
                            active: _torch,
                          ),
                        ),
                      ],
                    ),
                    if (widget.footer != null) ...[const SizedBox(height: 14), widget.footer!],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dims outside the frame and draws rounded green corner brackets.
class _FramePainter extends CustomPainter {
  final Rect frame;
  final bool dim;
  _FramePainter(this.frame, {required this.dim});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(22));
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(r);
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: dim ? 0.55 : 0.0));
    canvas.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.18));

    final p = Paint()
      ..color = C.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 30.0, rad = 22.0;
    for (final (x, y, dx, dy) in [
      (frame.left, frame.top, 1.0, 1.0),
      (frame.right, frame.top, -1.0, 1.0),
      (frame.left, frame.bottom, 1.0, -1.0),
      (frame.right, frame.bottom, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * (l + rad))
          ..lineTo(x, y + dy * rad)
          ..arcToPoint(Offset(x + dx * rad, y), radius: const Radius.circular(rad), clockwise: dx * dy > 0)
          ..lineTo(x + dx * (l + rad), y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.frame != frame || old.dim != dim;
}

class _Shutter extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _Shutter({required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Take photo',
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF111111), size: 28),
          ),
        ),
      ),
    ),
  );
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const _SideButton(this.icon, this.label, this.onTap, {this.active = false});
  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Colors.white30 : (active ? C.green : Colors.white);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? C.green.withValues(alpha: 0.18) : const Color(0x33FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: ft(13, w: 600, color: color)),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x66000000),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white)),
    ),
  );
}
