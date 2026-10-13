import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';

/// Shows a snake photo from the app's assets, the phone's storage, or — in the
/// browser version — the picked file's blob URL.
Widget photoOf(String path, {BoxFit fit = BoxFit.cover}) {
  if (path.startsWith('assets/')) return Image.asset(path, fit: fit);
  if (kIsWeb) return Image.network(path, fit: fit);
  return Image.file(File(path), fit: fit);
}

/// Dark screen with the green "top glow" used across the Snake Alert screens.
class DarkPage extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget? bottom;
  final Widget? fab;
  const DarkPage({super.key, this.header, required this.body, this.bottom, this.fab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: fab,
      bottomNavigationBar: bottom,
      body: Stack(
        children: [
          Container(
            height: 170,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF12301D), Color(0x000F0F0F)],
              ),
            ),
          ),
          SafeArea(
            bottom: bottom == null,
            child: Column(
              children: [
                ?header,
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final Widget? badge;
  const RoundButton(this.icon, {super.key, this.onTap, this.color = C.green, this.size = 40, this.badge});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.card2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: size * 0.48),
              if (badge != null) Positioned(top: 7, right: 8, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final IconData backIcon;
  final Widget? trailing;
  const AppHeader(this.title, {super.key, this.subtitle, this.onBack, this.backIcon = Icons.chevron_left_rounded, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          RoundButton(backIcon, onTap: onBack ?? () => Navigator.maybePop(context)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: ft(20, w: 700), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle!, style: ft(12.5, color: C.muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.border,
    this.color = C.card,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border ?? C.line),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum BtnKind { primary, danger, ghost }

class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final IconData? icon;
  final double height;
  const Btn(this.label, {super.key, this.onTap, this.kind = BtnKind.primary, this.icon, this.height = 52});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    late Color bg, fg;
    Color? border;
    switch (kind) {
      case BtnKind.primary:
        bg = C.green;
        fg = C.greenInk;
      case BtnKind.danger:
        bg = const Color(0xFFE5382D);
        fg = Colors.white;
      case BtnKind.ghost:
        bg = const Color(0xFF262626);
        fg = C.text;
        border = const Color(0xFF3A3A3A);
    }
    if (!enabled) {
      bg = const Color(0xFF232323);
      fg = const Color(0xFF6E6E6E);
      border = null;
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
              Text(label, style: ft(15.5, w: 700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase status pill (VENOMOUS / NON-VENOMOUS / NOT SURE / SAFE).
class Tag extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const Tag(this.text, {super.key, required this.fg, required this.bg});

  factory Tag.forReport(Report r) {
    if (r.safe) {
      return r.outcome == Outcome.notFound
          ? const Tag('NOT FOUND', fg: Color(0xFFFFC46B), bg: Color(0xFF2A1E0B))
          : const Tag('SAFE', fg: C.greenText, bg: C.greenSoft);
    }
    switch (r.venom) {
      case Venom.venomous:
        return const Tag('VENOMOUS', fg: C.redText, bg: C.redSoft);
      case Venom.nonVenomous:
        return const Tag('NON-VENOMOUS', fg: C.greenText, bg: C.greenSoft);
      case Venom.unsure:
        return const Tag('NOT SURE', fg: Color(0xFFFFC46B), bg: Color(0xFF2A1E0B));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: ft(10.5, w: 700, color: fg, ls: 0.6)),
  );
}

/// Deep, saturated map-pin colours so pins stand out on the light map.
const pinVenomous = Color(0xFFD92D20);
const pinNonVenomous = Color(0xFF0E9384);
const pinUnsure = Color(0xFFDC7900);
const pinDropped = Color(0xFF16A34A);

/// Pin colour on the map for a report.
Color pinColor(Report r) {
  if (r.safe) return const Color(0xFF6B6B6B);
  switch (r.venom) {
    case Venom.venomous:
      return pinVenomous;
    case Venom.unsure:
      return pinUnsure;
    case Venom.nonVenomous:
      return pinNonVenomous;
  }
}

class SnakeThumb extends StatelessWidget {
  final Report r;
  final double size;
  const SnakeThumb(this.r, {super.key, this.size = 68});

  @override
  Widget build(BuildContext context) {
    final sp = r.sp;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size,
        height: size,
        child: sp != null
            ? Image.asset(sp.photo, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFF2A2A2A),
                child: Icon(Icons.help_outline_rounded, color: pinColor(r), size: size * 0.42),
              ),
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, style: ft(13.5)),
        backgroundColor: const Color(0xFF262626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}
