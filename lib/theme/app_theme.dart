import 'package:flutter/material.dart';

import 'washi.dart';
import 'washi_buttons.dart';

ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: Washi.ai,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        primary: Washi.ai,
        onPrimary: Colors.white,
        surface: Washi.paper,
        onSurface: Washi.ink,
        onSurfaceVariant: Washi.inkSoft,
        outline: Washi.inkSoft,
        outlineVariant: Washi.line,
        surfaceContainerLowest: Washi.page,
        surfaceContainerLow: Washi.page,
        surfaceContainer: Washi.page,
        surfaceContainerHigh: Washi.page,
        surfaceContainerHighest: Washi.desk,
        secondaryContainer: Washi.page,
        onSecondaryContainer: Washi.ink,
      );
  return ThemeData(
    colorScheme: colorScheme,
    fontFamily: Washi.mincho,
    scaffoldBackgroundColor: Washi.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Washi.paper,
      foregroundColor: Washi.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: Washi.brush,
        fontSize: 24,
        color: Washi.ink,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Washi.page,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Washi.line),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FudaStyle.ai()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: FudaStyle.sumi()),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Washi.ink,
        textStyle: const TextStyle(fontFamily: Washi.mincho, fontSize: 15),
        minimumSize: const Size(48, 48),
      ),
    ),
    // 選ぶ札は、角を落とした木札の形。選ぶと藍の地に和紙色の字になる。
    // チェックを出すと札の幅が変わってがたつくので、色だけで示す。
    chipTheme: ChipThemeData(
      showCheckmark: false,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
      color: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Washi.ai : Washi.page,
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected) ? Washi.ai : Washi.line,
          width: 1.2,
        ),
      ),
      labelStyle: TextStyle(
        fontFamily: Washi.mincho,
        fontSize: 14,
        color: WidgetStateColor.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Washi.page : Washi.ink,
        ),
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: Washi.mincho,
        fontSize: 14,
        color: Washi.page,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Washi.ai,
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Washi.paper,
      // 選んだタブは、アイコンの枠そのものが藍に変わって示す。
      indicatorColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: Washi.line),
    // 入力欄は明るい紙の枠で囲み、見出しや仕切りの線と見分けられるようにする。
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Washi.page,
      // 入れた字と見分けられるよう、未入力の例は薄くする。
      hintStyle: TextStyle(color: Washi.faded),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Washi.line),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Washi.line),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Washi.ai, width: 1.6),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      // 浮かせて出すと、下のタブの判子を押し上げずにその上へ出る。
      behavior: SnackBarBehavior.floating,
      backgroundColor: Washi.ink,
      contentTextStyle: TextStyle(fontFamily: Washi.mincho, color: Washi.paper),
    ),
  );
}
