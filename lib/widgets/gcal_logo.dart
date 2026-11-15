import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The gcal brand mark: a rounded blue calendar tile with a paper fold, a
/// pink mic dot and an in-tile "G". Drawn with [CustomPainter] in a 512-space
/// so it scales cleanly and matches the shipped launcher icon exactly.
///
/// Blue/pink/glyph defaults follow the active brightness, matching the
/// landing page's theme (glyph = the adaptive `--logo-mark` color).
class GcalLogo extends StatelessWidget {
  const GcalLogo({super.key, this.size = 64, this.blue, this.pink, this.glyph});

  final double size;

  /// Optional overrides; when null the colors follow the active theme.
  final Color? blue;
  final Color? pink;
  final Color? glyph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = theme.brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GMarkPainter(
          blue: blue ?? GcalPalette.blue(d),
          pink: pink ?? GcalPalette.pink(d),
          glyph: glyph ?? gcalKeyColor(theme),
        ),
      ),
    );
  }
}

class _GMarkPainter extends CustomPainter {
  const _GMarkPainter({
    required this.blue,
    required this.pink,
    required this.glyph,
  });

  final Color blue;
  final Color pink;
  final Color glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 512;
    canvas.save();
    canvas.scale(k);

    final c = 256.0;
    final s = 170.0;

    final tile = RRect.fromRectAndRadius(
      Rect.fromLTRB(c - s, c - s, c + s, c + s),
      const Radius.circular(64),
    );

    final notch = RRect.fromRectAndRadius(
      Rect.fromLTRB(c - s + 38, c - s + 26, c - s + 150, c - s + 74),
      const Radius.circular(24),
    );

    canvas.drawRRect(tile, Paint()..color = blue);
    canvas.drawRRect(notch, Paint()..color = glyph);

    canvas.drawCircle(
      Offset(c + s - 79, c + s - 79),
      39,
      Paint()..color = pink,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          fontSize: 300,
          fontWeight: FontWeight.w900,
          color: glyph,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c + 10 - tp.width / 2, c + 16 - tp.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GMarkPainter oldDelegate) =>
      oldDelegate.blue != blue ||
      oldDelegate.pink != pink ||
      oldDelegate.glyph != glyph;
}