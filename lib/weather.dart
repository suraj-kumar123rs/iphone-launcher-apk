import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherDay {
  final DateTime date;
  final int code;
  final double hi, lo;
  const WeatherDay(this.date, this.code, this.hi, this.lo);
}

class WeatherNow {
  final double temp;
  final int code;
  final bool isDay;
  final List<WeatherDay> days;
  const WeatherNow(this.temp, this.code, this.isDay, this.days);
  double get hi => days.isEmpty ? temp : days.first.hi;
  double get lo => days.isEmpty ? temp : days.first.lo;
}

/// Free weather from Open-Meteo (no API key needed).
class Weather extends ChangeNotifier {
  Weather._();
  static final Weather i = Weather._();

  late SharedPreferences _p;
  String city = '';
  double? lat, lon;
  WeatherNow? now;
  DateTime? updated;
  bool loading = false;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    city = _p.getString('w_city') ?? '';
    lat = _p.getDouble('w_lat');
    lon = _p.getDouble('w_lon');
    final cached = _p.getString('w_cache');
    if (cached != null) {
      try {
        now = _parse(jsonDecode(cached) as Map<String, dynamic>);
        updated = DateTime.fromMillisecondsSinceEpoch(_p.getInt('w_time') ?? 0);
      } catch (_) {}
    }
  }

  /// Looks up [name] and saves it. Returns an error message, or null on success.
  Future<String?> setCity(String name) async {
    name = name.trim();
    if (name.isEmpty) return 'Enter a city name';
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': name, 'count': '1', 'language': 'en', 'format': 'json'});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final results = j['results'] as List?;
      if (results == null || results.isEmpty) return 'City not found';
      final r = results.first as Map<String, dynamic>;
      city = '${r['name']}';
      lat = (r['latitude'] as num).toDouble();
      lon = (r['longitude'] as num).toDouble();
      await _p.setString('w_city', city);
      await _p.setDouble('w_lat', lat!);
      await _p.setDouble('w_lon', lon!);
      notifyListeners();
      await refresh(force: true);
      return null;
    } catch (_) {
      return 'No internet connection';
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (lat == null || lon == null || loading) return;
    if (!force && updated != null && DateTime.now().difference(updated!) < const Duration(minutes: 30)) return;
    loading = true;
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lon',
        'current': 'temperature_2m,weather_code,is_day',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': '6',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        now = _parse(j);
        updated = DateTime.now();
        await _p.setString('w_cache', res.body);
        await _p.setInt('w_time', updated!.millisecondsSinceEpoch);
      }
    } catch (_) {
      // keep showing the last cached weather
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  WeatherNow _parse(Map<String, dynamic> j) {
    final c = j['current'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;
    final times = (d['time'] as List).cast<Object?>();
    final codes = (d['weather_code'] as List).cast<Object?>();
    final his = (d['temperature_2m_max'] as List).cast<Object?>();
    final los = (d['temperature_2m_min'] as List).cast<Object?>();
    final days = <WeatherDay>[];
    for (var k = 0; k < times.length; k++) {
      days.add(WeatherDay(
        DateTime.tryParse('${times[k]}') ?? DateTime.now(),
        (codes[k] as num?)?.toInt() ?? 0,
        (his[k] as num?)?.toDouble() ?? 0,
        (los[k] as num?)?.toDouble() ?? 0,
      ));
    }
    return WeatherNow(
      (c['temperature_2m'] as num).toDouble(),
      (c['weather_code'] as num).toInt(),
      (c['is_day'] as num?)?.toInt() != 0,
      days,
    );
  }
}

(IconData, String) weatherInfo(int code, bool day) {
  if (code == 0) return (day ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill, day ? 'Sunny' : 'Clear');
  if (code <= 2) return (day ? CupertinoIcons.cloud_sun_fill : CupertinoIcons.cloud_moon_fill, 'Partly Cloudy');
  if (code == 3) return (CupertinoIcons.cloud_fill, 'Cloudy');
  if (code == 45 || code == 48) return (CupertinoIcons.cloud_fog_fill, 'Fog');
  if (code >= 51 && code <= 57) return (CupertinoIcons.cloud_drizzle_fill, 'Drizzle');
  if (code >= 61 && code <= 67) return (CupertinoIcons.cloud_rain_fill, 'Rain');
  if (code >= 71 && code <= 77) return (CupertinoIcons.cloud_snow_fill, 'Snow');
  if (code >= 80 && code <= 82) return (CupertinoIcons.cloud_heavyrain_fill, 'Showers');
  if (code >= 95) return (CupertinoIcons.cloud_bolt_rain_fill, 'Thunderstorm');
  return (CupertinoIcons.cloud_fill, 'Cloudy');
}
