import 'package:flutter/material.dart';

import '../theme.dart';

/// A horizontal row with ‹ › buttons on the edges, shown only when there is
/// more to see that way, so people know the row scrolls. Tapping an arrow
/// moves the row about one screen width.
class ScrollArrows extends StatefulWidget {
  final List<Widget> children;

  /// Distance from the top of the row to the middle of the arrows.
  final double arrowCentre;
  const ScrollArrows({super.key, required this.children, this.arrowCentre = 38});

  @override
  State<ScrollArrows> createState() => _ScrollArrowsState();
}

class _ScrollArrowsState extends State<ScrollArrows> {
  final _ctrl = ScrollController();
  bool _left = false, _right = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _update() {
    if (!_ctrl.hasClients) return;
    final p = _ctrl.position;
    final left = p.pixels > 4, right = p.pixels < p.maxScrollExtent - 4;
    if (left != _left || right != _right) {
      setState(() {
        _left = left;
        _right = right;
      });
    }
  }

  void _go(int dir) {
    final p = _ctrl.position;
    _ctrl.animateTo(
      (p.pixels + dir * p.viewportDimension * 0.8).clamp(0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _fade(bool left) => IgnorePointer(
    child: Container(
      width: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: left ? Alignment.centerLeft : Alignment.centerRight,
          end: left ? Alignment.centerRight : Alignment.centerLeft,
          colors: [C.bg, C.bg.withValues(alpha: 0)],
        ),
      ),
    ),
  );

  Widget _arrow(bool left) => Material(
    color: const Color(0xEE262626),
    shape: const CircleBorder(side: BorderSide(color: Color(0xFF3A3A3A))),
    elevation: 3,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _go(left ? -1 : 1),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: C.text, size: 24),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (_) {
      _update();
      return false;
    },
    child: Stack(
      children: [
        ListView(controller: _ctrl, scrollDirection: Axis.horizontal, children: widget.children),
        if (_left) Positioned(left: 0, top: 0, bottom: 0, child: _fade(true)),
        if (_right) Positioned(right: 0, top: 0, bottom: 0, child: _fade(false)),
        // Arrows fade in and out rather than popping.
        Positioned(
          left: 2,
          top: widget.arrowCentre - 17,
          child: AnimatedOpacity(
            opacity: _left ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(ignoring: !_left, child: _arrow(true)),
          ),
        ),
        Positioned(
          right: 2,
          top: widget.arrowCentre - 17,
          child: AnimatedOpacity(
            opacity: _right ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(ignoring: !_right, child: _arrow(false)),
          ),
        ),
      ],
    ),
  );
}
