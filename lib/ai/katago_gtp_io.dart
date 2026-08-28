import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../coach/kaibitzer_coach.dart';
import '../engine/game.dart';
import '../engine/point.dart';
import 'gtp_parser.dart';
import 'move_engine.dart';

class KataGoGtpEngine implements MoveEngine {
  KataGoGtpEngine._(this._process, this._stdin, this._lines);

  final Process _process;
  final IOSink _stdin;
  final StreamIterator<String> _lines;

  @override
  String get name => 'KataGo';

  @override
  bool get isNeuralNet => true;

  static Future<KataGoGtpEngine?> tryLaunch() async {
    final launch = _discover();
    if (launch == null) {
      return null;
    }
    try {
      final args = <String>['gtp'];
      if (launch.configPath != null) {
        args.addAll(['-config', launch.configPath!]);
      }
      if (launch.modelPath != null) {
        args.addAll(['-model', launch.modelPath!]);
      }
      final process = await Process.start(
        launch.binaryPath,
        args,
        workingDirectory: launch.home,
      );
      final lines = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
      final engine = KataGoGtpEngine._(process, process.stdin, lines);
      final ok = await engine._rpc('protocol_version');
      if (ok == null || ok.startsWith('?')) {
        await engine.dispose();
        return null;
      }
      return engine;
    } catch (_) {
      return null;
    }
  }

  static _KataLaunch? _discover() {
    final envBin = Platform.environment['KATAGO_PATH'];
    final envHome = Platform.environment['KATAGO_HOME'];
    final envModel = Platform.environment['KATAGO_MODEL'];
    final envConfig = Platform.environment['KATAGO_CONFIG'];

    final cwd = Directory.current.path;
    final homeDir = Platform.environment['USERPROFILE'] ?? '';
    final candidates = <String>[
      if (envBin != null) envBin,
      if (envHome != null) '$envHome${Platform.pathSeparator}katago.exe',
      if (envHome != null) '$envHome${Platform.pathSeparator}katago',
      '$cwd${Platform.pathSeparator}engines${Platform.pathSeparator}katago${Platform.pathSeparator}katago.exe',
      if (homeDir.isNotEmpty)
        '$homeDir${Platform.pathSeparator}Kaibitzer${Platform.pathSeparator}engines${Platform.pathSeparator}katago${Platform.pathSeparator}katago.exe',
      'katago',
      'katago.exe',
      '${Platform.environment['LOCALAPPDATA']}\\katago\\katago.exe',
      '$homeDir\\katago\\katago.exe',
      '$homeDir\\KataGo\\katago.exe',
      r'C:\katago\katago.exe',
    ];

    for (final raw in candidates) {
      final resolved = _which(raw);
      if (resolved == null) {
        continue;
      }
      final home = File(resolved).parent.path;
      final model = envModel ?? _firstFile(home, ['.bin.gz', '.bin']);
      final config = envConfig ??
          _firstNamed(home, [
            'default_gtp.cfg',
            'gtp.cfg',
            'gtp_example.cfg',
            'analysis_example.cfg',
          ]);
      return _KataLaunch(
        binaryPath: resolved,
        home: home,
        modelPath: model,
        configPath: config,
      );
    }
    return null;
  }

  static String? _which(String pathOrName) {
    final direct = File(pathOrName);
    if (direct.existsSync()) {
      return direct.absolute.path;
    }
    final path = Platform.environment['PATH'] ?? '';
    for (final dir in path.split(Platform.isWindows ? ';' : ':')) {
      if (dir.isEmpty) {
        continue;
      }
      final file = File('$dir${Platform.pathSeparator}$pathOrName');
      if (file.existsSync()) {
        return file.absolute.path;
      }
    }
    return null;
  }

  static String? _firstFile(String dir, List<String> suffixes) {
    final folder = Directory(dir);
    if (!folder.existsSync()) {
      return null;
    }
    try {
      for (final entity in folder.listSync()) {
        if (entity is File) {
          final name = entity.path.toLowerCase();
          if (suffixes.any(name.endsWith)) {
            return entity.path;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _firstNamed(String dir, List<String> names) {
    for (final name in names) {
      final file = File('$dir${Platform.pathSeparator}$name');
      if (file.existsSync()) {
        return file.path;
      }
    }
    return null;
  }

  Future<String?> _rpc(String command) async {
    _stdin.writeln(command);
    await _stdin.flush();
    final buffer = StringBuffer();
    var sawStart = false;
    while (await _lines.moveNext().timeout(
      const Duration(seconds: 20),
      onTimeout: () => false,
    )) {
      final line = _lines.current;
      if (!sawStart && (line.startsWith('=') || line.startsWith('?'))) {
        sawStart = true;
      }
      if (sawStart) {
        if (line.isEmpty) {
          break;
        }
        buffer.writeln(line);
      }
    }
    final text = buffer.toString();
    return text.isEmpty ? null : text;
  }

  Future<void> _syncBoard(GoGame game) async {
    await _rpc('boardsize ${game.size}');
    await _rpc('clear_board');
    await _rpc('komi ${game.rules.komi}');
    await _rpc('kata-set-rules ${kataRulesName(game.rules.ruleSet)}');
    for (final move in game.moves) {
      final color = gtpColor(move.player);
      switch (move.kind) {
        case MoveKind.place:
          if (move.point != null) {
            await _rpc('play $color ${move.point!.toCoordinate(game.size)}');
          }
        case MoveKind.pass:
          await _rpc('play $color pass');
        case MoveKind.resign:
          break;
      }
    }
    if (game.moves.isEmpty) {
      for (final p in game.board.intersections) {
        final stone = game.board.at(p);
        if (stone.isPlayer) {
          await _rpc(
            'play ${gtpColor(stone)} ${p.toCoordinate(game.size)}',
          );
        }
      }
    }
  }

  @override
  Future<Point?> genMove(GoGame game, AiLevel level) async {
    await _syncBoard(game);
    await _rpc('time_settings 0 ${searchSeconds(level).ceil().clamp(1, 10)} 1');
    await _rpc('kata-set-param maxTime ${searchSeconds(level)}');
    final reply = await _rpc('genmove ${gtpColor(game.toPlay)}');
    if (reply == null) {
      return null;
    }
    return GtpParser.genmovePoint(reply, game.size);
  }

  @override
  Future<List<MoveRecommendation>> analyze(GoGame game, {int max = 3}) async {
    await _syncBoard(game);
    final visits = analyzeVisits(AiLevel.medium);
    // One-shot analyze: request a burst then stop.
    _stdin.writeln('kata-analyze interval 20 maxVisits $visits');
    await _stdin.flush();
    final buffer = StringBuffer();
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(deadline)) {
      final hasLine = await _lines.moveNext().timeout(
        const Duration(milliseconds: 400),
        onTimeout: () => false,
      );
      if (!hasLine) {
        break;
      }
      buffer.writeln(_lines.current);
      if (buffer.toString().contains('info move')) {
        break;
      }
    }
    _stdin.writeln();
    await _stdin.flush();
    return GtpParser.analyzeRecommendations(buffer.toString(), game.size, max: max);
  }

  @override
  Future<void> dispose() async {
    try {
      _stdin.writeln('quit');
      await _stdin.flush();
    } catch (_) {}
    _process.kill();
    await _lines.cancel();
  }
}

class _KataLaunch {
  final String binaryPath;
  final String home;
  final String? modelPath;
  final String? configPath;

  _KataLaunch({
    required this.binaryPath,
    required this.home,
    required this.modelPath,
    required this.configPath,
  });
}
