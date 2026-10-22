import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/scanner.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sign_in.dart';

void logOut(BuildContext context) {
  AppScope.read(context).setRole(Role.none);
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
}

/// Card at the top of both profiles (IIT Guwahati header, photo, name).
class IdCard extends StatelessWidget {
  final Widget avatar;
  final String name;
  final List<String> lines;
  final bool barcode;
  const IdCard({super.key, required this.avatar, required this.name, required this.lines, this.barcode = false});

  @override
  Widget build(BuildContext context) => Panel(
    border: C.green.withValues(alpha: 0.75),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/iitg_logo.png', width: 32, height: 32),
            const SizedBox(width: 16),
            Text('Indian Institute of\nTechnology, Guwahati', style: ft(14, color: C.sub, height: 1.4)),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(color: C.line, height: 1),
        const SizedBox(height: 18),
        avatar,
        const SizedBox(height: 12),
        Text(name, style: ft(20, w: 600)),
        const SizedBox(height: 4),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(l, style: ft(14, color: C.sub)),
          ),
        if (barcode) ...[const SizedBox(height: 14), SizedBox(width: 204, height: 58, child: CustomPaint(painter: _Barcode()))],
      ],
    ),
  );
}

class _Barcode extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var seed = 210102043, x = 0.0;
    double rnd() => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
    final p = Paint()..color = Colors.white;
    while (x < size.width) {
      final w = [2.0, 2.0, 3.0, 4.0, 5.0][(rnd() * 5).floor()];
      if (x + w > size.width) break;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w + [2.0, 3.0, 4.0][(rnd() * 3).floor()];
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InfoRow {
  final IconData icon;
  final String label, value;
  final bool editable;
  final Widget? trailing;
  const InfoRow(this.icon, this.label, this.value, {this.editable = true, this.trailing});
}

class InfoCard extends StatelessWidget {
  final List<InfoRow> rows;
  const InfoCard(this.rows, {super.key});
  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const Divider(color: C.line, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                Icon(r.icon, color: C.green, size: 19),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.label, style: ft(13.5, color: C.muted)),
                      const SizedBox(height: 4),
                      Text(
                        r.value.isEmpty ? 'Not added' : r.value,
                        style: ft(15, color: r.value.isEmpty ? const Color(0xFF5C5C5C) : C.text),
                      ),
                    ],
                  ),
                ),
                if (r.trailing != null) r.trailing!,
                if (r.editable)
                  IconButton(
                    onPressed: () => toast(context, 'Editing isn’t part of this demo'),
                    icon: const Icon(Icons.edit_outlined, color: C.green, size: 19),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Lets the user use their own AI key for the snake scanner instead of the
/// app's built-in free one. The key is saved only on this device.
Future<void> showScannerKeyDialog(BuildContext context) async {
  final current = await Scanner.loadKey();
  if (!context.mounted) return;
  final ctrl = TextEditingController(text: current ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Snake scanner key', style: ft(18, w: 700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Optional. The scanner already works for free. To use your own key instead, paste a '
            'Google Gemini key (AIza…) or an Anthropic key (sk-ant-…). It is saved only on this device.',
            style: ft(13, color: C.sub, height: 1.45),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: ft(14),
            decoration: InputDecoration(
              hintText: 'AIza… or sk-ant-…',
              hintStyle: ft(14, color: C.muted),
              filled: true,
              fillColor: C.card2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            current != null
                ? 'Using your own key.'
                : (Scanner.builtInKey != null ? 'Using the app’s free scanner.' : 'No key: the scanner shows demo matches.'),
            style: ft(12, color: current == null && Scanner.builtInKey == null ? C.amber : C.greenText),
          ),
        ],
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () {
              ctrl.clear();
              Navigator.pop(ctx, true);
            },
            child: Text('Remove', style: ft(14, w: 600, color: C.redText)),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: ft(14, color: C.sub))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save', style: ft(14, w: 700, color: C.green))),
      ],
    ),
  );
  if (saved != true) return;
  final key = ctrl.text.trim();
  await Scanner.saveKey(key);
  if (context.mounted) toast(context, key.isEmpty ? 'Your key was removed' : 'Your scanner key was saved');
}

class ProfileActions extends StatelessWidget {
  const ProfileActions({super.key});
  @override
  Widget build(BuildContext context) {
    Widget b(IconData icon, String label, VoidCallback onTap, {Color color = C.text}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: C.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: C.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color == C.text ? C.sub : color),
                const SizedBox(width: 10),
                Text(label, style: ft(16, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        b(Icons.document_scanner_outlined, 'Snake scanner key', () => showScannerKeyDialog(context)),
        b(
          Icons.info_outline_rounded,
          'About Us',
          () => showAboutDialog(
            context: context,
            applicationName: 'Onestop · Snake Alert',
            applicationVersion: 'Demo 1.0',
            applicationLegalese: 'A standalone demo of the Snake Alert add-on for the Onestop app. Uses example data only.',
          ),
        ),
        b(Icons.bug_report_outlined, 'Bug/Feature Request', () => toast(context, 'Thanks! Feedback isn’t sent in this demo')),
        b(Icons.light_mode_outlined, 'Switch to Light Mode', () => toast(context, 'Light mode isn’t part of this demo')),
        b(Icons.logout_rounded, 'Log Out', () => logOut(context), color: const Color(0xFFFF6B6B)),
        const SizedBox(height: 18),
        Opacity(opacity: 0.85, child: Image.asset('assets/images/swc.png', height: 30)),
      ],
    );
  }
}

class StudentProfile extends StatelessWidget {
  const StudentProfile({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return DarkPage(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'One', style: ft(28, w: 700)),
                    TextSpan(
                      text: '.',
                      style: ft(28, w: 700, color: C.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IdCard(
            avatar: ClipOval(child: Image.asset('assets/images/avatar_student.png', width: 88, height: 88, fit: BoxFit.cover)),
            name: s.studentName,
            lines: const ['210102043', 'IIT Guwahati'],
            barcode: true,
          ),
          const SizedBox(height: 22),
          Text('Additional Information', style: ft(17, w: 600)),
          const SizedBox(height: 12),
          InfoCard([
            InfoRow(Icons.mail_outline_rounded, 'Outlook ID', s.studentEmail, editable: false),
            const InfoRow(Icons.mail_outline_rounded, 'Alternate Email', 'ananya.sharma@gmail.com'),
            const InfoRow(Icons.call_outlined, 'Contact Number', '98765 43210'),
            const InfoRow(Icons.call_outlined, 'Emergency Contact Number', '91234 56780'),
            const InfoRow(Icons.person_outline_rounded, 'Gender', 'Female'),
            const InfoRow(Icons.apartment_outlined, 'Hostel', 'Kameng'),
            const InfoRow(Icons.restaurant_outlined, 'Subscribed Mess', 'Kameng'),
            const InfoRow(Icons.apartment_outlined, 'Room Number', 'B2-17'),
            const InfoRow(Icons.calendar_month_outlined, 'Date of Birth', '14-03-2004'),
            const InfoRow(Icons.home_outlined, 'Home Address', 'Jaipur, Rajasthan'),
            const InfoRow(Icons.pedal_bike_outlined, 'Cycle Registration Number', ''),
            const InfoRow(Icons.link_rounded, 'LinkedIn Profile', ''),
          ]),
          const SizedBox(height: 22),
          const ProfileActions(),
        ],
      ),
    );
  }
}
