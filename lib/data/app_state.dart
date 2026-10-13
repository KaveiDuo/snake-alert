import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'campus_boundary.dart';
import 'open_areas.dart';
import 'places.dart';
import 'species.dart';
import 'zones.dart';

/// IIT Guwahati campus (real coordinates, from OpenStreetMap).
const campusCenter = LatLng(26.1895, 91.6965);
final campusBounds = LatLngBounds(const LatLng(26.1780, 91.6820), const LatLng(26.2010, 91.7070));

/// Where "You" is shown when GPS is off, denied, or you're not on campus.
const demoYou = LatLng(26.19018, 91.70098); // beside Kameng Hostel

/// A spot counts as inside a building's premises if it is in the outline or
/// within this many metres of it (courtyards, entrances, parking).
const premisesMarginMetres = 20.0;

const _dist = Distance();

bool _inPolygon(LatLng p, List<LatLng> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
        p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
      inside = !inside;
    }
  }
  return inside;
}

double _distToPolygon(LatLng p, List<LatLng> poly) => poly.map((v) => _dist.as(LengthUnit.Meter, p, v)).reduce(min);

/// Hostel or campus building whose premises contain [p], or null for an
/// open area (road, field, lake, forest…). Inside an outline wins; otherwise
/// the nearest building within [premisesMarginMetres].
Zone? zoneAt(LatLng p) {
  for (final z in campusZones) {
    if (z.outlines.any((o) => _inPolygon(p, o))) return z;
  }
  Zone? best;
  var bestD = premisesMarginMetres;
  for (final z in campusZones) {
    for (final o in z.outlines) {
      final d = _distToPolygon(p, o);
      if (d <= bestD) {
        bestD = d;
        best = z;
      }
    }
  }
  return best;
}

/// Metres from [p] to the segment a–b (flat-earth approximation, fine at campus scale).
double _distToSegment(LatLng p, LatLng a, LatLng b) {
  const mPerDegLat = 111320.0;
  final mPerDegLon = 111320.0 * cos(p.latitude * pi / 180);
  final ax = (a.longitude - p.longitude) * mPerDegLon, ay = (a.latitude - p.latitude) * mPerDegLat;
  final bx = (b.longitude - p.longitude) * mPerDegLon, by = (b.latitude - p.latitude) * mPerDegLat;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
  final x = ax + t * dx, y = ay + t * dy;
  return sqrt(x * x + y * y);
}

double _distToLine(LatLng p, List<LatLng> line) {
  var best = double.infinity;
  for (var i = 0; i + 1 < line.length; i++) {
    best = min(best, _distToSegment(p, line[i], line[i + 1]));
  }
  return best;
}

/// Name for a spot outside any building: the field, court, park or lake it is
/// in, the road it is on, or just "Open area".
String openAreaName(LatLng p) {
  for (final (name, outline) in openFields) {
    if (_inPolygon(p, outline)) return name;
  }
  for (final (name, outline) in openWater) {
    if (_inPolygon(p, outline)) return name;
  }
  if (mainRoadLines.any((l) => _distToLine(p, l) <= 14)) return 'North Guwahati Road';
  if (campusRoadLines.any((l) => _distToLine(p, l) <= 10)) {
    String? best;
    var bestD = 170.0;
    for (final (name, at) in roadNameLabels) {
      final d = _dist.as(LengthUnit.Meter, p, at);
      if (d < bestD) {
        bestD = d;
        best = name;
      }
    }
    return best ?? 'Campus road';
  }
  for (final (name, outline) in openWater) {
    if (_distToLine(p, outline) <= 15) return '$name bank';
  }
  return 'Open area';
}

/// Inside the IIT Guwahati campus boundary (or on a building we know about).
bool onCampus(LatLng p) => _inPolygon(p, campusBoundary) || zoneAt(p) != null;

LatLng zoneCentre(String name) {
  final pts = campusZones.firstWhere((z) => z.name == name).outlines.first;
  return LatLng(
    pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length,
    pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length,
  );
}

enum Venom { venomous, nonVenomous, unsure }

/// Phone number the "Call the authority" button dials after a report. Demo
/// only: every hostel and building authority uses the same number for now.
const authorityPhone = '8277992838';

/// Snake catcher / wildlife department the authority calls for big or
/// venomous snakes. Demo placeholder until the real number is known.
const rescuerPhone = '8277992838';

enum Role { none, student, authority }

/// The authority console's Open / Resolved switch.
enum ConsoleTab { open, resolved }

/// Report-type filter chips in the authority console.
enum ConsoleFilter {
  all('All'),
  overdue('Overdue'),
  venomous('Venomous'),
  nonVenomous('Non-venomous'),
  unsure('Not sure');

  final String label;
  const ConsoleFilter(this.label);

  bool matches(Report r) => switch (this) {
    ConsoleFilter.all => true,
    ConsoleFilter.overdue => r.flagged,
    ConsoleFilter.venomous => r.venom == Venom.venomous,
    ConsoleFilter.nonVenomous => r.venom == Venom.nonVenomous,
    ConsoleFilter.unsure => r.venom == Venom.unsure,
  };
}

/// How far the responsible authority has got with a report. Every step is
/// timestamped and shown to students, so a report can't just be clicked away:
/// "Seen" is recorded when the authority opens their console, "At the spot"
/// checks their phone's location, and resolving needs an outcome and a photo.
enum Stage { reported, seen, onTheWay, onSite, resolved }

/// What the authority found, picked with one tap (no writing needed).
enum Outcome {
  caught('Caught & moved', 'Snake caught and released away from people'),
  rescuer('Rescuer took it', 'A snake rescuer caught it and took it away'),
  leftArea('It went away', 'Snake left on its own · area checked'),
  notFound('Not found', 'Area searched · snake not found');

  /// Short tile label and the sentence students see.
  final String short, label;
  const Outcome(this.short, this.label);
}

/// Places the authority can tap to say where they searched.
const searchSpots = ['Drains', 'Bushes & grass', 'Under vehicles', 'Stairs & steps', 'Inside the building', 'Walls & holes', 'Garbage area'];

/// After "Not found", the pin stays on the map as a caution for this long.
const cautionFor = Duration(hours: 24);

/// Time the authority has to reach the spot before the report counts as
/// overdue and is escalated to campus security.
const respondWithin = Duration(minutes: 15);

/// "At the spot" is location-verified when the authority's phone is this close
/// to the reported pin.
const onSiteRadiusMetres = 200.0;

class Loc {
  final String name;
  final String source;
  final bool covered;
  final LatLng pos;

  /// True when the spot is outside the IIT Guwahati campus (can't be reported).
  final bool outside;
  const Loc(this.name, this.source, {required this.covered, this.pos = demoYou, this.outside = false});
  String get authority => '$name authority';
}

class Report {
  final String id;
  final String? speciesId;
  final Venom venom;
  final String place;
  final String spot;
  final String note;
  final String reporter;
  final DateTime time;
  final LatLng pos;
  final bool covered;
  final String? photoPath;

  // Response by the responsible authority (see [Stage]).
  Stage stage;
  DateTime? seenAt, onTheWayAt, onSiteAt, resolvedAt;

  /// Who is handling it; null means "The [place] authority".
  String? handler;

  /// How far the authority's phone was from the pin when they marked arrival.
  double? onSiteMetres;
  Outcome? outcome;
  String? proofPhoto;
  String resolveNote;

  /// Where the authority searched (tapped from [searchSpots]).
  List<String> searched;

  /// When the authority called the snake catcher / wildlife department.
  DateTime? rescuerCalledAt;

  /// The reporter's answer to "Is the area clear now?" (null: not answered).
  bool? reporterConfirmed;

  /// Escalated to campus security because the reporter said the snake is still there.
  bool escalated;

  Report({
    required this.id,
    required this.venom,
    required this.place,
    required this.pos,
    required this.covered,
    this.speciesId,
    this.spot = '',
    this.note = '',
    this.reporter = 'Ananya S.',
    DateTime? time,
    this.photoPath,
    this.stage = Stage.reported,
    this.seenAt,
    this.onTheWayAt,
    this.onSiteAt,
    this.resolvedAt,
    this.handler,
    this.onSiteMetres,
    this.outcome,
    this.proofPhoto,
    this.resolveNote = '',
    this.searched = const [],
    this.rescuerCalledAt,
    this.reporterConfirmed,
    this.escalated = false,
  }) : time = time ?? DateTime.now();

  bool get safe => stage == Stage.resolved;

  /// Closed as "not found" recently: the snake may still be nearby, so the pin
  /// stays as a caution and students are told to stay alert.
  bool get caution => safe && outcome == Outcome.notFound && DateTime.now().difference(resolvedAt!) < cautionFor;

  /// Time spent at the spot before closing, recorded automatically.
  Duration? get timeAtSpot => onSiteAt != null && resolvedAt != null ? resolvedAt!.difference(onSiteAt!) : null;
  String get handlerName => handler ?? 'The $place authority';
  bool get locationVerified => onSiteMetres != null && onSiteMetres! <= onSiteRadiusMetres;

  /// Not reached the spot within [respondWithin].
  bool get overdue => covered && stage.index < Stage.onSite.index && DateTime.now().difference(time) > respondWithin;
  bool get flagged => overdue || (escalated && !safe);

  /// Time left to reach the spot (negative once overdue).
  Duration get dueIn => respondWithin - DateTime.now().difference(time);

  /// One line for students on how the response is going.
  String get statusLine => switch (stage) {
    Stage.reported => 'Waiting for the authority to open it',
    Stage.seen => 'Seen by $handlerName · not on the way yet',
    Stage.onTheWay => '$handlerName is on the way',
    Stage.onSite => '$handlerName is at the spot',
    Stage.resolved => outcome == Outcome.notFound ? 'Searched · not found, stay alert' : 'Checked and marked safe',
  };

  Species? get sp => speciesId == null ? null : speciesById(speciesId!);
  String get title => sp?.name ?? (venom == Venom.nonVenomous ? 'Non-venomous snake' : 'Unidentified snake');
  String get where => spot.isEmpty ? place : '$place · $spot';
  bool get treatAsVenomous => venom != Venom.nonVenomous;
}

/// "9:41 AM" style clock time.
String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

String mins(Duration d) => d.inMinutes < 1 ? 'under a minute' : '${d.inMinutes} min';

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return 'Yesterday';
}

class Draft {
  Loc? loc;
  Venom? venom;
  String? speciesId;
  String? photoPath;
  String? matchedId;

  /// Name the scanner gave, when it isn't one of the campus species.
  String? matchedName;
  bool exactSpotSet = false;
  String note = '';
}

enum GpsState { off, searching, onCampus, offCampus, denied }

class AppState extends ChangeNotifier {
  Role role = Role.none;
  bool mapDark = false; // light map first; the moon button switches to dark
  /// What the authority console lists: Open or Resolved, and which type.
  ConsoleTab consoleTab = ConsoleTab.open;
  ConsoleFilter consoleFilter = ConsoleFilter.all;
  final String authorityHostel = 'Kameng Hostel';
  static const kamengAuthority = 'Dr. P. Saikia';
  final String studentName = 'Ananya Sharma';
  final String studentEmail = '210102043@iitg.ac.in';

  // ---------- GPS ----------
  GpsState gps = GpsState.off;
  LatLng you = demoYou;
  StreamSubscription<Position>? _gpsSub;

  /// Asks for location permission once and follows the phone's GPS.
  /// Off campus (or no permission) the demo location beside Kameng is used.
  Future<void> startGps() async {
    if (gps != GpsState.off) return;
    gps = GpsState.searching;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        gps = GpsState.denied;
        notifyListeners();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        gps = GpsState.denied;
        notifyListeners();
        return;
      }
      _gpsSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5))
          .listen(
            _onPosition,
            onError: (_) {
              gps = GpsState.denied;
              notifyListeners();
            },
          );
      _onPosition(await Geolocator.getCurrentPosition());
    } catch (_) {
      gps = GpsState.denied;
      notifyListeners();
    }
  }

  void _onPosition(Position p) {
    final here = LatLng(p.latitude, p.longitude);
    if (campusBounds.contains(here)) {
      you = here;
      gps = GpsState.onCampus;
    } else {
      you = demoYou;
      gps = GpsState.offCampus;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }

  /// Location used for "Use my current location".
  Loc get currentLoc {
    final z = zoneAt(you);
    final source = gps == GpsState.onCampus ? 'Detected from your location' : 'Demo location (you’re off campus)';
    return z != null ? Loc(z.name, source, covered: true, pos: you) : Loc(openAreaName(you), source, covered: false, pos: you);
  }

  final List<Report> reports = [
    Report(
      id: 'r1',
      speciesId: 'banded_krait',
      venom: Venom.venomous,
      place: 'Kameng Hostel',
      spot: 'back gate',
      note: 'Went under the parked cycles near the back gate, hasn’t come out. Security has been told.',
      reporter: 'Ananya S.',
      time: DateTime.now().subtract(const Duration(minutes: 9)),
      pos: const LatLng(26.19068, 91.70186),
      covered: true,
      stage: Stage.onTheWay,
      handler: AppState.kamengAuthority,
      seenAt: DateTime.now().subtract(const Duration(minutes: 8)),
      onTheWayAt: DateTime.now().subtract(const Duration(minutes: 6)),
    ),
    Report(
      id: 'r2',
      speciesId: 'keelback',
      venom: Venom.nonVenomous,
      place: 'Kameng Hostel',
      spot: 'near the mess hall',
      note: 'Saw it near the mess hall drain this morning, it moved off toward the hedge.',
      reporter: 'Rohit K.',
      time: DateTime.now().subtract(const Duration(minutes: 32)),
      pos: const LatLng(26.19016, 91.70140),
      covered: true,
      // Seen but nobody went: overdue, so it's flagged to campus security.
      stage: Stage.seen,
      handler: AppState.kamengAuthority,
      seenAt: DateTime.now().subtract(const Duration(minutes: 29)),
    ),
    Report(
      id: 'r3',
      venom: Venom.unsure,
      place: 'Lake-side Path',
      note: 'Dark snake crossed the path and went into the grass by the lake.',
      reporter: 'Priya D.',
      time: DateTime.now().subtract(const Duration(minutes: 41)),
      pos: const LatLng(26.19005, 91.69420),
      covered: false,
    ),
    Report(
      id: 'r4',
      speciesId: 'wolf',
      venom: Venom.nonVenomous,
      place: 'Kameng Hostel',
      spot: 'near the parking area',
      note: 'Small banded snake near the bike parking, guard moved it to the green belt.',
      reporter: 'Meghna B.',
      time: DateTime.now().subtract(const Duration(hours: 1)),
      pos: const LatLng(26.19080, 91.70128),
      covered: true,
      stage: Stage.resolved,
      handler: AppState.kamengAuthority,
      seenAt: DateTime.now().subtract(const Duration(minutes: 58)),
      onTheWayAt: DateTime.now().subtract(const Duration(minutes: 56)),
      onSiteAt: DateTime.now().subtract(const Duration(minutes: 49)),
      onSiteMetres: 40,
      resolvedAt: DateTime.now().subtract(const Duration(minutes: 41)),
      outcome: Outcome.caught,
      searched: const ['Under vehicles'],
      proofPhoto: 'assets/snakes/wolf.jpg',
      resolveNote: 'Guard caught it with the snake hook and released it in the green belt behind the hostel.',
      reporterConfirmed: true,
    ),
    Report(
      id: 'r5',
      speciesId: 'rat',
      venom: Venom.nonVenomous,
      place: 'Core 3',
      spot: 'rear stairs',
      note: 'Long snake on the rear stairs, went under the steps.',
      reporter: 'Arjun M.',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      pos: const LatLng(26.18590, 91.69060),
      covered: true,
      stage: Stage.resolved,
      seenAt: DateTime.now().subtract(const Duration(minutes: 117)),
      onTheWayAt: DateTime.now().subtract(const Duration(minutes: 115)),
      onSiteAt: DateTime.now().subtract(const Duration(minutes: 108)),
      onSiteMetres: 25,
      resolvedAt: DateTime.now().subtract(const Duration(minutes: 100)),
      outcome: Outcome.leftArea,
      searched: const ['Stairs & steps', 'Drains'],
    ),
  ];

  Draft draft = Draft();

  // ---------- campus ----------
  List<Report> get openReports => reports.where((r) => !r.safe).toList();

  /// Pins on the map: open reports plus recent "not found" cautions.
  List<Report> get mapReports => reports.where((r) => !r.safe || r.caution).toList();
  int get activeCount => openReports.length;
  Report? get latestOpen {
    final o = openReports..sort((a, b) => b.time.compareTo(a.time));
    return o.isEmpty ? null : o.first;
  }

  double metresFromYou(LatLng p) => _dist.as(LengthUnit.Meter, you, p);

  // ---------- hostel authority ----------
  List<Report> get hostelReports =>
      reports.where((r) => r.covered && r.place == authorityHostel).toList()..sort((a, b) => b.time.compareTo(a.time));
  int get hostelOpen => hostelReports.where((r) => !r.safe).length;
  int get hostelFlagged => hostelReports.where((r) => r.flagged).length;

  /// Average time from report to reaching the spot, for this hostel.
  Duration? get avgArrival {
    final arrived = hostelReports.where((r) => r.onSiteAt != null).toList();
    if (arrived.isEmpty) return null;
    final total = arrived.fold<int>(0, (a, r) => a + r.onSiteAt!.difference(r.time).inSeconds);
    return Duration(seconds: total ~/ arrived.length);
  }
  int safeThisWeek = 5;

  void setRole(Role r) {
    role = r;
    notifyListeners();
  }

  void toggleMap() {
    mapDark = !mapDark;
    notifyListeners();
  }

  void setConsoleTab(ConsoleTab t) {
    consoleTab = t;
    // "Overdue" only applies to open reports.
    if (t == ConsoleTab.resolved && consoleFilter == ConsoleFilter.overdue) consoleFilter = ConsoleFilter.all;
    notifyListeners();
  }

  /// Tapping a type filters by it; tapping it again shows everything.
  void setConsoleFilter(ConsoleFilter f) {
    consoleFilter = consoleFilter == f ? ConsoleFilter.all : f;
    notifyListeners();
  }

  // ---------- response steps ----------

  /// Recorded when the authority opens their console, so the reporter knows
  /// the report has been read.
  void markSeen(Iterable<Report> rs) {
    var changed = false;
    for (final r in rs) {
      if (r.stage == Stage.reported) {
        r.stage = Stage.seen;
        r.seenAt = DateTime.now();
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void setOnTheWay(Report r) {
    final now = DateTime.now();
    r.seenAt ??= now;
    r.onTheWayAt = now;
    r.stage = Stage.onTheWay;
    notifyListeners();
  }

  /// Marks arrival and records how far the authority's phone is from the pin.
  void arrive(Report r) {
    final now = DateTime.now();
    r.seenAt ??= now;
    r.onTheWayAt ??= now;
    r.onSiteAt = now;
    r.onSiteMetres = metresFromYou(r.pos);
    r.stage = Stage.onSite;
    notifyListeners();
  }

  /// Only possible at the spot. "Not found" needs at least one searched place.
  /// The photo and written note are optional.
  void resolve(Report r, {required Outcome outcome, List<String> searched = const [], String? proofPhoto, String note = ''}) {
    assert(r.stage == Stage.onSite, 'Reach the spot before resolving');
    assert(outcome != Outcome.notFound || searched.isNotEmpty, 'Say where you searched');
    r.outcome = outcome;
    r.searched = List.unmodifiable(searched);
    r.proofPhoto = proofPhoto;
    r.resolveNote = note.trim();
    r.resolvedAt = DateTime.now();
    r.reporterConfirmed = null;
    r.escalated = false;
    r.stage = Stage.resolved;
    safeThisWeek++;
    notifyListeners();
  }

  /// Back to "Seen". When the reporter says the snake is still there, the
  /// report is also escalated to campus security.
  void reopen(Report r, {bool byReporter = false}) {
    if (r.safe) safeThisWeek--;
    r.stage = Stage.seen;
    r.onTheWayAt = r.onSiteAt = r.resolvedAt = null;
    r.onSiteMetres = null;
    r.outcome = null;
    r.proofPhoto = null;
    r.resolveNote = '';
    r.searched = const [];
    r.rescuerCalledAt = null;
    r.reporterConfirmed = byReporter ? false : null;
    r.escalated = r.escalated || byReporter;
    notifyListeners();
  }

  /// Recorded when the authority taps "Call rescuer", so students can see help was called.
  void callRescuer(Report r) {
    r.rescuerCalledAt = DateTime.now();
    notifyListeners();
  }

  void confirmSafe(Report r) {
    r.reporterConfirmed = true;
    notifyListeners();
  }

  /// Reports filed from this phone (the signed-in student).
  bool isMine(Report r) => r.reporter == 'Ananya S.';

  // ---------- reporting ----------
  void startDraft({Loc? at}) {
    draft = Draft()..loc = at;
    notifyListeners();
  }

  void setDraftLoc(Loc loc) {
    draft.loc = loc;
    notifyListeners();
  }

  void setVenom(Venom v) {
    draft.venom = v;
    final s = draft.speciesId;
    if (s != null && speciesById(s).venomous != (v == Venom.venomous) && v != Venom.unsure) draft.speciesId = null;
    notifyListeners();
  }

  void setSpecies(String? id) {
    draft.speciesId = draft.speciesId == id ? null : id;
    notifyListeners();
  }

  void setPhoto(String? path, {String? matchedId, String? matchedName, Venom? venom}) {
    draft.photoPath = path;
    draft.matchedId = matchedId;
    draft.matchedName = matchedId == null ? matchedName : null;
    if (matchedId != null) {
      draft.speciesId = matchedId;
      draft.venom = speciesById(matchedId).venomous ? Venom.venomous : Venom.nonVenomous;
    } else if (venom != null) {
      draft.speciesId = null;
      draft.venom = venom;
    }
    notifyListeners();
  }

  Report submit() {
    final loc = draft.loc ?? currentLoc;
    final r = Report(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      speciesId: draft.speciesId,
      venom: draft.venom ?? Venom.unsure,
      place: loc.name,
      note: draft.note,
      reporter: 'Ananya S.',
      pos: loc.pos,
      covered: loc.covered,
      photoPath: draft.photoPath,
    );
    reports.insert(0, r);
    notifyListeners();
    if (r.covered && role == Role.student) _demoResponse(r);
    return r;
  }

  /// Demo only: there is no real authority on another phone, so a student's
  /// new report is "opened" after a few seconds and the authority sets off
  /// soon after. Reaching the spot and resolving are left to the authority
  /// console (sign in as hostel authority to try them).
  void _demoResponse(Report r) {
    if (r.place == authorityHostel) r.handler = kamengAuthority;
    Timer(const Duration(seconds: 12), () {
      if (r.stage == Stage.reported) markSeen([r]);
    });
    Timer(const Duration(seconds: 35), () {
      if (r.stage == Stage.seen) setOnTheWay(r);
    });
  }

  /// Place picked from the list. Buildings with an OpenStreetMap outline use
  /// its real position; the rest get an approximate spot on campus (demo).
  Loc locFromList(Place place, bool covered) {
    LatLng pos;
    if (place.zone != null) {
      pos = zoneCentre(place.zone!);
    } else {
      final rnd = Random(place.label.hashCode);
      pos = LatLng(campusCenter.latitude + (rnd.nextDouble() - 0.5) * 0.008, campusCenter.longitude + (rnd.nextDouble() - 0.5) * 0.012);
    }
    return Loc(place.label, 'Chosen from the list', covered: covered, pos: pos);
  }

  /// Place picked by tapping the map: a hostel or campus building if the pin
  /// is on its premises, otherwise an open area (no authority).
  Loc locFromMap(LatLng p) {
    if (!onCampus(p)) {
      return Loc('Outside IIT Guwahati campus', 'Pinned on the map', covered: false, pos: p, outside: true);
    }
    final z = zoneAt(p);
    return z != null
        ? Loc(z.name, 'Pinned on the map', covered: true, pos: p)
        : Loc(openAreaName(p), 'Pinned on the map', covered: false, pos: p);
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
