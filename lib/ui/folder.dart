import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../native.dart';
import '../state.dart';
import 'common.dart';
import 'grid.dart';

void openFolder(BuildContext context, HomeItem folder) {
  pushOverlay<void>(context, (ctx, anim) => FolderView(anim: anim, folder: folder));
}

void openGroup(BuildContext context, LibraryGroup group) {
  pushOverlay<void>(context, (ctx, anim) => FolderView(anim: anim, title: group.name, pkgs: group.apps.map((a) => a.pkg).toList()));
}

/// Open folder (or a Library category) over a blurred background.
class FolderView extends StatelessWidget {
  final Animation<double> anim;
  final HomeItem? folder;
  final String? title;
  final List<String>? pkgs;

  const FolderView({super.key, required this.anim, this.folder, this.title, this.pkgs});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    final size = MediaQuery.sizeOf(context);
    final w = min(size.width - 48, 340.0);
    final icon = iconSizeFor(context);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final f = folder;
        if (f != null && (s.locate(f) == null || f.apps.length < 2)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.of(context).maybePop();
          });
        }
        final list = (f?.apps ?? pkgs ?? const <String>[]).where(s.apps.containsKey).toList();
        final name = f?.name ?? title ?? '';
        return Stack(
          children: [
            Positioned.fill(child: BlurBackdrop(anim: anim, sigma: 28, dim: 0.25, onTap: () => Navigator.of(context).pop())),
            Center(
              child: PopIn(
                anim: anim,
                from: 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: f == null ? null : () => renameFolderDialog(context, f),
                      child: Text(name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
                    ),
                    const SizedBox(height: 18),
                    Glass(
                      radius: 38,
                      alpha: 0.2,
                      width: w,
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: size.height * 0.55),
                        child: GridView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: list.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.84,
                            mainAxisSpacing: 4,
                          ),
                          itemBuilder: (context, i) => _FolderApp(pkg: list[i], folder: f, iconSize: icon),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FolderApp extends StatelessWidget {
  final String pkg;
  final HomeItem? folder;
  final double iconSize;
  const _FolderApp({required this.pkg, required this.folder, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final s = Launcher.i;
    final app = s.apps[pkg];
    final key = GlobalKey();
    return GestureDetector(
      onTap: () {
        final b = key.currentContext?.findRenderObject() as RenderBox?;
        final rect = b == null ? null : b.localToGlobal(Offset.zero) & b.size;
        s.launch(pkg, rect);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      },
      onLongPress: () => _sheet(context),
      child: Column(
        children: [
          KeyedSubtree(key: key, child: AppIcon(app: app, size: iconSize)),
          const SizedBox(height: 6),
          IconLabel(app?.label ?? ''),
        ],
      ),
    );
  }

  void _sheet(BuildContext context) {
    final app = Launcher.i.apps[pkg];
    if (app == null) return;
    final f = folder;
    if (f == null) {
      showAppSheet(context, app);
      return;
    }
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(app.label),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Launcher.i.removeFromFolder(f, pkg);
            },
            child: const Text('Remove from Folder'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Native.appInfo(pkg);
            },
            child: const Text('App Info'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Native.uninstall(pkg);
            },
            child: const Text('Delete App'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ),
    );
  }
}
