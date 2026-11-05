import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'home_widgets.dart';
import 'settings.dart';
import 'spotlight.dart';

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Widgets page, left of the first home page.
class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 32;
    final small = (w - 16) / 2;
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      children: [
        GestureDetector(
          onTap: () => openSpotlight(context),
          child: Glass(
            radius: 14,
            alpha: 0.16,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(
              children: [
                Icon(CupertinoIcons.search, size: 18, color: Colors.white70),
                SizedBox(width: 8),
                Text('Search', style: TextStyle(fontSize: 16, color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text(
            '${_weekdayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          ),
        ),
        WeatherWidget(width: w, height: 176, medium: true),
        const SizedBox(height: 16),
        Row(
          children: [
            CalendarSmall(width: small, height: small),
            const SizedBox(width: 16),
            ClockWidget(size: small),
          ],
        ),
        const SizedBox(height: 16),
        const BatteryWidget(),
        const SizedBox(height: 16),
        const SuggestionsWidget(),
        const SizedBox(height: 16),
        const MonthCalendar(),
        const SizedBox(height: 20),
        Center(
          child: CupertinoButton(
            onPressed: () => openSettings(context),
            child: const Text('Launcher Settings', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
