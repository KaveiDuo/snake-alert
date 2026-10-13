import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Loads OpenStreetMap tiles and repaints sports pitches, which the tiles draw
/// in a strong teal with a darker outline, in the same soft light green
/// (#DFFCE2) the tiles use for the other sports grounds. Recolouring the tile
/// pixels (rather than drawing shapes on top) keeps every map label readable.
class PitchRecolorTileProvider extends TileProvider {
  PitchRecolorTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _RecoloredTile(getTileUrl(coordinates, options), kIsWeb ? const {} : Map.of(headers));
}

@immutable
class _RecoloredTile extends ImageProvider<_RecoloredTile> {
  final String url;
  final Map<String, String> headers;
  const _RecoloredTile(this.url, this.headers);

  @override
  Future<_RecoloredTile> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_RecoloredTile key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load(), informationCollector: () => [DiagnosticsProperty('URL', url)]);

  Future<ImageInfo> _load() async {
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) throw Exception('Tile request failed (${res.statusCode}): $url');
    final codec = await ui.instantiateImageCodec(res.bodyBytes);
    final tile = (await codec.getNextFrame()).image;
    final data = await tile.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = tile.width, h = tile.height;
    tile.dispose();
    final px = data!.buffer.asUint8List();
    for (var i = 0; i < px.length; i += 4) {
      final r = px[i], g = px[i + 1], b = px[i + 2];
      // Pitch teal (#88E0BE), its darker outline (#6DD1AA–#7FDBB8) and their
      // soft edges: green above blue above red, and fairly light. Water (blue
      // above green), parks and the other light greens (blue ≈ red) don't match.
      if (g > 0xC0 && g > b + 10 && b > r + 8) {
        px[i] = 0xDF;
        px[i + 1] = 0xFC;
        px[i + 2] = 0xE2;
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
    return ImageInfo(image: await done.future);
  }

  @override
  bool operator ==(Object other) => other is _RecoloredTile && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
