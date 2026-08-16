import 'dart:io';

import 'package:flutter/material.dart';

/// Material tuned to feel like a desktop (macOS) app instead of a mobile
/// one: system font, compact density, no ink splashes, neutral grays with a
/// blue accent, small radii, flat 44px toolbar.
ThemeData desktopTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3574F0),
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );

  const radius = BorderRadius.all(Radius.circular(6));
  const shape = RoundedRectangleBorder(borderRadius: radius);

  return ThemeData(
    colorScheme: scheme,
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    fontFamily: Platform.isMacOS ? '.AppleSystemUIFont' : null,
    appBarTheme: AppBarTheme(
      toolbarHeight: 44,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surfaceContainerLow,
      titleTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        fontFamily: Platform.isMacOS ? '.AppleSystemUIFont' : null,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        iconSize: 18,
        visualDensity: VisualDensity.compact,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity.compact,
      shape: shape,
      contentPadding: EdgeInsets.symmetric(horizontal: 12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: shape,
      textStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
      isDense: true,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(false),
      thickness: const WidgetStatePropertyAll(8),
    ),
  );
}
