import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'native.dart';

/// Holds installed apps and the home screen layout (pages, dock, folders).
class Launcher extends ChangeNotifier {
  Launcher._();
  static final Launcher i = Launcher._();

  static const cols = 4;
  static const rows = 6;
  static const widgetRows = 2; // first page shows widgets on top
  static const dockMax = 4;

  late SharedPreferences _prefs;
  Map<String, AppInfo> apps = {};
  List<List<HomeItem>> pages = [[]];
  List<HomeItem> dock = [];
  Set<String> hidden = {}; // apps removed from home (still in library)
  Map<String, int> launchCount = {};
  Map<String, int> lastLaunch = {};
  bool editing = false;
  bool loaded = false;
  bool _hasLayout = false;
  bool _refreshing = false;
  final dragging = ValueNotifier<bool>(false);

  String? wallpaperPath;
  int wallpaperIndex = 0;
  bool showLabels = true;
  bool addNewToHome = true;

  int capacity(int page) => page == 0 ? cols * (rows - widgetRows) : cols * rows;

  // ---------------- Load / save ----------------

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    wallpaperPath = _prefs.getString('wp_path');
    if (wallpaperPath != null && !File(wallpaperPath!).existsSync()) wallpaperPath = null;
    wallpaperIndex = _prefs.getInt('wp_idx') ?? 0;
    showLabels = _prefs.getBool('labels') ?? true;
    addNewToHome = _prefs.getBool('add_new') ?? true;
    try {
      final raw = _prefs.getString('layout');
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        pages = (j['pages'] as List).map((p) => (p as List).map((e) => HomeItem.fromJson(e as Map)).toList()).toList();
        dock = (j['dock'] as List).map((e) => HomeItem.fromJson(e as Map)).toList();
        hidden = Set<String>.from((j['hidden'] as List?) ?? const []);
        if (pages.isEmpty) pages = [[]];
        _hasLayout = true;
      }
    } catch (_) {
      pages = [[]];
      dock = [];
    }
    try {
      final lc = _prefs.getString('launches');
      if (lc != null) {
        final j = jsonDecode(lc) as Map<String, dynamic>;
        launchCount = Map<String, int>.from(j['c'] as Map);
        lastLaunch = Map<String, int>.from(j['t'] as Map);
      }
    } catch (_) {}
    try {
      final cached = _prefs.getString('apps_cache');
      if (cached != null) {
        for (final m in jsonDecode(cached) as List) {
          final a = AppInfo.fromMap(m as Map);
          apps[a.pkg] = a;
        }
        loaded = apps.isNotEmpty && _hasLayout;
      }
    } catch (_) {}
  }

  void _save() {
    _prefs.setString(
      'layout',
      jsonEncode({
        'pages': pages.map((p) => p.map((e) => e.toJson()).toList()).toList(),
        'dock': dock.map((e) => e.toJson()).toList(),
        'hidden': hidden.toList(),
      }),
    );
  }

  void _commit() {
    _normalize();
    _save();
    notifyListeners();
  }

  /// Reads installed apps from Android and syncs the layout.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final list = await Native.getApps();
      if (list.isEmpty) return;
      final map = <String, AppInfo>{};
      for (final m in list) {
        final a = AppInfo.fromMap(m);
        map[a.pkg] = a;
      }
      apps = map;
      _prefs.setString('apps_cache', jsonEncode(map.values.map((a) => a.toMap()).toList()));
      if (!_hasLayout) {
        await _firstLayout();
      } else {
        _sync();
      }
      loaded = true;
      _commit();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _firstLayout() async {
    final defs = await Native.defaults();
    dock = defs.where(apps.containsKey).take(dockMax).map(HomeItem.app).toList();
    final inDock = dock.map((e) => e.pkg).toSet();
    final rest = apps.values.where((a) => !inDock.contains(a.pkg)).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    pages = [rest.map((a) => HomeItem.app(a.pkg)).toList()];
    hidden = {};
    _hasLayout = true;
  }

  void _sync() {
    bool ok(String p) => apps.containsKey(p);
    void clean(List<HomeItem> l) {
      l.removeWhere((it) => !it.isFolder && !ok(it.pkg!));
      for (final f in l.where((e) => e.isFolder)) {
        f.apps.removeWhere((p) => !ok(p));
      }
    }

    clean(dock);
    for (final p in pages) {
      clean(p);
    }
    hidden.removeWhere((p) => !ok(p));
    final placed = placedPackages();
    final fresh = apps.keys.where((p) => !placed.contains(p) && !hidden.contains(p)).toList()
      ..sort((a, b) => apps[a]!.label.toLowerCase().compareTo(apps[b]!.label.toLowerCase()));
    if (fresh.isEmpty) return;
    if (addNewToHome) {
      _lastContentPage().addAll(fresh.map(HomeItem.app));
    } else {
      hidden.addAll(fresh);
    }
  }

  Set<String> placedPackages() {
    final s = <String>{};
    for (final l in [dock, ...pages]) {
      for (final it in l) {
        if (it.isFolder) {
          s.addAll(it.apps);
        } else {
          s.add(it.pkg!);
        }
      }
    }
    return s;
  }

  List<HomeItem> _lastContentPage() {
    for (var p = pages.length - 1; p > 0; p--) {
      if (pages[p].isNotEmpty) return pages[p];
    }
    return pages.first;
  }

  void _dissolve(List<HomeItem> l) {
    for (var i = l.length - 1; i >= 0; i--) {
      final it = l[i];
      if (!it.isFolder) continue;
      if (it.apps.isEmpty) {
        l.removeAt(i);
      } else if (it.apps.length == 1) {
        l[i] = HomeItem.app(it.apps.first);
      }
    }
  }

  void _normalize() {
    if (pages.isEmpty) pages = [[]];
    _dissolve(dock);
    while (dock.length > dockMax) {
      pages.last.add(dock.removeLast());
    }
    for (var p = 0; p < pages.length; p++) {
      _dissolve(pages[p]);
      final cap = capacity(p);
      while (pages[p].length > cap) {
        final extra = pages[p].removeLast();
        if (p + 1 >= pages.length) pages.add([]);
        pages[p + 1].insert(0, extra);
      }
    }
    final keep = <List<HomeItem>>[];
    for (var p = 0; p < pages.length; p++) {
      if (p == 0 || pages[p].isNotEmpty) keep.add(pages[p]);
    }
    if (editing && keep.last.isNotEmpty) keep.add([]); // room to drop on a new page
    pages = keep;
  }

  // ---------------- Layout editing ----------------

  (int, int)? locate(HomeItem it) {
    final d = dock.indexWhere((e) => e.id == it.id);
    if (d >= 0) return (-1, d);
    for (var p = 0; p < pages.length; p++) {
      final i = pages[p].indexWhere((e) => e.id == it.id);
      if (i >= 0) return (p, i);
    }
    return null;
  }

  List<HomeItem> listOf(int c) => c < 0 ? dock : pages[c];

  bool canDropInDock(HomeItem it) => dock.length < dockMax || dock.any((e) => e.id == it.id);

  void setEditing(bool v) {
    if (editing == v) return;
    editing = v;
    if (!v) dragging.value = false;
    _commit();
  }

  /// Moves [it] to container [toC] (-1 = dock) at index [toI].
  bool moveTo(HomeItem it, int toC, int toI) {
    dragging.value = false;
    final from = locate(it);
    if (from == null) return false;
    if (toC < 0 && from.$1 >= 0 && dock.length >= dockMax) return false;
    listOf(from.$1).removeAt(from.$2);
    if (from.$1 == toC && from.$2 < toI) toI--;
    while (toC >= pages.length) {
      pages.add([]);
    }
    final dst = listOf(toC);
    dst.insert(toI.clamp(0, dst.length), it);
    _commit();
    return true;
  }

  /// Drops [dragged] onto [target]: makes a folder or adds to one.
  HomeItem? merge(HomeItem dragged, HomeItem target) {
    dragging.value = false;
    if (dragged.isFolder || dragged.id == target.id) return null;
    final from = locate(dragged);
    if (from == null || locate(target) == null) return null;
    listOf(from.$1).removeAt(from.$2);
    final to = locate(target)!;
    HomeItem result;
    if (target.isFolder) {
      target.apps.add(dragged.pkg!);
      result = target;
    } else {
      result = HomeItem.folder(folderNameFor(target.pkg!), [target.pkg!, dragged.pkg!]);
      listOf(to.$1)[to.$2] = result;
    }
    _commit();
    return result;
  }

  String folderNameFor(String pkg) {
    final a = apps[pkg];
    if (a == null) return 'Folder';
    final c = categoryOf(a);
    return c == 'Other' ? 'Folder' : c;
  }

  void removeFromHome(HomeItem it) {
    final loc = locate(it);
    if (loc == null) return;
    listOf(loc.$1).removeAt(loc.$2);
    hidden.addAll(it.isFolder ? it.apps : [it.pkg!]);
    _commit();
  }

  void removeFromFolder(HomeItem folder, String pkg) {
    folder.apps.remove(pkg);
    _lastContentPage().add(HomeItem.app(pkg));
    _commit();
  }

  void renameFolder(HomeItem folder, String name) {
    if (name.trim().isEmpty) return;
    folder.name = name.trim();
    _commit();
  }

  bool isOnHome(String pkg) => placedPackages().contains(pkg);

  void addToHome(String pkg) {
    hidden.remove(pkg);
    if (!isOnHome(pkg)) _lastContentPage().add(HomeItem.app(pkg));
    _commit();
  }

  Future<void> resetLayout() async {
    _hasLayout = false;
    editing = false;
    await refresh();
  }

  // ---------------- Launching & suggestions ----------------

  Future<void> launch(String pkg, [Rect? from]) async {
    final ok = await Native.launch(pkg, from);
    if (!ok) return;
    launchCount[pkg] = (launchCount[pkg] ?? 0) + 1;
    lastLaunch[pkg] = DateTime.now().millisecondsSinceEpoch;
    _prefs.setString('launches', jsonEncode({'c': launchCount, 't': lastLaunch}));
  }

  List<AppInfo> suggestions(int n) {
    final now = DateTime.now().millisecondsSinceEpoch;
    double score(String p) {
      final c = launchCount[p] ?? 0;
      final t = lastLaunch[p] ?? 0;
      if (t == 0) return c.toDouble();
      final hours = (now - t) / 3600000;
      return c + 20 / (1 + hours);
    }

    final list = apps.values.where((a) => (launchCount[a.pkg] ?? 0) > 0).toList()
      ..sort((a, b) => score(b.pkg).compareTo(score(a.pkg)));
    if (list.length < n) {
      for (final d in dock) {
        final a = d.pkg == null ? null : apps[d.pkg];
        if (a != null && !list.contains(a)) list.add(a);
      }
    }
    if (list.length < n) {
      for (final a in apps.values) {
        if (list.length >= n) break;
        if (!list.contains(a)) list.add(a);
      }
    }
    return list.take(n).toList();
  }

  List<LibraryGroup> libraryGroups() {
    final all = apps.values.toList();
    int byUse(AppInfo a, AppInfo b) {
      final c = (launchCount[b.pkg] ?? 0).compareTo(launchCount[a.pkg] ?? 0);
      return c != 0 ? c : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    }

    final groups = <String, List<AppInfo>>{};
    for (final a in all) {
      groups.putIfAbsent(categoryOf(a), () => []).add(a);
    }
    for (final g in groups.values) {
      g.sort(byUse);
    }
    final sorted = groups.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    final recent = List.of(all)..sort((a, b) => b.installed.compareTo(a.installed));
    return [
      LibraryGroup('Suggestions', suggestions(8)),
      LibraryGroup('Recently Added', recent.take(8).toList()),
      for (final e in sorted) LibraryGroup(e.key, e.value),
    ];
  }

  List<AppInfo> sortedApps() =>
      apps.values.toList()..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  // ---------------- Settings ----------------

  void setWallpaperIndex(int i) {
    wallpaperIndex = i;
    wallpaperPath = null;
    _prefs.setInt('wp_idx', i);
    _prefs.remove('wp_path');
    notifyListeners();
  }

  void setWallpaperPath(String p) {
    wallpaperPath = p;
    _prefs.setString('wp_path', p);
    notifyListeners();
  }

  void setShowLabels(bool v) {
    showLabels = v;
    _prefs.setBool('labels', v);
    notifyListeners();
  }

  void setAddNew(bool v) {
    addNewToHome = v;
    _prefs.setBool('add_new', v);
    notifyListeners();
  }
}
