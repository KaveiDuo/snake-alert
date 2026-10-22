import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snake_watch/data/app_state.dart';
import 'package:snake_watch/data/scanner.dart';
import 'package:snake_watch/data/species.dart';
import 'package:snake_watch/main.dart';
import 'package:snake_watch/screens/authority_sign_in.dart';
import 'package:snake_watch/screens/notifications.dart';
import 'package:snake_watch/screens/sighting_detail.dart';

void main() {
  testWidgets('Sign-in: Student, Housekeeping, Security and Warden options change the one button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(SnakeWatchApp(state: AppState()));
    await tester.pumpAndSettle();
    expect(find.text('Student'), findsOneWidget);
    for (final o in ['Housekeeping', 'Security', 'Warden']) {
      expect(find.text(o), findsOneWidget);
    }
    expect(find.text('Sign in with Outlook'), findsOneWidget);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with phone number'), findsOneWidget);
    expect(find.text('Sign in with Outlook'), findsNothing);
    expect((await SharedPreferences.getInstance()).getString('sign_in_as'), 'security'); // remembered
  });

  test('Escalation ladder: Housekeeping, then security guard at 15 min, then warden at 30 min', () {
    final s = AppState();
    Report open(int minutesAgo) => Report(
      id: 't$minutesAgo',
      venom: Venom.unsure,
      place: 'Kameng Hostel',
      pos: const LatLng(26.1902, 91.7018),
      covered: true,
      time: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );
    expect(open(5).level, AdminRole.housekeeping);
    expect(open(20).level, AdminRole.security);
    expect(open(40).level, AdminRole.warden);
    // Reaching the spot stops the climb.
    final reached = open(40)
      ..stage = Stage.onSite
      ..onSiteAt = DateTime.now().subtract(const Duration(minutes: 30));
    expect(reached.level, AdminRole.housekeeping);
    expect(reached.needs(AdminRole.security), isFalse);
    // The reporter saying it's still there goes straight to the security guard.
    final r = s.hostelReports.firstWhere((x) => x.stage == Stage.seen && !x.flagged);
    s.setOnTheWay(r);
    s.arrive(r);
    s.resolve(r, outcome: Outcome.notFound, searched: const ['Drains']);
    s.reopen(r, byReporter: true);
    expect(r.level, AdminRole.security);
    expect(r.needs(AdminRole.security), isTrue);
    expect(r.needs(AdminRole.warden), isFalse);
  });

  test('Each admin is alerted once about reports escalated to their role; taking one shows who has it', () {
    final s = AppState()..role = Role.authority;
    expect(s.takeNewEscalations(), isEmpty); // Housekeeping gets new reports, not escalations
    s.setAdminRole(AdminRole.security);
    final first = s.takeNewEscalations();
    expect(first, isNotEmpty);
    expect(s.takeNewEscalations(), isEmpty); // not alerted twice
    s.setAdminRole(AdminRole.warden);
    expect(s.takeNewEscalations().every((r) => r.level == AdminRole.warden), isTrue);
    s.setAdminRole(AdminRole.security);
    final r = s.escalatedToMe.first;
    s.setOnTheWay(r);
    expect(r.handlerName, 'R. Das (Security guard)');
    // Housekeeping sees everything; the security guard and warden only what reached them.
    s.setAdminRole(AdminRole.housekeeping);
    final all = s.adminReports.length;
    s.setAdminRole(AdminRole.security);
    expect(s.adminReports.length, lessThan(all));
    expect(
      s.adminReports.where((x) => !x.safe).every((x) => x.level != AdminRole.housekeeping || x.handlerRole == AdminRole.security),
      isTrue,
    );
    s.setAdminRole(AdminRole.warden);
    expect(s.adminReports.every((x) => x.level == AdminRole.warden || x.handlerRole == AdminRole.warden), isTrue);
  });

  test('The warden oversees: reminders reach Housekeeping and Security again; the warden is never alerted to go', () {
    final s = AppState()..role = Role.authority;
    s.setAdminRole(AdminRole.warden);
    final r = s.escalatedToMe.first;
    expect(r.seenAt, isNotNull); // seen earlier by Housekeeping, not by the warden opening it
    s.takeNewEscalations();
    s.remind(r);
    s.logCall(r, AdminRole.security);
    expect(r.calls.single.$1, AdminRole.warden);
    expect(r.calls.single.$2, AdminRole.security);
    expect(s.remindedToMe, isEmpty); // the warden doesn't remind themselves
    s.setAdminRole(AdminRole.housekeeping);
    expect(s.takeNewEscalations(), contains(r));
    s.setAdminRole(AdminRole.security);
    expect(s.takeNewEscalations(), contains(r));
    expect(s.takeNewEscalations(), isEmpty); // once per reminder
    expect(r.alertedAt(AdminRole.warden).difference(r.alertedAt(AdminRole.security)), escalateEvery);
  });

  testWidgets('Admin sign-in: the phone number decides the account; unregistered numbers are refused', (t) async {
    expect(Staff.byPhone('98765 43210')!.post, AdminRole.housekeeping);
    expect(Staff.byPhone('9876543213')!.name, 'S. Bora'); // several staff per post
    expect(Staff.byPhone('98765 43211')!.post, AdminRole.security);
    expect(Staff.byPhone('98765 43212')!.post, AdminRole.warden);
    expect(Staff.byPhone('91234 56780'), isNull);
    final s = AppState();
    await t.pumpWidget(AppScope(state: s, child: const MaterialApp(home: AuthorityPhoneScreen())));
    await t.tap(find.text('Security'));
    await t.pump();
    await t.tap(find.text('R. Das'));
    await t.pump();
    expect(find.text('Registered: R. Das · Security guard'), findsOneWidget);
    // A housekeeping number can't sign in under Security.
    await t.enterText(find.byType(TextField), '98765 43213');
    await t.pump();
    expect(find.textContaining('registered for Housekeeping'), findsOneWidget);
    await t.enterText(find.byType(TextField), '91234 56780');
    await t.pump();
    expect(find.textContaining('isn’t registered'), findsOneWidget);
  });

  testWidgets('On the way: "At the spot" fills in by itself when the admin gets there', (tester) async {
    final s = AppState()..role = Role.authority;
    final r = s.hostelReports.firstWhere((r) => r.stage == Stage.seen);
    s.setOnTheWay(r);
    expect(r.distanceLeft, greaterThan(onSiteRadiusMetres)); // still walking
    final start = r.distanceLeft!;
    await tester.pump(const Duration(seconds: 3));
    expect(r.distanceLeft, lessThan(start)); // getting closer
    await tester.pump(const Duration(seconds: 20));
    expect(r.stage, Stage.onSite); // no tap on Reached needed
    expect(r.arrivedAuto, isTrue);
    expect(r.locationVerified, isTrue);
    expect(r.distanceLeft, isNull);
    s.dispose();
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
    s.resolve(r, outcome: Outcome.chased, note: ' Moved it to the green belt. '); // photo and note are optional
    expect(r.safe, isTrue);
    expect(r.caution, isFalse);
    expect(r.resolveNote, 'Moved it to the green belt.');
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

  test('Pins on a hostel or campus building go to its admin; open areas go to nobody', () {
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

  test("A student's report inside Kameng reaches the Kameng admin's console", () {
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

  test('Demo data has two open and two resolved Kameng reports of each type', () {
    final s = AppState();
    for (final v in Venom.values) {
      final ofType = s.hostelReports.where((r) => r.venom == v);
      expect(ofType.where((r) => !r.safe).length, 2, reason: '$v open');
      expect(ofType.where((r) => r.safe).length, 2, reason: '$v resolved');
    }
    for (final r in s.hostelReports) {
      expect(s.locFromMap(r.pos).name, 'Kameng Hostel', reason: '${r.id} pin inside Kameng'); // pins on the premises
    }
  });

  test('Console: Open / Resolved switch and type filters', () {
    final s = AppState();
    List<Report> shown() =>
        s.hostelReports.where((r) => r.safe == (s.consoleTab == ConsoleTab.resolved)).where(s.consoleFilter.matches).toList();
    expect(shown().every((r) => !r.safe), isTrue);
    s.setConsoleFilter(ConsoleFilter.venomous);
    expect(shown().map((r) => r.id).toSet(), {'r1', 'r6'});
    s.setConsoleFilter(ConsoleFilter.overdue);
    expect(shown().map((r) => r.id).toSet(), {'r2', 'r9'});
    s.setConsoleTab(ConsoleTab.resolved); // overdue doesn't apply to resolved reports
    expect(s.consoleFilter, ConsoleFilter.all);
    expect(shown().map((r) => r.id).toSet(), {'r4', 'r10', 'r11', 'r12', 'r13', 'r14'});
    s.setConsoleFilter(ConsoleFilter.nonVenomous);
    s.setConsoleFilter(ConsoleFilter.nonVenomous); // tap again: back to all
    expect(s.consoleFilter, ConsoleFilter.all);
  });

  test('"Not found" needs where they searched and tells students to stay alert', () {
    final s = AppState();
    final r = s.reports.firstWhere((r) => r.id == 'r1');
    s.arrive(r);
    expect(() => s.resolve(r, outcome: Outcome.notFound), throwsA(isA<AssertionError>()));
    s.resolve(r, outcome: Outcome.notFound, searched: ['Drains', 'Under vehicles']);
    expect(r.safe, isTrue);
    expect(r.caution, isTrue);
    expect(r.proofPhoto, isNull);
    expect(s.openReports, isNot(contains(r))); // removed from the map
  });

  test('Calling the rescuer is recorded for students to see', () {
    final s = AppState();
    final r = s.reports.firstWhere((r) => r.id == 'r2');
    expect(r.rescuerCalledAt, isNull);
    s.callRescuer(r);
    expect(r.rescuerCalledAt, isNotNull);
  });

  testWidgets('Only students see "Call the admin now" on a sighting', (tester) async {
    for (final role in [Role.student, Role.authority]) {
      final s = AppState()..role = role;
      await tester.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(home: SightingDetailScreen(report: s.reports.firstWhere((r) => r.id == 'r1'))),
        ),
      );
      expect(find.text('Call the admin now'), role == Role.student ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox()); // stop the live clock
    }
  });

  testWidgets('Notifications: snake-type filter under Snake Alert', (tester) async {
    final s = AppState()..role = Role.student;
    await tester.pumpWidget(
      AppScope(
        state: s,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    expect(find.text('Open area'), findsNothing); // only under Snake Alert
    await tester.tap(find.text('Snake Alert'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Venomous'), const Offset(-300, 0)); // swipe the type row
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open area'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lake-side Path'), findsOneWidget);
    expect(find.textContaining('Cricket Ground'), findsOneWidget);
    expect(find.textContaining('back gate'), findsNothing); // Kameng reports hidden
  });

  test('Every look-alike warning pairs a harmless snake with a venomous one', () {
    for (final MapEntry(key: harmless, value: (danger, tip)) in venomousLookAlikes.entries) {
      expect(speciesById(harmless).venomous, isFalse, reason: harmless);
      expect(speciesById(danger).venomous, isTrue, reason: danger);
      expect(tip, isNotEmpty);
    }
  });

  test('A scanned snake that is not a campus species keeps its name in the report', () {
    final s = AppState();
    s.startDraft(at: s.locFromMap(const LatLng(26.19043, 91.70156)));
    s.setPhoto('photo.jpg', matchedName: 'Saw-scaled Viper', venom: Venom.venomous);
    final r = s.submit();
    expect(r.title, 'Saw-scaled Viper');
    expect(r.venom, Venom.venomous);
  });

  test('Background scan fills in the report but never contradicts the student', () {
    const krait = ScanMatch(speciesId: 'banded_krait', name: 'Banded Krait', venomous: true, confidence: 80);
    const wolf = ScanMatch(speciesId: 'wolf', name: 'Common Wolf Snake', venomous: false, confidence: 80);
    final kameng = const LatLng(26.19043, 91.70156);

    // Still writing the report, venom not chosen yet: filled in.
    final s = AppState();
    s.startDraft(at: s.locFromMap(kameng));
    s.startBackgroundScan('a.jpg');
    expect(s.draft.scanning, isTrue);
    s.finishBackgroundScan('a.jpg', krait);
    expect(s.draft.scanning, isFalse);
    expect(s.draft.speciesId, 'banded_krait');
    expect(s.draft.venom, Venom.venomous);

    // Student said venomous, scan says a harmless snake: their answer stands.
    final s2 = AppState();
    s2.startDraft(at: s2.locFromMap(kameng));
    s2.setVenom(Venom.venomous);
    s2.startBackgroundScan('b.jpg');
    s2.finishBackgroundScan('b.jpg', wolf);
    expect(s2.draft.venom, Venom.venomous);
    expect(s2.draft.speciesId, isNull);

    // Report already sent as "Not sure": updated when the scan finishes.
    final s3 = AppState();
    s3.startDraft(at: s3.locFromMap(kameng));
    s3.setVenom(Venom.unsure);
    s3.startBackgroundScan('c.jpg');
    final r = s3.submit();
    s3.finishBackgroundScan('c.jpg', const ScanMatch(name: 'Saw-scaled Viper', venomous: true, confidence: 70));
    expect(r.title, 'Saw-scaled Viper');
    expect(r.venom, Venom.venomous);
  });
}
