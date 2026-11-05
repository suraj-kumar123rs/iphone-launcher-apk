import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../native.dart';
import '../state.dart';
import 'common.dart';
import 'grid.dart';

void openSpotlight(BuildContext context) {
  pushOverlay<void>(context, (ctx, anim) => SearchView(anim: anim));
}

/// Swipe-down search: apps, quick maths, web and Play Store.
class SearchView extends StatefulWidget {
  final Animation<double> anim;
  const SearchView({super.key, required this.anim});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  List<AppInfo> _matches() {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return [];
    final s = Launcher.i;
    final list = s.apps.values.where((a) => a.label.toLowerCase().contains(q) || a.pkg.toLowerCase().contains(q)).toList();
    int rank(AppInfo a) {
      final l = a.label.toLowerCase();
      if (l.startsWith(q)) return 0;
      if (l.split(' ').any((w) => w.startsWith(q))) return 1;
      return 2;
    }

    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return (s.launchCount[b.pkg] ?? 0).compareTo(s.launchCount[a.pkg] ?? 0);
    });
    return list.take(12).toList();
  }

  void _launch(AppInfo a) {
    Launcher.i.launch(a.pkg);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    final q = _q.trim();
    final matches = _matches();
    final calc = tryCalc(q);
    final icon = iconSizeFor(context);
    final slide = Tween(begin: const Offset(0, -0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: widget.anim, curve: Curves.easeOutCubic));

    return Stack(
      children: [
        Positioned.fill(child: BlurBackdrop(anim: widget.anim, sigma: 34, dim: 0.4, onTap: _close)),
        SafeArea(
          child: FadeTransition(
            opacity: widget.anim,
            child: SlideTransition(
              position: slide,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoSearchTextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            placeholder: 'Search',
                            style: const TextStyle(color: Colors.white, fontSize: 17),
                            onChanged: (v) => setState(() => _q = v),
                            onSubmitted: (_) {
                              if (matches.isNotEmpty) {
                                _launch(matches.first);
                              } else if (q.isNotEmpty) {
                                Native.webSearch(q);
                                _close();
                              }
                            },
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: _close,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _close,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          if (q.isEmpty) ...[
                            _header('Suggestions'),
                            Glass(
                              radius: 22,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  for (final a in s.suggestions(4))
                                    GestureDetector(
                                      onTap: () => _launch(a),
                                      child: SizedBox(
                                        width: icon + 16,
                                        child: Column(children: [AppIcon(app: a, size: icon), const SizedBox(height: 5), IconLabel(a.label)]),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (calc != null) ...[
                            _header('Calculator'),
                            Glass(
                              radius: 18,
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.plus_slash_minus, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text('= ${formatNumber(calc)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (matches.isNotEmpty) ...[
                            _header('Top Hits'),
                            Glass(
                              radius: 18,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                children: [
                                  for (final a in matches)
                                    InkWell(
                                      onTap: () => _launch(a),
                                      onLongPress: () => showAppSheet(context, a),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Row(
                                          children: [
                                            AppIcon(app: a, size: 40),
                                            const SizedBox(width: 12),
                                            Expanded(child: Text(a.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                                            Text(categoryOf(a), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (q.isNotEmpty) ...[
                            _header('More'),
                            Glass(
                              radius: 18,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  _action(CupertinoIcons.globe, 'Search the web for “$q”', () {
                                    Native.webSearch(q);
                                    _close();
                                  }),
                                  _action(CupertinoIcons.bag_fill, 'Search Play Store for “$q”', () {
                                    Native.openUrl('market://search?q=${Uri.encodeComponent(q)}');
                                    _close();
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
      );

  Widget _action(IconData icon, String text, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: CupertinoColors.systemBlue),
              const SizedBox(width: 14),
              Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15))),
            ],
          ),
        ),
      );
}

// ---------------- Tiny calculator ----------------

double? tryCalc(String input) {
  final s = input.replaceAll(' ', '').replaceAll('×', '*').replaceAll('÷', '/');
  if (s.isEmpty) return null;
  if (!RegExp(r'^[0-9+\-*/().%]+$').hasMatch(s)) return null;
  if (!RegExp(r'\d[+\-*/%]').hasMatch(s) && !RegExp(r'\)[+\-*/%]').hasMatch(s)) return null;
  final p = _Parser(s);
  try {
    final v = p.expr();
    if (p.i != s.length || v.isNaN || v.isInfinite) return null;
    return v;
  } catch (_) {
    return null;
  }
}

String formatNumber(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  var t = v.toStringAsFixed(6);
  t = t.replaceAll(RegExp(r'0+$'), '');
  return t.endsWith('.') ? t.substring(0, t.length - 1) : t;
}

class _Parser {
  final String s;
  int i = 0;
  _Parser(this.s);

  bool _at(String c) => i < s.length && s[i] == c;

  double expr() {
    var v = term();
    while (_at('+') || _at('-')) {
      final op = s[i++];
      final r = term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double term() {
    var v = factor();
    while (_at('*') || _at('/') || _at('%')) {
      final op = s[i++];
      final r = factor();
      v = op == '*' ? v * r : (op == '/' ? v / r : v % r);
    }
    return v;
  }

  double factor() {
    if (_at('-')) {
      i++;
      return -factor();
    }
    if (_at('+')) {
      i++;
      return factor();
    }
    if (_at('(')) {
      i++;
      final v = expr();
      if (!_at(')')) throw const FormatException('missing )');
      i++;
      return v;
    }
    final start = i;
    while (i < s.length && '0123456789.'.contains(s[i])) {
      i++;
    }
    if (start == i) throw const FormatException('number expected');
    return double.parse(s.substring(start, i));
  }
}
