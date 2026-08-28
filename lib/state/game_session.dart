import 'package:flutter/material.dart';

import '../ai/engine_factory.dart';
import '../ai/logos_engine.dart';
import '../coach/kaibitzer_coach.dart';
import '../engine/game.dart';
import '../engine/point.dart';
import '../engine/rules.dart';
import '../engine/stone.dart';
import '../ui/goban/goban_style.dart';
import 'match_config.dart';

class GameSession extends ChangeNotifier {
  GoGame game;
  GobanAppearance appearance;
  final MatchConfig match;
  final KaibitzerCoach coach;
  final List<CoachMessage> messages;
  final List<EngineLogEntry> debugLogs;
  List<MoveRecommendation> hints;
  bool showHints;
  bool showDebugConsole;
  bool thinking;
  AiLevel aiLevel;
  EngineKind engineKind;
  String engineName;
  bool engineIsNeuralNet;
  int _aiGeneration;
  MoveEngine? _engine;
  Future<MoveEngine>? _engineFuture;
  bool _alive;

  GameSession({
    required this.game,
    required this.appearance,
    this.match = const MatchConfig.local(),
    KaibitzerCoach? coach,
  })  : coach = coach ?? KaibitzerCoach(),
        messages = [
          CoachMessage(
            fromCoach: true,
            text: match.vsComputer
                ? 'I play ${match.computerColor.label} with ${match.engine.title}. '
                    'Press H for a hint, then 1 2 3 to play a suggested move. '
                    'Switch engine or difficulty from the toolbar.'
                : 'Press H for a recommended move, then 1 2 3 to play it. '
                    'Pick an engine in the toolbar if you want KataGo or LoGos-7B hints.',
          ),
        ],
        debugLogs = [],
        hints = const [],
        showHints = false,
        showDebugConsole = true,
        thinking = false,
        aiLevel = match.aiLevel,
        engineKind = match.engine,
        engineName = match.engine.title,
        engineIsNeuralNet = match.engine.isNeuralNet,
        _aiGeneration = 0,
        _alive = true {
    _loadEngine(match.engine);
  }

  @override
  void dispose() {
    _alive = false;
    _aiGeneration++;
    _engine?.dispose();
    super.dispose();
  }

  factory GameSession.start({
    required GameRules rules,
    GobanAppearance appearance = const GobanAppearance(),
    MatchConfig match = const MatchConfig.local(),
  }) {
    return GameSession(
      game: GoGame(rules),
      appearance: appearance,
      match: match,
    );
  }

  Stone get toPlay => game.toPlay;

  bool get vsComputer => match.vsComputer;

  bool get isHumanTurn =>
      !vsComputer || game.toPlay == match.humanColor;

  bool get inputLocked =>
      thinking ||
      game.phase != GamePhase.playing ||
      (vsComputer && !isHumanTurn);

  void logEngine({
    required String source,
    required String summary,
    String? detail,
    Duration? elapsed,
    bool isError = false,
  }) {
    logEngineEntry(
      EngineLogEntry(
        source: source,
        summary: summary,
        detail: detail,
        elapsed: elapsed,
        isError: isError,
      ),
    );
  }

  void clearDebugLogs() {
    debugLogs.clear();
    notifyListeners();
  }

  void toggleDebugConsole() {
    showDebugConsole = !showDebugConsole;
    notifyListeners();
  }

  void setAiLevel(AiLevel level) {
    if (level == aiLevel) {
      return;
    }
    logEngine(
      source: 'session',
      summary: 'Difficulty ${aiLevel.title} → ${level.title}',
    );
    aiLevel = level;
    notifyListeners();
  }

  void setEngine(EngineKind kind) {
    if (kind == engineKind && _engine != null) {
      return;
    }
    logEngine(
      source: 'session',
      summary: 'Switch engine: ${engineKind.title} → ${kind.title}',
    );
    engineKind = kind;
    _aiGeneration++;
    thinking = false;
    engineName = kind.title;
    engineIsNeuralNet = kind.isNeuralNet;
    notifyListeners();
    _loadEngine(kind, announce: true);
  }

  void _loadEngine(EngineKind kind, {bool announce = false}) {
    final previous = _engine;
    _engine = null;
    previous?.dispose();
    logEngine(source: 'session', summary: 'Loading ${kind.title}…');
    final future = createMoveEngine(
      kind: kind,
      fallback: HeuristicEngine(coach: coach),
      log: logEngineEntry,
    );
    _engineFuture = future;
    future.then((engine) {
      if (!_alive || _engineFuture != future) {
        engine.dispose();
        return;
      }
      _engine = engine;
      engineName = engine.name;
      engineIsNeuralNet = engine.isNeuralNet;
      if (engine.name != kind.title) {
        logEngine(
          source: 'session',
          summary: '${kind.title} unavailable, using ${engine.name}',
          isError: true,
        );
      } else if (engine is LogosEngine) {
        logEngine(
          source: 'session',
          summary: 'Ready: ${engine.name} (${_modelLabel(engine)})',
        );
      } else {
        logEngine(source: 'session', summary: 'Ready: ${engine.name}');
      }
      if (announce || kind != EngineKind.heuristic) {
        _noteEngineReady(kind, engine);
      }
      notifyListeners();
      scheduleAiMove();
    });
  }

  void logEngineEntry(EngineLogEntry entry) {
    debugLogs.add(entry);
    const cap = 250;
    if (debugLogs.length > cap) {
      debugLogs.removeRange(0, debugLogs.length - cap);
    }
    notifyListeners();
  }

  String _modelLabel(LogosEngine engine) {
    return '${engine.model} @ ${engine.baseUrl}';
  }

  void _noteEngineReady(EngineKind requested, MoveEngine engine) {
    if (requested == EngineKind.katago && engine.name != 'KataGo') {
      messages.add(
        const CoachMessage(
          fromCoach: true,
          text:
              'KataGo was not found, so I am using the built-in tutor. '
              'Install katago.exe on Windows and set KATAGO_PATH, or pick another engine.',
        ),
      );
    } else if (requested == EngineKind.logos) {
      messages.add(
        const CoachMessage(
          fromCoach: true,
          text:
              'LoGos-7B talks to a local server (Ollama, llama.cpp, or LM Studio). '
              'If nothing is running, I fall back to the built-in tutor for that move.',
        ),
      );
    } else if (requested == EngineKind.heuristic) {
      messages.add(
        const CoachMessage(
          fromCoach: true,
          text: 'Using the built-in tutor.',
        ),
      );
    } else if (engine.name == 'KataGo') {
      messages.add(
        const CoachMessage(
          fromCoach: true,
          text: 'KataGo is ready.',
        ),
      );
    }
  }

  void tapPoint(Point point) {
    if (game.phase == GamePhase.scoring) {
      game.toggleDead(point);
      notifyListeners();
      return;
    }
    if (inputLocked) {
      return;
    }
    final result = game.play(point);
    if (!result.ok) {
      messages.add(CoachMessage(fromCoach: true, text: result.reason ?? 'Illegal move.'));
      notifyListeners();
      return;
    }
    hints = const [];
    showHints = false;
    notifyListeners();
    scheduleAiMove();
  }

  void playHint(int index) {
    if (inputLocked) {
      return;
    }
    if (!showHints || index < 0 || index >= hints.length) {
      return;
    }
    tapPoint(hints[index].point);
  }

  void pass() {
    if (inputLocked) {
      return;
    }
    final result = game.pass();
    if (!result.ok && result.reason != null) {
      messages.add(CoachMessage(fromCoach: true, text: result.reason!));
    } else if (game.phase == GamePhase.scoring) {
      messages.add(
        const CoachMessage(
          fromCoach: true,
          text:
              'Both players passed. Tap groups that are dead, then confirm the score. '
              'I can still estimate the living-stone score if you ask.',
        ),
      );
    }
    hints = const [];
    showHints = false;
    notifyListeners();
    scheduleAiMove();
  }

  void resign() {
    _aiGeneration++;
    thinking = false;
    if (vsComputer) {
      game.toPlay = match.humanColor;
    }
    game.resign();
    hints = const [];
    notifyListeners();
  }

  void undo() {
    if (!game.canUndo) {
      return;
    }
    _aiGeneration++;
    thinking = false;
    game.undo();
    if (vsComputer && game.toPlay == match.computerColor && game.canUndo) {
      game.undo();
    }
    hints = const [];
    showHints = false;
    notifyListeners();
  }

  void confirmScore() {
    game.confirmScore();
    notifyListeners();
  }

  void updateAppearance(GobanAppearance next) {
    appearance = next;
    notifyListeners();
  }

  void ask(String question) {
    messages.add(CoachMessage(fromCoach: false, text: question));
    final reply = coach.answer(game, question);
    messages.add(reply);
    if (reply.recommendations.isNotEmpty) {
      hints = reply.recommendations;
      showHints = true;
    }
    notifyListeners();
  }

  Future<void> recommendMoves() async {
    messages.add(const CoachMessage(fromCoach: false, text: 'Recommend a move'));
    notifyListeners();
    final engine = await (_engineFuture ?? Future.value(HeuristicEngine(coach: coach)));
    _engine = engine;
    logEngine(
      source: 'session',
      summary: 'Hint request via ${engine.name}',
    );
    var recs = await engine.analyze(game, max: 3);
    if (recs.isEmpty) {
      recs = coach.recommend(game, max: 3);
    }
    hints = recs;
    showHints = recs.isNotEmpty;
    messages.add(
      CoachMessage(
        fromCoach: true,
        text: recs.isEmpty
            ? 'No legal suggestion right now. Passing may be correct.'
            : _formatHints(recs),
        recommendations: recs,
      ),
    );
    notifyListeners();
  }

  String _formatHints(List<MoveRecommendation> recs) {
    final lines = <String>[
      'Suggested for ${game.toPlay.label} ($engineName). Press 1, 2, or 3 to play one.',
    ];
    for (var i = 0; i < recs.length; i++) {
      final rec = recs[i];
      lines.add('${i + 1}. ${rec.point.toCoordinate(game.size)} — ${rec.headline}');
    }
    return lines.join('\n');
  }

  void clearHints() {
    showHints = false;
    hints = const [];
    notifyListeners();
  }

  Future<void> scheduleAiMove() async {
    if (!vsComputer ||
        game.phase != GamePhase.playing ||
        game.toPlay != match.computerColor) {
      return;
    }
    final token = ++_aiGeneration;
    thinking = true;
    notifyListeners();
    final engine = await (_engineFuture ?? Future.value(HeuristicEngine(coach: coach)));
    if (token != _aiGeneration || !_alive) {
      return;
    }
    _engine = engine;
    engineName = engine.name;
    engineIsNeuralNet = engine.isNeuralNet;
    logEngine(
      source: 'session',
      summary: 'Requesting move from ${engine.name} (${aiLevel.title})',
    );
    Point? point;
    try {
      point = await engine.genMove(game, aiLevel);
    } catch (_) {
      logEngine(
        source: 'session',
        summary: '${engine.name} threw, using built-in tutor',
        isError: true,
      );
      point = HeuristicEngine(coach: coach).computer.choose(game, aiLevel);
    }
    if (token != _aiGeneration || !_alive) {
      return;
    }
    if (point == null) {
      game.pass();
    } else {
      final result = game.play(point);
      if (!result.ok) {
        game.pass();
      }
    }
    thinking = false;
    notifyListeners();
  }
}
