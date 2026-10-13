import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:snake_watch/data/app_state.dart';
import 'package:snake_watch/data/scanner.dart';
import 'package:snake_watch/main.dart';

void main() {
  testWidgets('Sign-in screen shows both sign-in options', (tester) async {
    await tester.pumpWidget(SnakeWatchApp(state: AppState()));
    expect(find.text('Sign in with Outlook'), findsOneWidget);
    expect(find.text('Hostel authority sign-in'), findsOneWidget);
  });

  test('Marking safe takes the full response: on the way, at the spot, then outcome and photo', () {
    final s = AppState();
    final r = s.hostelReports.firstWhere((r) => r.stage == Stage.seen);
    final before = s.hostelOpen;
    s.setOnTheWay(r);
    expect(r.stage, Stage.onTheWay);
    s.arrive(r);
    expect(r.stage, Stage.onSite);
    expect(r.locationVerified, isTrue); // the demo location is beside Kameng
    s.resolve(r, outcome: Outcome.notFound, proofPhoto: 'assets/snakes/keelback.jpg', note: ' Checked the drain. ');
    expect(r.safe, isTrue);
    expect(r.resolveNote, 'Checked the drain.');
    expect(r.reporterConfirmed, isNull); // the reporter is asked next
    expect(s.hostelOpen, before - 1);
  });

  test('Opening the console marks reports seen; overdue and disputed reports are flagged', () {
    final s = AppState();
    s.startDraft(at: s.locFromMap(const LatLng(26.19043, 91.70156)));
    final mine = s.submit();
    expect(mine.stage, Stage.reported);
    s.markSeen(s.hostelReports);
    expect(mine.stage, Stage.seen);
    expect(mine.seenAt, isNotNull);
    expect(mine.flagged, isFalse);

    // Seen 30 min ago but nobody went: overdue.
    expect(s.reports.firstWhere((r) => r.id == 'r2').flagged, isTrue);

    // The reporter says the snake is still there: reopened and escalated.
    final done = s.reports.firstWhere((r) => r.id == 'r4');
    s.reopen(done, byReporter: true);
    expect(done.safe, isFalse);
    expect(done.proofPhoto, isNull);
    expect(done.flagged, isTrue);
  });

  test('Pins on a hostel or campus building go to its authority; open areas go to nobody', () {
    final s = AppState();
    expect(s.locFromMap(const LatLng(26.19043, 91.70156)).name, 'Kameng Hostel');
    expect(s.locFromMap(const LatLng(26.18574, 91.68935)).name, 'Core 5');
    expect(s.locFromMap(const LatLng(26.19665, 91.69748)).name, 'IITG Hospital');
    expect(s.locFromMap(const LatLng(26.19248, 91.69901)).name, 'New SAC');
    expect(s.locFromMap(const LatLng(26.19580, 91.68998)).name, 'D-type Quarters');
    expect(s.locFromMap(const LatLng(26.19418, 91.69236)).name, 'IIT Guwahati Viewpoint');
    // Coordinates given by the user for KV, the pool and the Central Library
    expect(s.locFromMap(const LatLng(26.184588, 91.696582)).name, 'Kendriya Vidyalaya (KV)');
    expect(s.locFromMap(const LatLng(26.191318, 91.699137)).name, 'Swimming Pool');
    expect(s.locFromMap(const LatLng(26.189272, 91.693006)).name, 'Central Library');
    final field = s.locFromMap(const LatLng(26.19506, 91.70221)); // cricket ground
    expect(field.covered, isFalse);
    expect(field.name, 'Cricket Ground');
  });

  test('Pins outside the IIT Guwahati campus cannot be reported', () {
    final s = AppState();
    final gnrc = s.locFromMap(const LatLng(26.20214, 91.69395)); // GNRC hospital, north of campus
    expect(gnrc.outside, isTrue);
    expect(s.locFromMap(const LatLng(26.1825, 91.6990)).outside, isTrue); // main road south of campus
    expect(s.locFromMap(const LatLng(26.19043, 91.70156)).outside, isFalse); // Kameng Hostel
    expect(s.locFromMap(const LatLng(26.184588, 91.696582)).outside, isFalse); // KV
  });

  test('Open-area pins are named after the road, field or lake they are on', () {
    final s = AppState();
    expect(s.locFromMap(const LatLng(26.192957, 91.69016)).name, 'Suryamukhi Road');
    expect(s.locFromMap(const LatLng(26.19030, 91.69458)).name, 'IITG Lake');
    expect(s.locFromMap(const LatLng(26.19057, 91.69705)).name, 'Cricket Pitch');
  });

  test("A student's report inside Kameng reaches the Kameng authority's console", () {
    final s = AppState();
    final before = s.hostelOpen;
    s.startDraft(at: s.locFromMap(const LatLng(26.19043, 91.70156)));
    s.setVenom(Venom.venomous);
    final r = s.submit();
    expect(s.hostelReports, contains(r));
    expect(s.hostelOpen, before + 1);
  });

  test('Scanner answers are read into campus and non-campus matches', () {
    final r = Scanner.parse('''```json
{"is_snake": true, "matches": [
  {"id": "cobra", "name": "Spectacled Cobra", "latin": "x", "venomous": false, "confidence": 81.6},
  {"id": null, "name": "Checkered Keelback", "latin": "Fowlea piscator", "venomous": false, "confidence": 12},
  {"id": "made_up", "name": "Mystery Snake", "venomous": null, "confidence": 3}
], "note": "Hood with a single ring."}
```''');
    expect(r.isSnake, isTrue);
    expect(r.matches.first.speciesId, 'cobra');
    expect(r.matches.first.name, 'Monocled Cobra'); // campus data wins over the model's wording
    expect(r.matches.first.venomous, isTrue);
    expect(r.matches.first.confidence, 82);
    expect(r.matches[1].speciesId, isNull);
    expect(r.matches[1].venomous, isFalse);
    expect(r.matches[2].speciesId, isNull);
    expect(Scanner.parse('{"is_snake": false, "matches": []}').isSnake, isFalse);
  });

  test('Console tiles filter the list and tapping again shows everything', () {
    final s = AppState();
    s.toggleFilter(ConsoleFilter.overdue);
    expect(s.consoleFilter, ConsoleFilter.overdue);
    s.toggleFilter(ConsoleFilter.open);
    expect(s.consoleFilter, ConsoleFilter.open);
    s.toggleFilter(ConsoleFilter.open);
    expect(s.consoleFilter, ConsoleFilter.all);
  });
}
