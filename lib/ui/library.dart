import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import 'common.dart';
import 'folder.dart';
import 'grid.dart';

/// Last page: every app grouped into categories.
class AppLibraryPage extends StatelessWidget {
  const AppLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final groups = s.libraryGroups().where((g) => g.apps.isNotEmpty).toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                child: GestureDetector(
                  onTap: () => openLibraryList(context),
                  child: Glass(
                    radius: 14,
                    alpha: 0.16,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.search, size: 18, color: Colors.white70),
                        SizedBox(width: 8),
                        Text('Library', style: TextStyle(fontSize: 16, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 22,
                  childAspectRatio: 0.84,
                ),
                itemCount: groups.length,
                itemBuilder: (context, i) => _GroupCard(group: groups[i]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final LibraryGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final apps = group.apps;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final side = c.maxWidth;
              const pad = 12.0;
              const gap = 12.0;
              final big = (side - pad * 2 - gap) / 2;
              final showMini = apps.length > 4;
              Widget slot(int i) {
                if (i == 3 && showMini) return _MiniGrid(apps: apps.skip(3).take(4).toList(), size: big, onTap: () => openGroup(context, group));
                if (i >= apps.length) return SizedBox(width: big, height: big);
                return _LibIcon(app: apps[i], size: big);
              }

              return Align(
                alignment: Alignment.topCenter,
                child: Glass(
                  radius: 26,
                  alpha: 0.14,
                  width: side,
                  height: side,
                  padding: const EdgeInsets.all(pad),
                  child: Column(
                    children: [
                      Row(children: [slot(0), const SizedBox(width: gap), slot(1)]),
                      const SizedBox(height: gap),
                      Row(children: [slot(2), const SizedBox(width: gap), slot(3)]),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _LibIcon extends StatefulWidget {
  final AppInfo app;
  final double size;
  const _LibIcon({required this.app, required this.size});

  @override
  State<_LibIcon> createState() => _LibIconState();
}

class _LibIconState extends State<_LibIcon> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final b = _key.currentContext?.findRenderObject() as RenderBox?;
        Launcher.i.launch(widget.app.pkg, b == null ? null : b.localToGlobal(Offset.zero) & b.size);
      },
      onLongPress: () => showAppSheet(context, widget.app),
      child: KeyedSubtree(key: _key, child: AppIcon(app: widget.app, size: widget.size)),
    );
  }
}

class _MiniGrid extends StatelessWidget {
  final List<AppInfo> apps;
  final double size;
  final VoidCallback onTap;
  const _MiniGrid({required this.apps, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gap = size * 0.08;
    final mini = ((size - gap) / 2).floorToDouble();
    Widget at(int i) => i < apps.length ? AppIcon(app: apps[i], size: mini) : SizedBox(width: mini, height: mini);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Column(
          children: [
            Row(children: [at(0), SizedBox(width: gap), at(1)]),
            SizedBox(height: gap),
            Row(children: [at(2), SizedBox(width: gap), at(3)]),
          ],
        ),
      ),
    );
  }
}

// ---------------- Alphabetical list ----------------

void openLibraryList(BuildContext context) {
  pushOverlay<void>(context, (ctx, anim) => _LibraryList(anim: anim));
}

class _LibraryList extends StatefulWidget {
  final Animation<double> anim;
  const _LibraryList({required this.anim});

  @override
  State<_LibraryList> createState() => _LibraryListState();
}

class _LibraryListState extends State<_LibraryList> {
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

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    final q = _q.toLowerCase();
    final apps = s.sortedApps().where((a) => q.isEmpty || a.label.toLowerCase().contains(q)).toList();
    final rows = <Object>[];
    String? letter;
    for (final a in apps) {
      final l = a.label.isEmpty ? '#' : a.label[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(l) ? l : '#';
      if (key != letter) {
        letter = key;
        rows.add(key);
      }
      rows.add(a);
    }
    return Stack(
      children: [
        Positioned.fill(child: BlurBackdrop(anim: widget.anim, sigma: 40, dim: 0.55)),
        SafeArea(
          child: FadeTransition(
            opacity: widget.anim,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          placeholder: 'Library',
                          style: const TextStyle(color: Colors.white),
                          onChanged: (v) => setState(() => _q = v),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      if (r is String) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 0, 4),
                          child: Text(r, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white54)),
                        );
                      }
                      final a = r as AppInfo;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          s.launch(a.pkg);
                          Navigator.of(context).pop();
                        },
                        onLongPress: () => showAppSheet(context, a),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              AppIcon(app: a, size: 40),
                              const SizedBox(width: 14),
                              Expanded(child: Text(a.label, style: const TextStyle(fontSize: 16))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
