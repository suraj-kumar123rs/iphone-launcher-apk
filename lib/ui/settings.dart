import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../native.dart';
import '../state.dart';
import '../weather.dart';
import 'wallpaper.dart';

void openSettings(BuildContext context) {
  Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const SettingsPage()));
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  final _city = TextEditingController(text: Weather.i.city);
  bool _isDefault = false;
  String? _cityMsg;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDefault();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _city.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkDefault();
  }

  Future<void> _checkDefault() async {
    final d = await Native.isDefault();
    if (mounted) setState(() => _isDefault = d);
  }

  Future<void> _saveCity() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _cityMsg = null;
    });
    final err = await Weather.i.setCity(_city.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _cityMsg = err ?? 'Saved: ${Weather.i.city}';
      if (err == null) _city.text = Weather.i.city;
    });
  }

  Future<void> _pickPhoto() async {
    final p = await Native.pickWallpaper();
    if (p != null) Launcher.i.setWallpaperPath(p);
  }

  Future<void> _reset() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reset Home Screen?'),
        content: const Text('All folders and arrangements will be removed. Your apps stay installed.'),
        actions: [
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ],
      ),
    );
    if (ok == true) await Launcher.i.resetLayout();
  }

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Launcher Settings'),
        previousPageTitle: 'Home',
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('DEFAULT HOME APP'),
                  footer: const Text('Make Lumen open when you press the Home button.'),
                  children: [
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.house_fill, color: CupertinoColors.systemBlue),
                      title: const Text('Set as Default Home App'),
                      trailing: _isDefault
                          ? const Icon(CupertinoIcons.checkmark_alt, color: CupertinoColors.systemGreen)
                          : const CupertinoListTileChevron(),
                      onTap: Native.homeSettings,
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('WALLPAPER'),
                  children: [
                    SizedBox(
                      height: 168,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(12),
                        itemCount: wallpapers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final selected = s.wallpaperPath == null && s.wallpaperIndex == i;
                          return GestureDetector(
                            onTap: () => s.setWallpaperIndex(i),
                            child: Column(
                              children: [
                                Container(
                                  width: 66,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: selected ? CupertinoColors.systemBlue : Colors.white12, width: selected ? 2.5 : 1),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CustomPaint(painter: WallpaperPainter(wallpapers[i])),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(wallpapers[i].name, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.photo_fill, color: CupertinoColors.systemPink),
                      title: const Text('Choose from Photos'),
                      trailing: s.wallpaperPath != null
                          ? const Icon(CupertinoIcons.checkmark_alt, color: CupertinoColors.systemGreen)
                          : const CupertinoListTileChevron(),
                      onTap: _pickPhoto,
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('WEATHER'),
                  footer: const Text('Weather data from Open-Meteo. No location permission needed.'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              controller: _city,
                              placeholder: 'Your city (e.g. Gaya)',
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: (_) => _saveCity(),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: _saving ? null : _saveCity,
                            child: _saving ? const CupertinoActivityIndicator() : const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                    if (_cityMsg != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(_cityMsg!, style: const TextStyle(fontSize: 13, color: Colors.white60)),
                      ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('HOME SCREEN'),
                  children: [
                    CupertinoListTile(
                      title: const Text('Show App Names'),
                      trailing: CupertinoSwitch(value: s.showLabels, onChanged: s.setShowLabels),
                    ),
                    CupertinoListTile(
                      title: const Text('Add New Apps to Home Screen'),
                      trailing: CupertinoSwitch(value: s.addNewToHome, onChanged: s.setAddNew),
                    ),
                    CupertinoListTile(
                      title: const Text('Reset Home Screen Layout', style: TextStyle(color: CupertinoColors.systemRed)),
                      onTap: _reset,
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('GESTURES'),
                  children: const [
                    _Hint(CupertinoIcons.search, 'Swipe down', 'Search'),
                    _Hint(CupertinoIcons.slider_horizontal_3, 'Swipe down from top-right', 'Controls'),
                    _Hint(CupertinoIcons.bell_fill, 'Swipe down from top-left', 'Notifications'),
                    _Hint(CupertinoIcons.square_grid_2x2_fill, 'Swipe up / swipe to last page', 'Library'),
                    _Hint(CupertinoIcons.pencil, 'Long-press empty space', 'Edit Home Screen'),
                    _Hint(CupertinoIcons.folder_fill, 'Drag an app onto another', 'Make a folder'),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Lumen 1.0', style: TextStyle(color: Colors.white38))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String gesture;
  final String action;
  const _Hint(this.icon, this.gesture, this.action);

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      leading: Icon(icon, color: CupertinoColors.systemGrey),
      title: Text(action),
      subtitle: Text(gesture),
    );
  }
}
