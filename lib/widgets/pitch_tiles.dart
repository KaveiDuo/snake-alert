import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Loads OpenStreetMap tiles and adjusts their pixels:
///
/// * Inside the campus, sports pitches (strong teal with a darker outline) are
///   repainted in the soft light green (#DFFCE2) of the other sports grounds.
/// * Outside the campus, everything is washed out to light grey except roads,
///   paths, tracks, the railway and text, so the way in stays readable.
///
/// Working on the tile pixels (rather than drawing shapes on top) keeps every
/// map label readable.
class PitchRecolorTileProvider extends TileProvider {
  /// The campus outline(s): pixels inside any of these keep their colours.
  final List<List<LatLng>> campus;
  PitchRecolorTileProvider({required this.campus});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _RecoloredTile(getTileUrl(coordinates, options), kIsWeb ? const {} : Map.of(headers), coordinates, campus);
}

@immutable
class _RecoloredTile extends ImageProvider<_RecoloredTile> {
  final String url;
  final Map<String, String> headers;
  final TileCoordinates tile;
  final List<List<LatLng>> campus;
  const _RecoloredTile(this.url, this.headers, this.tile, this.campus);

  @override
  Future<_RecoloredTile> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_RecoloredTile key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load(), informationCollector: () => [DiagnosticsProperty('URL', url)]);

  /// Roads, paths, tracks, the railway and text: kept outside the campus.
  static bool _isWay(int r, int g, int b) {
    final hi = math.max(r, math.max(g, b)), lo = math.min(r, math.min(g, b));
    if (hi - lo <= 6) return true; // white roads, grey casings, railway, text
    if (r >= 0xE5 && b <= 0xC0 && r - b >= 0x2A) return true; // main roads, footways and paths
    if (r >= 0x80 && r <= 0xC8 && g < r && b + 0x20 < g) return true; // brown tracks
    return false;
  }

  Future<ImageInfo> _load() async {
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) throw Exception('Tile request failed (${res.statusCode}): $url');
    final codec = await ui.instantiateImageCodec(res.bodyBytes);
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    final px = data!.buffer.asUint8List();
    final n = math.pow(2, tile.z).toDouble();

    for (var row = 0; row < h; row++) {
      // Where this pixel row crosses the campus outline, as pixel columns.
      final ty = tile.y + (row + 0.5) / h;
      final lat = math.atan(_sinh(math.pi * (1 - 2 * ty / n))) * 180 / math.pi;
      final cuts = <double>[];
      for (final ring in campus) {
        for (var k = 0; k < ring.length; k++) {
          final a = ring[k], b = ring[(k + 1) % ring.length];
          if ((a.latitude > lat) != (b.latitude > lat)) {
            final lon = a.longitude + (lat - a.latitude) * (b.longitude - a.longitude) / (b.latitude - a.latitude);
            cuts.add(((lon + 180) / 360 * n - tile.x) * w);
          }
        }
      }
      cuts.sort();
      var next = 0;
      var inside = false;
      for (var col = 0; col < w; col++) {
        while (next < cuts.length && cuts[next] <= col + 0.5) {
          inside = !inside;
          next++;
        }
        final i = (row * w + col) * 4;
        final r = px[i], g = px[i + 1], b = px[i + 2];
        if (inside) {
          // Pitch teal (#88E0BE), its darker outline (#6DD1AA–#7FDBB8) and their
          // soft edges: green above blue above red, and fairly light. Water (blue
          // above green), parks and the other light greens (blue ≈ red) don't match.
          if (g > 0xC0 && g > b + 10 && b > r + 8) {
            px[i] = 0xDF;
            px[i + 1] = 0xFC;
            px[i + 2] = 0xE2;
          }
        } else if (!_isWay(r, g, b)) {
          // Washed out towards light grey.
          px[i] = (r * 0.15 + 0xEE * 0.85).round();
          px[i + 1] = (g * 0.15 + 0xEE * 0.85).round();
          px[i + 2] = (b * 0.15 + 0xEE * 0.85).round();
        }
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
    return ImageInfo(image: await done.future);
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

  @override
  bool operator ==(Object other) => other is _RecoloredTile && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
