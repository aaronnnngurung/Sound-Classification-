import 'package:flutter/material.dart';

/// Keeps [child] inside the visible, unclipped region of a round Wear OS
/// screen. Regular Flutter `SafeArea` only accounts for rectangular
/// system insets (status bar, notch) — it does nothing for the physical
/// corner-clipping of a round bezel, which is why content and buttons
/// placed flush against the edge (e.g. a standard AppBar's back button,
/// top-left) can get cut off or become untappable on round watches.
///
/// Computes inset as a fraction of the screen's shortest side via
/// MediaQuery rather than a hardcoded pixel value, so it holds up across
/// different round profiles (Wear OS Small Round, Large Round, etc.),
/// not just whatever emulator you're testing on right now.
class WatchRoundSafeArea extends StatelessWidget {
  final Widget child;
  final double insetFraction;

  const WatchRoundSafeArea({
    Key? key,
    required this.child,
    this.insetFraction = 0.15,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final inset = shortestSide * insetFraction;

    return Padding(padding: EdgeInsets.all(inset), child: Center(child: child));
  }
}