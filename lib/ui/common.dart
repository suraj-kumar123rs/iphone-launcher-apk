import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';

/// iOS-like "squircle" shape for icons.
ShapeBorder squircle(double size) => ContinuousRectangleBorder(borderRadius: BorderRadius.circular(size * 0.46));

double iconSizeFor(BuildContext c) {
  final w = MediaQuery.sizeOf(c).width;
  return ((w - 32) / 4 * 0.64).clamp(44.0, 72.0).toDouble();
}

/// Frosted glass panel.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double alpha;
  final double blur;
  final double? width, height;
  final Color tint;

  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.alpha = 0.16,
    this.blur = 26,
    this.width,
    this.height,
    this.tint = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.6),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Pushes a transparent full-screen overlay (search, folders, controls…).
Future<T?> pushOverlay<T>(BuildContext context, Widget Function(BuildContext, Animation<double>) builder) {
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, _) => Material(type: MaterialType.transparency, child: builder(ctx, anim)),
    transitionsBuilder: (_, __, ___, child) => child,
  ));
}

/// Animated blur + dim layer behind overlays.
class BlurBackdrop extends StatelessWidget {
  final Animation<double> anim;
  final double sigma;
  final double dim;
  final VoidCallback? onTap;

  const BlurBackdrop({super.key, required this.anim, this.sigma = 30, this.dim = 0.3, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = Curves.easeOut.transform(anim.value.clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma * t + 0.01, sigmaY: sigma * t + 0.01),
            child: Container(color: Colors.black.withValues(alpha: dim * t)),
          ),
        );
      },
    );
  }
}

/// Scale + fade entrance used by overlays.
class PopIn extends StatelessWidget {
  final Animation<double> anim;
  final Widget child;
  final double from;
  final Alignment alignment;
  const PopIn({super.key, required this.anim, required this.child, this.from = 0.9, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween(begin: from, end: 1.0).animate(curved), alignment: alignment, child: child),
    );
  }
}

class IconLabel extends StatelessWidget {
  final String text;
  const IconLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  final AppInfo? app;
  final double size;
  const AppIcon({super.key, required this.app, required this.size});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final a = app;
    final img = a == null
        ? _fallback()
        : Image.file(
            File(a.icon),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * dpr).round(),
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _fallback(),
          );
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(clipper: ShapeBorderClipper(shape: squircle(size)), child: img),
    );
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        color: const Color(0xFF3A3A3C),
        child: Icon(Icons.android_rounded, color: Colors.white70, size: size * 0.5),
      );
}

/// Folder icon: frosted squircle with a 3x3 grid of mini icons.
class FolderIcon extends StatelessWidget {
  final List<String> pkgs;
  final double size;
  const FolderIcon({super.key, required this.pkgs, required this.size});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    final pad = size * 0.13;
    final gap = size * 0.05;
    final mini = ((size - pad * 2 - gap * 2) / 3).floorToDouble();
    final shown = pkgs.take(9).toList();
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: squircle(size)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: Colors.white.withValues(alpha: 0.26),
            padding: EdgeInsets.all(pad),
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < 3; r++)
                  Padding(
                    padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < 3; c++)
                          Padding(
                            padding: EdgeInsets.only(left: c == 0 ? 0 : gap),
                            child: r * 3 + c < shown.length
                                ? AppIcon(app: s.apps[shown[r * 3 + c]], size: mini)
                                : SizedBox(width: mini, height: mini),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wiggle animation for edit mode.
class Jiggle extends StatefulWidget {
  final int seed;
  final Widget child;
  const Jiggle({super.key, required this.seed, required this.child});

  @override
  State<Jiggle> createState() => _JiggleState();
}

class _JiggleState extends State<Jiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final s = widget.seed.abs();
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: 230 + (s % 5) * 18));
    _c.value = (s % 100) / 100;
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = widget.seed.isEven ? 1.0 : -1.0;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.rotate(angle: (_c.value - 0.5) * 0.05 * dir, child: child),
    );
  }
}

class MinusBadge extends StatelessWidget {
  final VoidCallback onTap;
  const MinusBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFD1D1D6),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: const Icon(Icons.remove_rounded, size: 16, color: Colors.black87),
        ),
      ),
    );
  }
}

/// Rounded card used by widgets.
class WidgetCard extends StatelessWidget {
  final Widget child;
  final double? width, height;
  final Gradient? gradient;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const WidgetCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.gradient,
    this.color = const Color(0xFF1C1C1E),
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: ShapeDecoration(
          color: gradient == null ? color : null,
          gradient: gradient,
          shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(48)),
          shadows: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: child,
      ),
    );
  }
}
