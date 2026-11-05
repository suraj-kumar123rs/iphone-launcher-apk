import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../native.dart';
import '../state.dart';
import '../weather.dart';
import 'common.dart';
import 'settings.dart';

const _red = Color(0xFFFF453A);
const _weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Two small widgets shown on top of the first home page.
class HomeWidgetsRow extends StatelessWidget {
  const HomeWidgetsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 18) / 2;
        final h = c.maxHeight;
        return Row(
          children: [
            WeatherWidget(width: w, height: h),
            const SizedBox(width: 18),
            CalendarSmall(width: w, height: h),
          ],
        );
      },
    );
  }
}

/// Ticks every [period] and rebuilds.
class PeriodicRebuild extends StatefulWidget {
  final Duration period;
  final WidgetBuilder builder;
  const PeriodicRebuild({super.key, required this.period, required this.builder});

  @override
  State<PeriodicRebuild> createState() => _PeriodicRebuildState();
}

class _PeriodicRebuildState extends State<PeriodicRebuild> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.period, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// ---------------- Weather ----------------

LinearGradient _skyGradient(bool day) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: day ? const [Color(0xFF2F80ED), Color(0xFF56A8F5)] : const [Color(0xFF0E1A3B), Color(0xFF2B3B6E)],
    );

class WeatherWidget extends StatelessWidget {
  final double width, height;
  final bool medium;
  const WeatherWidget({super.key, required this.width, required this.height, this.medium = false});

  @override
  Widget build(BuildContext context) {
    final w = Weather.i;
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        final now = w.now;
        if (w.city.isEmpty || now == null) {
          return WidgetCard(
            width: width,
            height: height,
            gradient: _skyGradient(true),
            onTap: () => openSettings(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weather', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                const Icon(CupertinoIcons.cloud_sun_fill, size: 34, color: Colors.white),
                const SizedBox(height: 6),
                Text(w.city.isEmpty ? 'Tap to set your city' : 'Loading…', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          );
        }
        final (icon, label) = weatherInfo(now.code, now.isDay);
        final top = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(w.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                const SizedBox(width: 4),
                const Icon(CupertinoIcons.location_fill, size: 11),
              ],
            ),
            Text('${now.temp.round()}°', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300, height: 1.05, letterSpacing: -1)),
          ],
        );
        final bottom = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('H:${now.hi.round()}°  L:${now.lo.round()}°', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        );
        return WidgetCard(
          width: width,
          height: height,
          gradient: _skyGradient(now.isDay),
          onTap: () => w.refresh(force: true),
          child: medium
              ? Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: top), bottom],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final d in now.days.skip(1).take(5))
                          Column(
                            children: [
                              Text(_shortDays[d.date.weekday - 1], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 4),
                              Icon(weatherInfo(d.code, true).$1, size: 18),
                              const SizedBox(height: 4),
                              Text('${d.hi.round()}°', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [top, const Spacer(), bottom],
                ),
        );
      },
    );
  }
}

// ---------------- Calendar ----------------

class CalendarSmall extends StatelessWidget {
  final double width, height;
  const CalendarSmall({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return PeriodicRebuild(
      period: const Duration(minutes: 1),
      builder: (context) {
        final now = DateTime.now();
        return WidgetCard(
          width: width,
          height: height,
          onTap: () => Native.openShortcut('calendar'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_weekdays[now.weekday - 1], style: const TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
              Text('${now.day}', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w300, height: 1.05)),
              const Spacer(),
              Text(_months[now.month - 1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Text('No events today', style: TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        );
      },
    );
  }
}

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final days = DateTime(now.year, now.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final cells = <int?>[...List<int?>.filled(lead, null), for (var d = 1; d <= days; d++) d];
    return WidgetCard(
      onTap: () => Native.openShortcut('calendar'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_months[now.month - 1].toUpperCase(), style: const TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)))),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r * 7 < cells.length; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(builder: (_) {
                      final i = r * 7 + c;
                      final d = i < cells.length ? cells[i] : null;
                      final today = d == now.day;
                      return Container(
                        height: 26,
                        margin: const EdgeInsets.all(1),
                        decoration: today ? const BoxDecoration(color: _red, shape: BoxShape.circle) : null,
                        alignment: Alignment.center,
                        child: Text(d == null ? '' : '$d', style: TextStyle(fontSize: 12.5, fontWeight: today ? FontWeight.w700 : FontWeight.w500)),
                      );
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------- Clock ----------------

class ClockWidget extends StatelessWidget {
  final double size;
  const ClockWidget({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return PeriodicRebuild(
      period: const Duration(seconds: 1),
      builder: (context) => WidgetCard(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        onTap: () => Native.openShortcut('alarm'),
        child: CustomPaint(painter: _ClockPainter(DateTime.now())),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime t;
  _ClockPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = min(size.width, size.height) / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.black);
    for (var i = 0; i < 60; i++) {
      final a = i * pi / 30;
      final major = i % 5 == 0;
      final p1 = c + Offset(sin(a), -cos(a)) * (r * 0.95);
      final p2 = c + Offset(sin(a), -cos(a)) * (r * (major ? 0.86 : 0.91));
      canvas.drawLine(p1, p2, Paint()
        ..color = major ? Colors.white70 : Colors.white24
        ..strokeWidth = major ? 1.6 : 0.8);
    }
    for (var h = 1; h <= 12; h++) {
      final a = h * pi / 6;
      final tp = TextPainter(
        text: TextSpan(text: '$h', style: TextStyle(color: Colors.white, fontSize: r * 0.2, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = c + Offset(sin(a), -cos(a)) * (r * 0.68);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    void hand(double angle, double len, double width, Color color) {
      final end = c + Offset(sin(angle), -cos(angle)) * len;
      canvas.drawLine(c, end, Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round);
    }

    final sec = t.second;
    final minute = t.minute + sec / 60;
    final hour = (t.hour % 12) + minute / 60;
    hand(hour * pi / 6, r * 0.45, 4, Colors.white);
    hand(minute * pi / 30, r * 0.7, 3, Colors.white);
    hand(sec * pi / 30, r * 0.8, 1.2, const Color(0xFFFF9F0A));
    canvas.drawCircle(c, 3.5, Paint()..color = const Color(0xFFFF9F0A));
    canvas.drawCircle(c, 1.5, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.t.second != t.second || old.t.minute != t.minute;
}

// ---------------- Battery ----------------

class BatteryWidget extends StatefulWidget {
  const BatteryWidget({super.key});

  @override
  State<BatteryWidget> createState() => _BatteryWidgetState();
}

class _BatteryWidgetState extends State<BatteryWidget> {
  int level = -1;
  bool charging = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  Future<void> _load() async {
    final b = await Native.battery();
    if (!mounted) return;
    setState(() {
      level = (b['level'] as num?)?.toInt() ?? -1;
      charging = b['charging'] == true;
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = level < 0 ? 0.0 : level / 100;
    final color = charging ? const Color(0xFF30D158) : (level >= 0 && level <= 20 ? _red : const Color(0xFF30D158));
    return WidgetCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: v, strokeWidth: 5, color: color, backgroundColor: Colors.white12),
                Icon(charging ? CupertinoIcons.bolt_fill : CupertinoIcons.device_phone_portrait, size: 22),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Text('This phone', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          Text(level < 0 ? '--' : '$level%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------- Suggestions ----------------

class SuggestionsWidget extends StatelessWidget {
  const SuggestionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    final icon = iconSizeFor(context);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final apps = s.suggestions(4);
        return Glass(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 10),
                child: Text('Suggestions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final a in apps)
                    GestureDetector(
                      onTap: () => s.launch(a.pkg),
                      child: SizedBox(
                        width: icon + 16,
                        child: Column(children: [AppIcon(app: a, size: icon), const SizedBox(height: 5), IconLabel(a.label)]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
