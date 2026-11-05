import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../state.dart';

class WallpaperStyle {
  final String name;
  final List<Color> base;
  final List<Color> blobs;
  final List<Offset> spots;
  const WallpaperStyle(this.name, this.base, this.blobs, this.spots);
}

const wallpapers = [
  WallpaperStyle('Aurora', [Color(0xFF0B1026), Color(0xFF1B1F4B)], [Color(0xFF7C3AED), Color(0xFF06B6D4), Color(0xFFF472B6)],
      [Offset(0.15, 0.2), Offset(0.9, 0.4), Offset(0.4, 0.9)]),
  WallpaperStyle('Sunset', [Color(0xFF2A0A1F), Color(0xFF3B0D2E)], [Color(0xFFFB923C), Color(0xFFF43F5E), Color(0xFFFACC15)],
      [Offset(0.8, 0.15), Offset(0.1, 0.55), Offset(0.7, 0.95)]),
  WallpaperStyle('Ocean', [Color(0xFF021B2E), Color(0xFF04314F)], [Color(0xFF0EA5E9), Color(0xFF22D3EE), Color(0xFF6366F1)],
      [Offset(0.2, 0.1), Offset(0.85, 0.6), Offset(0.25, 0.85)]),
  WallpaperStyle('Forest', [Color(0xFF04140E), Color(0xFF0A2A1C)], [Color(0xFF10B981), Color(0xFF84CC16), Color(0xFF0EA5E9)],
      [Offset(0.75, 0.2), Offset(0.2, 0.5), Offset(0.8, 0.9)]),
  WallpaperStyle('Candy', [Color(0xFF1A0B2E), Color(0xFF2D0B3E)], [Color(0xFFA855F7), Color(0xFFEC4899), Color(0xFF38BDF8)],
      [Offset(0.1, 0.3), Offset(0.9, 0.2), Offset(0.5, 0.8)]),
  WallpaperStyle('Graphite', [Color(0xFF0A0A0A), Color(0xFF1C1C1E)], [Color(0xFF52525B), Color(0xFF3F3F46), Color(0xFF71717A)],
      [Offset(0.2, 0.2), Offset(0.85, 0.55), Offset(0.3, 0.95)]),
];

class WallpaperPainter extends CustomPainter {
  final WallpaperStyle style;
  WallpaperPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: style.base).createShader(rect),
    );
    final r = max(size.width, size.height) * 0.75;
    for (var i = 0; i < style.blobs.length; i++) {
      final c = Offset(style.spots[i].dx * size.width, style.spots[i].dy * size.height);
      final paint = Paint()
        ..shader = RadialGradient(colors: [style.blobs[i].withValues(alpha: 0.85), style.blobs[i].withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(WallpaperPainter old) => old.style != style;
}

class WallpaperView extends StatelessWidget {
  const WallpaperView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final path = s.wallpaperPath;
        final size = MediaQuery.sizeOf(context);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        if (path != null) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            cacheWidth: (size.width * dpr).round(),
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _gradient(s.wallpaperIndex),
          );
        }
        return _gradient(s.wallpaperIndex);
      },
    );
  }

  Widget _gradient(int i) => RepaintBoundary(
        child: CustomPaint(painter: WallpaperPainter(wallpapers[i.clamp(0, wallpapers.length - 1)]), size: Size.infinite),
      );
}
