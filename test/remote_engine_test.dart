import 'package:flutter_test/flutter_test.dart';
import 'package:kaibitzer/ai/katago_http.dart';
import 'package:kaibitzer/ai/remote_config.dart';
import 'package:kaibitzer/engine/point.dart';

void main() {
  group('RemoteEngineConfig', () {
    test('defaults to local Ollama', () {
      final config = RemoteEngineConfig.fromParts(
        page: Uri.parse('https://ikaankeskin.github.io/kaibitzer/'),
      );
      expect(config.logosUrl, RemoteEngineConfig.defaultLogosUrl);
      expect(config.logosModel, RemoteEngineConfig.defaultLogosModel);
      expect(config.logosApiKey, isNull);
      expect(config.kataGoUrl, isNull);
    });

    test('query params override dart-defines', () {
      final config = RemoteEngineConfig.fromParts(
        page: Uri.parse(
          'https://example.com/?logos_url=https://api.example/v1&logos_model=qwen&logos_key=sk&katago_url=https://kata.example',
        ),
        logosUrlDefine: 'http://ignored',
        logosModelDefine: 'ignored',
      );
      expect(config.logosUrl, 'https://api.example/v1');
      expect(config.logosModel, 'qwen');
      expect(config.logosApiKey, 'sk');
      expect(config.kataGoUrl, 'https://kata.example');
    });

    test('explicit fields win over query', () {
      final config = RemoteEngineConfig.fromParts(
        page: Uri.parse('https://example.com/?logos_url=https://from-query'),
        logosUrl: 'https://from-ui',
      );
      expect(config.logosUrl, 'https://from-ui');
    });
  });

  group('KataGo HTTP parse', () {
    test('reads moveInfos by order', () {
      final recs = parseKataGoHttpAnalysis(
        {
          'moveInfos': [
            {
              'moveCoord': 'Q16',
              'order': 1,
              'visits': 10,
              'winrate': 0.4,
            },
            {
              'moveCoord': 'D4',
              'order': 0,
              'visits': 80,
              'winrate': 0.55,
            },
          ],
        },
        19,
        max: 2,
      );
      expect(recs, hasLength(2));
      expect(recs.first.point, Point.parse('D4', 19));
      expect(recs.last.point, Point.parse('Q16', 19));
    });

    test('skips pass and accepts move field', () {
      final recs = parseKataGoHttpAnalysis(
        {
          'moveInfos': [
            {'move': 'pass', 'order': 0},
            {'move': 'C3', 'order': 1, 'visits': 3},
          ],
        },
        9,
      );
      expect(recs.single.point, const Point(2, 6));
    });
  });
}
