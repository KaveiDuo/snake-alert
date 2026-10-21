import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'species.dart';

/// One possible identification. [speciesId] is set when it's one of the
/// campus species; otherwise only [name] (and maybe [latin]) is known.
class ScanMatch {
  final String? speciesId;
  final String name;
  final String? latin;
  final bool? venomous;
  final int confidence;
  const ScanMatch({this.speciesId, required this.name, this.latin, this.venomous, required this.confidence});

  Species? get sp => speciesId == null ? null : speciesById(speciesId!);
}

class ScanResult {
  final bool isSnake;
  final List<ScanMatch> matches;
  final String? note;
  const ScanResult({required this.isSnake, required this.matches, this.note});
}

class ScanException implements Exception {
  final String message;
  const ScanException(this.message);
  @override
  String toString() => message;
}

/// Identifies snakes in photos with AI.
///
/// By default it uses Google Gemini's free tier with the app's built-in key,
/// which is added at build time from the untracked file `scanner_key.txt`
/// (see build_web.sh / build_apk.ps1) and never committed. It is stored
/// reversed so the raw key never appears in the published files. Anyone can
/// override it in Profile → Snake scanner key with their own Gemini (AIza…)
/// or Anthropic (sk-ant-…) key, saved only on that device.
class Scanner {
  static const _prefsKey = 'scanner_api_key';
  static const claudeModel = 'claude-sonnet-5';

  /// Free-tier Gemini models, tried in order when one is busy, out of quota or
  /// too slow, each with the least "thinking" it allows (thinking adds delay).
  /// Flash-Lite answers in about 2 s and named all the sample snakes correctly
  /// in testing; the bigger models are slower and often overloaded.
  static const geminiModels = {'gemini-3.5-flash-lite': 'minimal', 'gemini-3.6-flash': 'minimal', 'gemini-3.8-flash': 'low'};

  /// How long to wait for one model before trying the next. Flash-Lite gets
  /// longer: when Google's free tier is overloaded it still answers, just
  /// slowly (25–30 s seen), while the bigger models are usually refused.
  static const perModelTimeout = Duration(seconds: 12);
  static const firstModelTimeout = Duration(seconds: 35);

  static const _builtInReversed = String.fromEnvironment('SCANNER_KEY_R');
  static String? get builtInKey => _builtInReversed.isEmpty ? null : _builtInReversed.split('').reversed.join();

  /// Backup scanner: Groq's free vision model, asked when Gemini is slow or
  /// fails. Its key comes from the untracked groq_key.txt at build time (also
  /// reversed); without it the app simply uses Gemini alone.
  static const _groqReversed = String.fromEnvironment('GROQ_KEY_R');
  static String? get groqKey => _groqReversed.isEmpty ? null : _groqReversed.split('').reversed.join();
  static const groqModel = 'meta-llama/llama-4-scout-17b-16e-instruct';

  /// Gemini gets this long on its own before Groq is asked as well.
  static const groqAfter = Duration(seconds: 4);

  /// The key a scan will use: the user's own key, else the built-in free one.
  static Future<String?> activeKey() async => await loadKey() ?? builtInKey;

  static Future<String?> loadKey() async {
    try {
      final k = (await SharedPreferences.getInstance()).getString(_prefsKey);
      return (k == null || k.trim().isEmpty) ? null : k.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.trim().isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, key.trim());
    }
  }

  static String _mediaType(Uint8List b) {
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'image/gif';
    if (b.length > 11 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static String get _prompt {
    final list = species.map((s) => '${s.id} | ${s.name} | ${s.latin} | ${s.venomous ? 'venomous' : 'non-venomous'}').join('\n');
    // Species first: the AI names whatever snake it sees; the campus list only
    // links the answer to a campus species when it is that exact species.
    return '''
Identify the snake in this photo as precisely as you can: its exact species, whatever it is. Judge only from what you see; do not force a match.

Context: the photo was taken on the IIT Guwahati campus in Assam, India. These species have been recorded there (id | name | scientific name | venom). If — and only if — the snake is one of these exact species, give its id; otherwise use null:
$list

Reply with ONLY this JSON:
{"is_snake": true|false, "matches": [{"id": "<campus id or null>", "name": "<common name>", "latin": "<scientific name>", "venomous": true|false|null, "confidence": <0-100>}], "note": "<one short sentence on the features you used>"}

Rules: up to 3 matches, most likely first; confidences add up to at most 100. "venomous" means dangerous to people (true for cobras, kraits, vipers, pit vipers and other medically significant species). If unsure about venom, use null. If the photo is unclear, keep confidences low and say so in the note. No snake: "is_snake": false and "matches": [].''';
  }

  static Future<ScanResult> identify(Uint8List image, String apiKey) {
    if (apiKey.startsWith('sk-ant-')) return _claude(image, apiKey);
    final groq = groqKey;
    return groq == null ? _gemini(image, apiKey) : _race(image, apiKey, groq);
  }

  /// Gemini first. If it hasn't answered after [groqAfter], or fails, Groq is
  /// asked too and the first good answer wins. Fails only if both fail.
  static Future<ScanResult> _race(Uint8List image, String geminiKey, String groqKey) {
    final done = Completer<ScanResult>();
    Object? firstError;
    var pending = 1;
    var groqStarted = false;
    void ok(ScanResult r) {
      if (!done.isCompleted) done.complete(r);
    }

    void fail(Object e) {
      firstError ??= e;
      if (--pending == 0 && !done.isCompleted) done.completeError(firstError!);
    }

    void startGroq() {
      if (groqStarted || done.isCompleted) return;
      groqStarted = true;
      pending++;
      _groq(image, groqKey).then(ok, onError: fail);
    }

    _gemini(image, geminiKey).then(ok, onError: (Object e) {
      startGroq();
      fail(e);
    });
    Future<void>.delayed(groqAfter, startGroq);
    return done.future;
  }

  static Future<ScanResult> _groq(Uint8List image, String key) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {'content-type': 'application/json', 'authorization': 'Bearer $key'},
            body: jsonEncode({
              'model': groqModel,
              'temperature': 0.2,
              'response_format': {'type': 'json_object'},
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': _prompt},
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'data:${_mediaType(image)};base64,${base64Encode(image)}'},
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const ScanException('Couldn’t reach the scanner. Check your internet connection and try again.');
    }
    if (res.statusCode != 200) throw ScanException('Scanner error (${res.statusCode}). Try again.');
    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return parse(json['choices'][0]['message']['content'] as String);
    } catch (_) {
      throw const ScanException('The scanner gave an answer the app couldn’t read. Try again.');
    }
  }

  static const _geminiBase = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// One shared connection, so the warm-up below and the scan reuse it.
  static final _client = http.Client();

  /// If the first Flash-Lite answer hasn't arrived by then, a second identical
  /// request is sent and whichever answers first wins. Flash-Lite usually takes
  /// about 2 s but now and then one request takes 5–10 s.
  static const hedgeAfter = Duration(milliseconds: 2500);

  /// Opens the connection to Google (and, in the browser, its CORS check)
  /// while the student is still picking a photo, so the scan starts faster.
  static Future<void> warmUp() async {
    final key = await activeKey();
    if (key == null || key.startsWith('sk-ant-')) return;
    try {
      await _client
          .get(Uri.parse('$_geminiBase/${geminiModels.keys.first}'), headers: {'x-goog-api-key': key})
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// One Gemini request. Null when it timed out or the network failed.
  static Future<http.Response?> _post(String model, String body, String apiKey) async {
    try {
      return await _client
          .post(
            Uri.parse('$_geminiBase/$model:generateContent'),
            headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
            body: body,
          )
          .timeout(model == geminiModels.keys.first ? firstModelTimeout : perModelTimeout);
    } catch (_) {
      return null;
    }
  }

  /// Flash-Lite with a backup request after [hedgeAfter]: the first OK answer
  /// wins. Returns the last answer (or null) if neither succeeded.
  static Future<http.Response?> _hedged(String model, String body, String apiKey) {
    final done = Completer<http.Response?>();
    var pending = 2;
    http.Response? last;
    void finish(http.Response? r) {
      if (done.isCompleted) return;
      if (r != null) last = r;
      if (r != null && r.statusCode == 200) {
        done.complete(r);
      } else if (--pending == 0) {
        done.complete(last);
      }
    }

    _post(model, body, apiKey).then(finish);
    Future<void>.delayed(hedgeAfter, () {
      if (done.isCompleted) return;
      _post(model, body, apiKey).then(finish);
    });
    return done.future;
  }

  static Future<ScanResult> _gemini(Uint8List image, String apiKey) async {
    final imagePart = {
      'inline_data': {'mime_type': _mediaType(image), 'data': base64Encode(image)},
    };
    String bodyFor(String thinking) => jsonEncode({
      'contents': [
        {
          'parts': [imagePart, {'text': _prompt}],
        },
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
        'thinkingConfig': {'thinkingLevel': thinking},
      },
    });

    // Fast model first (with a backup request), then the bigger ones in turn.
    http.Response? res;
    var i = 0;
    for (final MapEntry(key: model, value: thinking) in geminiModels.entries) {
      res = i++ == 0 ? await _hedged(model, bodyFor(thinking), apiKey) : await _post(model, bodyFor(thinking), apiKey);
      if (res == null) continue; // too slow or no connection: try the next model
      // Busy, out of today's free quota or model not available: try the next one.
      if (res.statusCode == 429 || res.statusCode == 404 || res.statusCode == 503) continue;
      break;
    }
    if (res == null) throw const ScanException('Couldn’t reach the scanner. Check your internet connection and try again.');
    final r = res;
    if (r.statusCode == 429) throw const ScanException('The free scanner has reached its limit for now. Try again later.');
    if (r.statusCode == 400 && r.body.contains('API_KEY_INVALID') || r.statusCode == 401 || r.statusCode == 403) {
      throw const ScanException('The scanner key isn’t valid. Check it in Profile → Snake scanner key.');
    }
    if (r.statusCode >= 400) throw ScanException('Scanner error (${r.statusCode}). Try again.');
    try {
      final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final parts = json['candidates'][0]['content']['parts'] as List;
      return parse(parts.where((p) => p['thought'] != true).map((p) => p['text'] ?? '').join());
    } catch (_) {
      throw const ScanException('The scanner gave an answer the app couldn’t read. Try again.');
    }
  }

  static Future<ScanResult> _claude(Uint8List image, String apiKey) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              // Lets the browser (web version) call the API directly.
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode({
              'model': claudeModel,
              'max_tokens': 700,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image',
                      'source': {'type': 'base64', 'media_type': _mediaType(image), 'data': base64Encode(image)},
                    },
                    {'type': 'text', 'text': _prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const ScanException('Couldn’t reach the scanner. Check your internet connection.');
    }

    if (res.statusCode == 401) throw const ScanException('The scanner key isn’t valid. Check it in Profile → Snake scanner key.');
    if (res.statusCode == 429) throw const ScanException('Too many scans right now. Wait a minute and try again.');
    if (res.statusCode >= 400) {
      String msg = 'Scanner error (${res.statusCode}).';
      try {
        msg = (jsonDecode(res.body)['error']['message'] as String?) ?? msg;
      } catch (_) {}
      throw ScanException(msg);
    }

    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return parse((body['content'] as List).where((c) => c['type'] == 'text').map((c) => c['text'] as String).join());
    } catch (_) {
      throw const ScanException('The scanner gave an answer the app couldn’t read. Try again.');
    }
  }

  /// Reads the JSON answer described in [_prompt].
  static ScanResult parse(String text) {
    final json = jsonDecode(text.substring(text.indexOf('{'), text.lastIndexOf('}') + 1)) as Map<String, dynamic>;
    final ids = species.map((s) => s.id).toSet();
    final matches = <ScanMatch>[
      for (final m in (json['matches'] as List? ?? const []).cast<Map<String, dynamic>>())
        ScanMatch(
          speciesId: ids.contains(m['id']) ? m['id'] as String : null,
          name: ids.contains(m['id']) ? speciesById(m['id'] as String).name : (m['name'] as String? ?? 'Unknown snake'),
          latin: ids.contains(m['id']) ? speciesById(m['id'] as String).latin : m['latin'] as String?,
          venomous: ids.contains(m['id']) ? speciesById(m['id'] as String).venomous : m['venomous'] as bool?,
          confidence: ((m['confidence'] as num?) ?? 0).round().clamp(0, 100),
        ),
    ];
    return ScanResult(isSnake: json['is_snake'] != false && matches.isNotEmpty, matches: matches.take(3).toList(), note: json['note'] as String?);
  }
}
