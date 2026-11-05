import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../native.dart';
import '../state.dart';
import '../weather.dart';
import 'common.dart';
import 'control_center.dart';
import 'grid.dart';
import 'library.dart';
import 'settings.dart';
import 'spotlight.dart';
import 'today.dart';
import 'wallpaper.dart';

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> with WidgetsBindingObserver {
  final s = Launcher.i;
  final pc = PageController(initialPage: 1);
  bool _foreground = true;
  Offset _dragStart = Offset.zero;
  double _dy = 0;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Native.onHome = _onHome;
    Native.onAppsChanged = s.refresh;
    s.refresh();
    Weather.i.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      s.refresh();
      Weather.i.refresh();
    }
  }

  double get _page => pc.hasClients && pc.position.hasContentDimensions ? (pc.page ?? 1) : 1;

  void _goHomePage() {
    if (pc.hasClients) pc.animateToPage(1, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  /// Home button pressed.
  void _onHome() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final hadRoute = nav.canPop();
    nav.popUntil((r) => r.isFirst);
    if (!_foreground) return;
    if (s.editing) {
      s.setEditing(false);
      return;
    }
    if (!hadRoute && _page.round() != 1) _goHomePage();
  }

  /// 1 on home pages, fades to 0 towards Today view / Library.
  double _homeFactor(int n) {
    final p = _page;
    if (p < 1) return p.clamp(0.0, 1.0);
    if (p > n) return (n + 1 - p).clamp(0.0, 1.0);
    return 1;
  }

  void _onSwipeDown() {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    if (_dragStart.dy < top + 110) {
      if (_dragStart.dx > size.width * 0.55) {
        openControlCenter(context);
        return;
      }
      if (_dragStart.dx < size.width * 0.45) {
        Native.expandNotifications();
        return;
      }
    }
    openSpotlight(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (s.editing) {
          s.setEditing(false);
        } else if (_page.round() != 1) {
          _goHomePage();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final n = s.pages.length;
            return Stack(
              children: [
                const Positioned.fill(child: WallpaperView()),
                // Blur the wallpaper on Today view & Library
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: pc,
                      builder: (_, __) {
                        final b = 1 - _homeFactor(n);
                        if (b < 0.01) return const SizedBox.shrink();
                        return BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30 * b, sigmaY: 30 * b),
                          child: Container(color: Colors.black.withValues(alpha: 0.25 * b)),
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      SizedBox(height: 44, child: s.editing ? _editBar() : null),
                      Expanded(
                        child: GestureDetector(
                          onVerticalDragStart: (d) {
                            _dragStart = d.globalPosition;
                            _dy = 0;
                            _fired = false;
                          },
                          onVerticalDragUpdate: (d) {
                            if (_fired || s.editing) return;
                            final p = _page.round();
                            if (p < 1 || p > n) return;
                            _dy += d.delta.dy;
                            if (_dy > 50) {
                              _fired = true;
                              _onSwipeDown();
                            } else if (_dy < -80) {
                              _fired = true;
                              pc.animateToPage(n + 1, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
                            }
                          },
                          child: PageView.builder(
                            controller: pc,
                            allowImplicitScrolling: true,
                            itemCount: n + 2,
                            itemBuilder: (context, i) {
                              if (i == 0) return const TodayView();
                              if (i == n + 1) return const AppLibraryPage();
                              return HomePageGrid(page: i - 1);
                            },
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: pc,
                        builder: (_, __) => Opacity(opacity: _homeFactor(n), child: _dots(n)),
                      ),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: pc,
                        builder: (_, child) {
                          final f = _homeFactor(n);
                          return Opacity(
                            opacity: f,
                            child: Transform.translate(offset: Offset(0, (1 - f) * 160), child: child),
                          );
                        },
                        child: const Dock(),
                      ),
                      SizedBox(height: bottom + 8),
                    ],
                  ),
                ),
                // Drag an icon to the screen edge to change page
                Positioned(left: 0, top: 0, bottom: 0, width: 26, child: _edge(-1, n)),
                Positioned(right: 0, top: 0, bottom: 0, width: 26, child: _edge(1, n)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _edge(int dir, int n) => ValueListenableBuilder<bool>(
        valueListenable: s.dragging,
        builder: (_, dragging, __) => dragging
            ? _EdgeZone(onFlip: () {
                final target = _page.round() + dir;
                if (target >= 1 && target <= n) {
                  pc.animateToPage(target, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
                }
              })
            : const SizedBox.shrink(),
      );

  Widget _dots(int n) {
    final current = (_page - 1).round();
    return GestureDetector(
      onTap: () => openSpotlight(context),
      child: Glass(
        radius: 20,
        alpha: 0.14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.search, size: 13, color: Colors.white70),
            const SizedBox(width: 6),
            if (n <= 1)
              const Text('Search', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500))
            else
              for (var i = 0; i < n; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 6.5,
                  height: 6.5,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i == current ? Colors.white : Colors.white38),
                ),
          ],
        ),
      ),
    );
  }

  Widget _editBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _pill('Settings', CupertinoIcons.gear_alt_fill, () => openSettings(context)),
            const Spacer(),
            _pill('Done', null, () => s.setEditing(false)),
          ],
        ),
      );

  Widget _pill(String text, IconData? icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: 18,
          alpha: 0.25,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 6)],
              Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      );
}

class _EdgeZone extends StatefulWidget {
  final VoidCallback onFlip;
  const _EdgeZone({required this.onFlip});

  @override
  State<_EdgeZone> createState() => _EdgeZoneState();
}

class _EdgeZoneState extends State<_EdgeZone> {
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<HomeItem>(
      onWillAcceptWithDetails: (_) => false,
      onMove: (_) {
        _t ??= Timer(const Duration(milliseconds: 550), () {
          _t = null;
          widget.onFlip();
        });
      },
      onLeave: (_) {
        _t?.cancel();
        _t = null;
      },
      builder: (_, __, ___) => const SizedBox.expand(),
    );
  }
}
