import 'package:flutter/material.dart';

enum GobanThemeId { kaya, night, ink, jade }

enum StoneFinish { classic, flat, shell }

class GobanAppearance {
  final GobanThemeId themeId;
  final StoneFinish stoneFinish;
  final bool showCoordinates;
  final bool showHoshi;
  final bool showMoveNumbers;
  final double lineWidth;

  const GobanAppearance({
    this.themeId = GobanThemeId.kaya,
    this.stoneFinish = StoneFinish.classic,
    this.showCoordinates = true,
    this.showHoshi = true,
    this.showMoveNumbers = false,
    this.lineWidth = 1.2,
  });

  GobanAppearance copyWith({
    GobanThemeId? themeId,
    StoneFinish? stoneFinish,
    bool? showCoordinates,
    bool? showHoshi,
    bool? showMoveNumbers,
    double? lineWidth,
  }) {
    return GobanAppearance(
      themeId: themeId ?? this.themeId,
      stoneFinish: stoneFinish ?? this.stoneFinish,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showHoshi: showHoshi ?? this.showHoshi,
      showMoveNumbers: showMoveNumbers ?? this.showMoveNumbers,
      lineWidth: lineWidth ?? this.lineWidth,
    );
  }
}

class GobanPalette {
  final Color boardFrom;
  final Color boardTo;
  final Color line;
  final Color hoshi;
  final Color blackStone;
  final Color blackHighlight;
  final Color whiteStone;
  final Color whiteHighlight;
  final Color coordinate;
  final Color lastMove;
  final Color hint;
  final Color woodGrain;

  const GobanPalette({
    required this.boardFrom,
    required this.boardTo,
    required this.line,
    required this.hoshi,
    required this.blackStone,
    required this.blackHighlight,
    required this.whiteStone,
    required this.whiteHighlight,
    required this.coordinate,
    required this.lastMove,
    required this.hint,
    required this.woodGrain,
  });

  factory GobanPalette.fromId(GobanThemeId id) {
    switch (id) {
      case GobanThemeId.kaya:
        return const GobanPalette(
          boardFrom: Color(0xFFE4C49A),
          boardTo: Color(0xFFC9965C),
          line: Color(0xFF5A3B1E),
          hoshi: Color(0xFF4A3018),
          blackStone: Color(0xFF1A1A1C),
          blackHighlight: Color(0xFF6A6A72),
          whiteStone: Color(0xFFF4F1EA),
          whiteHighlight: Color(0xFFFFFFFF),
          coordinate: Color(0xFF4A3018),
          lastMove: Color(0xFFC23B22),
          hint: Color(0xFFB42318),
          woodGrain: Color(0x332A1A0A),
        );
      case GobanThemeId.night:
        return const GobanPalette(
          boardFrom: Color(0xFF2A2622),
          boardTo: Color(0xFF1A1714),
          line: Color(0xFFD9C7A8),
          hoshi: Color(0xFFE8D5B5),
          blackStone: Color(0xFF0E0E10),
          blackHighlight: Color(0xFF4A4A52),
          whiteStone: Color(0xFFECE6DA),
          whiteHighlight: Color(0xFFFFFFFF),
          coordinate: Color(0xFFD9C7A8),
          lastMove: Color(0xFFFFB703),
          hint: Color(0xFFFF8A5B),
          woodGrain: Color(0x22FFFFFF),
        );
      case GobanThemeId.ink:
        return const GobanPalette(
          boardFrom: Color(0xFFF6F1E6),
          boardTo: Color(0xFFE7DDC8),
          line: Color(0xFF2B2B2B),
          hoshi: Color(0xFF1A1A1A),
          blackStone: Color(0xFF161616),
          blackHighlight: Color(0xFF5C5C5C),
          whiteStone: Color(0xFFFAFAF7),
          whiteHighlight: Color(0xFFFFFFFF),
          coordinate: Color(0xFF333333),
          lastMove: Color(0xFF1D4E89),
          hint: Color(0xFF9B1D20),
          woodGrain: Color(0x14000000),
        );
      case GobanThemeId.jade:
        return const GobanPalette(
          boardFrom: Color(0xFF7BA17D),
          boardTo: Color(0xFF4E7A58),
          line: Color(0xFF173022),
          hoshi: Color(0xFF102018),
          blackStone: Color(0xFF141816),
          blackHighlight: Color(0xFF6A7A70),
          whiteStone: Color(0xFFEEF3EC),
          whiteHighlight: Color(0xFFFFFFFF),
          coordinate: Color(0xFF102018),
          lastMove: Color(0xFFFFF3B0),
          hint: Color(0xFFFFF3B0),
          woodGrain: Color(0x22081510),
        );
    }
  }
}

extension GobanThemeLabels on GobanThemeId {
  String get title => switch (this) {
        GobanThemeId.kaya => 'Kaya',
        GobanThemeId.night => 'Night',
        GobanThemeId.ink => 'Ink',
        GobanThemeId.jade => 'Jade',
      };
}

extension StoneFinishLabels on StoneFinish {
  String get title => switch (this) {
        StoneFinish.classic => 'Classic',
        StoneFinish.flat => 'Flat',
        StoneFinish.shell => 'Shell',
      };
}
