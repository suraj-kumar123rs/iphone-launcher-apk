import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../native.dart';
import '../state.dart';
import 'common.dart';
import 'folder.dart';
import 'home_widgets.dart';

/// One home screen page: widgets (first page) + a 4x6 grid of apps/folders.
class HomePageGrid extends StatelessWidget {
  final int page;
  const HomePageGrid({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => LayoutBuilder(
        builder: (context, c) {
          if (page >= s.pages.length) return const SizedBox.shrink();
          final items = s.pages[page];
          const hp = 16.0;
          final cellW = (c.maxWidth - hp * 2) / Launcher.cols;
          final cellH = c.maxHeight / Launcher.rows;
          final icon = iconSizeFor(context);
          final rowOffset = page == 0 ? Launcher.widgetRows : 0;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: s.editing
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    s.setEditing(true);
                  },
            onTap: s.editing ? () => s.setEditing(false) : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DragTarget<HomeItem>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (d) => s.moveTo(d.data, page, s.pages[page].length),
                    builder: (_, __, ___) => const SizedBox.expand(),
                  ),
                ),
                if (page == 0)
                  Positioned(
                    left: hp,
                    right: hp,
                    top: 4,
                    height: cellH * Launcher.widgetRows - 8,
                    child: const HomeWidgetsRow(),
                  ),
                for (var i = 0; i < items.length; i++)
                  AnimatedPositioned(
                    key: ValueKey(items[i].id),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: hp + (i % Launcher.cols) * cellW,
                    top: (rowOffset + i ~/ Launcher.cols) * cellH,
                    width: cellW,
                    height: cellH,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: HomeCell(item: items[i], container: page, index: i, iconSize: icon, showLabel: s.showLabels),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The glass dock at the bottom.
class Dock extends StatelessWidget {
  const Dock({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    final icon = iconSizeFor(context);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Glass(
          radius: 34,
          alpha: 0.2,
          blur: 30,
          height: icon + 26,
          child: DragTarget<HomeItem>(
            onWillAcceptWithDetails: (d) => s.canDropInDock(d.data),
            onAcceptWithDetails: (d) => s.moveTo(d.data, -1, s.dock.length),
            builder: (_, __, ___) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < s.dock.length; i++)
                  HomeCell(key: ValueKey(s.dock[i].id), item: s.dock[i], container: -1, index: i, iconSize: icon, showLabel: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeCell extends StatefulWidget {
  final HomeItem item;
  final int container; // -1 = dock, otherwise page index
  final int index;
  final double iconSize;
  final bool showLabel;

  const HomeCell({
    super.key,
    required this.item,
    required this.container,
    required this.index,
    required this.iconSize,
    required this.showLabel,
  });

  @override
  State<HomeCell> createState() => _HomeCellState();
}

class _HomeCellState extends State<HomeCell> {
  final _iconKey = GlobalKey();
  bool _mergeHover = false;

  Launcher get s => Launcher.i;
  double get _fb => widget.iconSize * 1.12;

  Rect? _iconRect() {
    final b = _iconKey.currentContext?.findRenderObject() as RenderBox?;
    if (b == null || !b.hasSize || !b.attached) return null;
    return b.localToGlobal(Offset.zero) & b.size;
  }

  bool _overCenter(Offset pointer) {
    final r = _iconRect();
    if (r == null) return false;
    return (pointer - r.center).distance < widget.iconSize * 0.34;
  }

  void _open() {
    final it = widget.item;
    if (it.isFolder) {
      openFolder(context, it);
    } else if (!s.editing) {
      s.launch(it.pkg!, _iconRect());
    }
  }

  Widget _iconVisual(double size) {
    final it = widget.item;
    return it.isFolder ? FolderIcon(pkgs: it.apps, size: size) : AppIcon(app: s.apps[it.pkg], size: size);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final visual = AnimatedScale(
      scale: _mergeHover ? 1.14 : 1,
      duration: const Duration(milliseconds: 160),
      child: _iconVisual(widget.iconSize),
    );

    Widget core;
    if (s.editing) {
      core = LongPressDraggable<HomeItem>(
        data: it,
        delay: const Duration(milliseconds: 130),
        hapticFeedbackOnStart: true,
        dragAnchorStrategy: (_, __, ___) => Offset(_fb / 2, _fb / 2),
        feedback: Material(
          type: MaterialType.transparency,
          child: SizedBox(width: _fb, height: _fb, child: _iconVisual(_fb)),
        ),
        childWhenDragging: SizedBox(width: widget.iconSize, height: widget.iconSize),
        onDragStarted: () => s.dragging.value = true,
        onDragEnd: (_) => s.dragging.value = false,
        child: GestureDetector(
          onTap: it.isFolder ? _open : () {},
          child: Jiggle(
            seed: it.id.hashCode,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                visual,
                Positioned(left: -8, top: -8, child: MinusBadge(onTap: () => confirmRemove(context, it))),
              ],
            ),
          ),
        ),
      );
    } else {
      core = CupertinoContextMenu(
        enableHapticFeedback: true,
        actions: _menuActions(context),
        child: GestureDetector(onTap: _open, child: visual),
      );
    }

    final label = widget.showLabel ? (it.isFolder ? it.name : (s.apps[it.pkg]?.label ?? '')) : null;
    final cell = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(key: _iconKey, child: SizedBox(width: widget.iconSize, height: widget.iconSize, child: core)),
        if (label != null) ...[
          const SizedBox(height: 5),
          SizedBox(width: widget.iconSize + 22, child: IconLabel(label)),
        ],
      ],
    );

    if (!s.editing) return cell;

    return DragTarget<HomeItem>(
      onWillAcceptWithDetails: (d) => d.data.id != it.id && (widget.container >= 0 || s.canDropInDock(d.data) || !d.data.isFolder),
      onMove: (d) {
        final over = !d.data.isFolder && _overCenter(d.offset + Offset(_fb / 2, _fb / 2));
        if (over != _mergeHover) setState(() => _mergeHover = over);
      },
      onLeave: (_) {
        if (_mergeHover) setState(() => _mergeHover = false);
      },
      onAcceptWithDetails: (d) {
        final p = d.offset + Offset(_fb / 2, _fb / 2);
        final merge = !d.data.isFolder && _overCenter(p);
        setState(() => _mergeHover = false);
        if (merge) {
          s.merge(d.data, it);
        } else {
          final r = _iconRect();
          final after = r != null && p.dx > r.center.dx;
          s.moveTo(d.data, widget.container, widget.index + (after ? 1 : 0));
        }
      },
      builder: (_, __, ___) => cell,
    );
  }

  List<Widget> _menuActions(BuildContext ctx) {
    final it = widget.item;
    void then(VoidCallback f) {
      Navigator.of(ctx).pop();
      Future.delayed(const Duration(milliseconds: 280), f);
    }

    if (it.isFolder) {
      return [
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.pencil,
          onPressed: () => then(() => renameFolderDialog(context, it)),
          child: const Text('Rename'),
        ),
        CupertinoContextMenuAction(
          trailingIcon: CupertinoIcons.square_grid_2x2,
          onPressed: () => then(() => s.setEditing(true)),
          child: const Text('Edit Home Screen'),
        ),
        CupertinoContextMenuAction(
          isDestructiveAction: true,
          trailingIcon: CupertinoIcons.minus_circle,
          onPressed: () => then(() => confirmRemove(context, it)),
          child: const Text('Remove Folder'),
        ),
      ];
    }
    return [
      CupertinoContextMenuAction(
        trailingIcon: CupertinoIcons.square_grid_2x2,
        onPressed: () => then(() => s.setEditing(true)),
        child: const Text('Edit Home Screen'),
      ),
      CupertinoContextMenuAction(
        trailingIcon: CupertinoIcons.info_circle,
        onPressed: () => then(() => Native.appInfo(it.pkg!)),
        child: const Text('App Info'),
      ),
      CupertinoContextMenuAction(
        isDestructiveAction: true,
        trailingIcon: CupertinoIcons.minus_circle,
        onPressed: () => then(() => confirmRemove(context, it)),
        child: const Text('Remove App'),
      ),
    ];
  }
}

// ---------------- Dialogs ----------------

Future<void> confirmRemove(BuildContext context, HomeItem it) {
  final s = Launcher.i;
  final name = it.isFolder ? it.name : (s.apps[it.pkg]?.label ?? 'App');
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text('Remove “$name”?'),
      content: Text(it.isFolder
          ? 'The apps in this folder will move to the Library.'
          : 'Removing from Home Screen will keep the app in your Library.'),
      actions: [
        if (!it.isFolder)
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Native.uninstall(it.pkg!);
            },
            child: const Text('Delete App'),
          ),
        CupertinoDialogAction(
          isDestructiveAction: it.isFolder,
          onPressed: () {
            Navigator.pop(ctx);
            s.removeFromHome(it);
          },
          child: Text(it.isFolder ? 'Remove Folder' : 'Remove from Home Screen'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<void> renameFolderDialog(BuildContext context, HomeItem folder) async {
  final ctrl = TextEditingController(text: folder.name);
  final name = await showCupertinoDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Rename Folder'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(controller: ctrl, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
      ),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
      ],
    ),
  );
  if (name != null) Launcher.i.renameFolder(folder, name);
}

/// Action sheet for an app in the Library or search.
Future<void> showAppSheet(BuildContext context, AppInfo app) {
  final s = Launcher.i;
  final onHome = s.isOnHome(app.pkg);
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(app.label),
      actions: [
        if (!onHome)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              s.addToHome(app.pkg);
            },
            child: const Text('Add to Home Screen'),
          ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            Native.appInfo(app.pkg);
          },
          child: const Text('App Info'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(ctx);
            Native.uninstall(app.pkg);
          },
          child: const Text('Delete App'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
    ),
  );
}
