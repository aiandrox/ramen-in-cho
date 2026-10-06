import 'dart:async';

import 'package:flutter/material.dart';

/// 下から出る窓。タブの画面から開いたときは、上の見出しと下のタブ・判子の間に出し、
/// タブと判子は覆わない（[ShellSheetHost]）。全画面の画面から開いたときは、画面の下端から出す。
/// 窓を閉じるときは [closeWashiSheet] を使う。
Future<T?> showWashiSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  ShellSheetHostState? host,
  Object? tag,
}) {
  final shell = host ?? ShellSheetHost.maybeOf(context);
  if (shell != null) return shell.show<T>(builder: builder, tag: tag);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    builder: builder,
  );
}

/// [showWashiSheet] で開いた窓を閉じ、[result] を返す。
void closeWashiSheet<T>(BuildContext context, [T? result]) {
  final scope = context.getInheritedWidgetOfExactType<_ShellSheetScope>();
  if (scope != null) {
    scope.host.close(result);
  } else {
    Navigator.of(context).pop(result);
  }
}

/// タブの画面の上に窓を出す場所。[headerHeight] の分（タブの画面の見出し）は覆わない。
/// 下端は下のタブの上なので、はみ出す判子の分 [footerOverlap] だけ窓の中を空ける。
class ShellSheetHost extends StatefulWidget {
  const ShellSheetHost({
    super.key,
    required this.child,
    this.headerHeight = kToolbarHeight,
    this.footerOverlap = 0,
  });

  final Widget child;
  final double headerHeight;
  final double footerOverlap;

  static ShellSheetHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ShellSheetHostState>();

  @override
  State<ShellSheetHost> createState() => ShellSheetHostState();
}

class _SheetEntry {
  _SheetEntry(this.builder, this.completer, this.tag);

  final WidgetBuilder builder;
  final Completer<Object?> completer;
  final Object? tag;
}

class ShellSheetHostState extends State<ShellSheetHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      BottomSheet.createAnimationController(this);
  _SheetEntry? _entry;
  bool _closing = false;

  bool get isOpen => _entry != null && !_closing;

  /// いま開いている窓の [show] の `tag`。閉じていれば null。
  Object? get openTag => isOpen ? _entry!.tag : null;

  Future<T?> show<T>({required WidgetBuilder builder, Object? tag}) {
    _complete(_entry);
    final completer = Completer<Object?>();
    setState(() {
      _entry = _SheetEntry(builder, completer, tag);
      _closing = false;
    });
    _controller.forward();
    return completer.future.then((value) => value as T?);
  }

  void close([Object? result]) {
    final entry = _entry;
    if (entry == null || _closing) return;
    _closing = true;
    _complete(entry, result);
    setState(() {});
    _controller.reverse().whenCompleteOrCancel(() {
      if (mounted && identical(_entry, entry) && _closing) {
        setState(() {
          _entry = null;
          _closing = false;
        });
      }
    });
  }

  void _complete(_SheetEntry? entry, [Object? result]) {
    if (entry != null && !entry.completer.isCompleted) {
      entry.completer.complete(result);
    }
  }

  @override
  void dispose() {
    _complete(_entry);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (entry != null)
            Positioned.fill(
              top: MediaQuery.paddingOf(context).top + widget.headerHeight,
              // 窓の中の SafeArea が、端末の上の帯の分を空けないように。
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: IgnorePointer(
                  ignoring: _closing,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: close,
                          child: FadeTransition(
                            opacity: _controller,
                            child: const ColoredBox(color: Colors.black54),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(_controller),
                          // 中身の量で窓の幅が変わらないよう、幅は画面いっぱい（640まで）に決める。
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: SizedBox(
                              width: double.infinity,
                              child: BottomSheet(
                                animationController: _controller,
                                showDragHandle: true,
                                onClosing: close,
                                builder: (context) => _ShellSheetScope(
                                  host: this,
                                  child: SingleChildScrollView(
                                    padding: EdgeInsets.only(
                                      bottom: widget.footerOverlap,
                                    ),
                                    child: Builder(builder: entry.builder),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShellSheetScope extends InheritedWidget {
  const _ShellSheetScope({required this.host, required super.child});

  final ShellSheetHostState host;

  @override
  bool updateShouldNotify(_ShellSheetScope oldWidget) => host != oldWidget.host;
}
