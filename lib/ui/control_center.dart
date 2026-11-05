import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../native.dart';
import '../state.dart';
import 'common.dart';

void openControlCenter(BuildContext context) {
  HapticFeedback.lightImpact();
  pushOverlay<void>(context, (ctx, anim) => ControlCenter(anim: anim));
}

/// Quick controls panel (swipe down from the top-right).
class ControlCenter extends StatefulWidget {
  final Animation<double> anim;
  const ControlCenter({super.key, required this.anim});

  @override
  State<ControlCenter> createState() => _ControlCenterState();
}

class _ControlCenterState extends State<ControlCenter> with WidgetsBindingObserver {
  bool wifi = false, bt = false, airplane = false, cellular = false, torch = false, music = false, canWrite = false;
  double bright = 0.5, volume = 0.5;
  bool _sliding = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_sliding) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final st = await Native.status();
    if (!mounted || st.isEmpty) return;
    setState(() {
      wifi = st['wifi'] == true;
      bt = st['bluetooth'] == true;
      airplane = st['airplane'] == true;
      cellular = st['cellular'] == true;
      torch = st['torch'] == true;
      music = st['music'] == true;
      canWrite = st['canWrite'] == true;
      if (!_sliding) {
        bright = (st['brightness'] as num?)?.toDouble() ?? bright;
        volume = (st['volume'] as num?)?.toDouble() ?? volume;
      }
    });
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 48;
    const gap = 14.0;
    final unit = (w - gap * 3) / 4;
    final block = unit * 2 + gap;
    final curved = CurvedAnimation(parent: widget.anim, curve: Curves.easeOutCubic);

    return Stack(
      children: [
        Positioned.fill(child: BlurBackdrop(anim: widget.anim, sigma: 40, dim: 0.45, onTap: _close)),
        SafeArea(
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -200) _close();
            },
            child: FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -0.06), end: Offset.zero).animate(curved),
                child: ScaleTransition(
                  scale: Tween(begin: 0.96, end: 1.0).animate(curved),
                  alignment: Alignment.topRight,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _connectivity(block),
                            const SizedBox(width: gap),
                            _media(block),
                          ],
                        ),
                        const SizedBox(height: gap),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: block,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _tile(unit, CupertinoIcons.lock_rotation, onTap: () => Native.openPanel('display')),
                                      const SizedBox(width: gap),
                                      _tile(unit, CupertinoIcons.rectangle_on_rectangle, onTap: () => Native.openPanel('cast')),
                                    ],
                                  ),
                                  const SizedBox(height: gap),
                                  _wideTile(block, unit, CupertinoIcons.moon_fill, 'Focus', () => Native.openPanel('dnd')),
                                ],
                              ),
                            ),
                            const SizedBox(width: gap),
                            _VSlider(
                              width: unit,
                              height: block,
                              value: bright,
                              icon: CupertinoIcons.sun_max_fill,
                              onStart: () {
                                _sliding = true;
                                if (!canWrite) Native.requestWrite();
                              },
                              onEnd: () => _sliding = false,
                              onChanged: (v) {
                                setState(() => bright = v);
                                if (canWrite) Native.setBrightness(v);
                              },
                            ),
                            const SizedBox(width: gap),
                            _VSlider(
                              width: unit,
                              height: block,
                              value: volume,
                              icon: CupertinoIcons.speaker_2_fill,
                              onStart: () => _sliding = true,
                              onEnd: () => _sliding = false,
                              onChanged: (v) {
                                setState(() => volume = v);
                                Native.setVolume(v);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: gap),
                        Row(
                          children: [
                            _tile(unit, torch ? CupertinoIcons.lightbulb_fill : CupertinoIcons.lightbulb, active: torch, onTap: () async {
                              HapticFeedback.selectionClick();
                              final r = await Native.setTorch(!torch);
                              if (mounted) setState(() => torch = r);
                            }),
                            const SizedBox(width: gap),
                            _tile(unit, CupertinoIcons.timer, onTap: () => _shortcut('timer', 'clock')),
                            const SizedBox(width: gap),
                            _tile(unit, CupertinoIcons.plus_slash_minus, onTap: () => _shortcut('calculator', 'calculator')),
                            const SizedBox(width: gap),
                            _tile(unit, CupertinoIcons.camera_fill, onTap: () => _shortcut('camera', 'camera')),
                          ],
                        ),
                        const SizedBox(height: gap),
                        Row(
                          children: [
                            _tile(unit, CupertinoIcons.alarm_fill, onTap: () => _shortcut('alarm', 'clock')),
                            const SizedBox(width: gap),
                            _tile(unit, CupertinoIcons.location_fill, onTap: () => Native.openPanel('location')),
                            const SizedBox(width: gap),
                            _tile(unit, CupertinoIcons.device_phone_portrait, onTap: () => Native.openPanel('display')),
                            const SizedBox(width: gap),
                            _tile(unit, CupertinoIcons.gear_alt_fill, onTap: () => _shortcut('settings', 'settings')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens a system shortcut, falling back to an installed app whose name matches.
  Future<void> _shortcut(String kind, String keyword) async {
    final ok = await Native.openShortcut(kind);
    if (!ok) {
      final s = Launcher.i;
      for (final a in s.apps.values) {
        if (a.label.toLowerCase().contains(keyword)) {
          s.launch(a.pkg);
          break;
        }
      }
    }
  }

  Widget _box(double w, double h, Widget child, {Color? color, VoidCallback? onTap, double radius = 26}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: w,
        height: h,
        decoration: ShapeDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.13),
          shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(radius * 2)),
        ),
        child: child,
      ),
    );
  }

  Widget _tile(double unit, IconData icon, {bool active = false, VoidCallback? onTap}) {
    return _box(
      unit,
      unit,
      Icon(icon, size: unit * 0.38, color: active ? Colors.black : Colors.white),
      color: active ? Colors.white : null,
      onTap: onTap,
      radius: 22,
    );
  }

  Widget _wideTile(double w, double unit, IconData icon, String label, VoidCallback onTap) {
    return _box(
      w,
      unit,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: unit * 0.56,
              height: unit * 0.56,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(icon, size: unit * 0.28, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _connectivity(double size) {
    final d = size * 0.3;
    Widget circle(IconData icon, bool on, Color color, String kind) => GestureDetector(
          onTap: () => Native.openPanel(kind),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: d,
            height: d,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? color : Colors.white.withValues(alpha: 0.18)),
            child: Icon(icon, size: d * 0.48, color: Colors.white),
          ),
        );
    return _box(
      size,
      size,
      Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                circle(CupertinoIcons.airplane, airplane, const Color(0xFFFF9F0A), 'airplane'),
                circle(CupertinoIcons.antenna_radiowaves_left_right, cellular, const Color(0xFF30D158), 'internet'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                circle(CupertinoIcons.wifi, wifi, const Color(0xFF0A84FF), 'wifi'),
                circle(CupertinoIcons.bluetooth, bt, const Color(0xFF0A84FF), 'bluetooth'),
              ],
            ),
          ],
        ),
      ),
      radius: 30,
    );
  }

  Widget _media(double size) {
    Future<void> key(String k) async {
      HapticFeedback.selectionClick();
      await Native.mediaKey(k);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _load();
    }

    return _box(
      size,
      size,
      Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(music ? 'Playing' : 'Not Playing', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(music ? 'Media' : 'Tap play to resume', style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(onTap: () => key('prev'), child: const Icon(CupertinoIcons.backward_fill, size: 24)),
                GestureDetector(
                  onTap: () => key('play_pause'),
                  child: Icon(music ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 30),
                ),
                GestureDetector(onTap: () => key('next'), child: const Icon(CupertinoIcons.forward_fill, size: 24)),
              ],
            ),
          ],
        ),
      ),
      radius: 30,
    );
  }
}

/// Tall fill slider like brightness / volume.
class _VSlider extends StatelessWidget {
  final double width, height, value;
  final IconData icon;
  final ValueChanged<double> onChanged;
  final VoidCallback onStart, onEnd;

  const _VSlider({
    required this.width,
    required this.height,
    required this.value,
    required this.icon,
    required this.onChanged,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return GestureDetector(
      onVerticalDragStart: (_) => onStart(),
      onVerticalDragUpdate: (d) => onChanged((v - d.delta.dy / height).clamp(0.0, 1.0)),
      onVerticalDragEnd: (_) => onEnd(),
      onTapUp: (d) {
        onStart();
        onChanged((1 - d.localPosition.dy / height).clamp(0.0, 1.0));
        onEnd();
      },
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(56))),
        child: Container(
          width: width,
          height: height,
          color: Colors.white.withValues(alpha: 0.16),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(height: height * v, color: Colors.white),
              Positioned(
                bottom: 16,
                child: Icon(icon, size: width * 0.34, color: v > 0.18 ? Colors.black54 : Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
