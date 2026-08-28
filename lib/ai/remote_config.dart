/// Endpoints for optional LoGos / KataGo HTTP servers.
///
/// There is no public CORS KataGo host, and LoGos-7B is not on a free
/// inference API (Hugging Face serverless needs a token and a GPU; Ollama
/// library is pull-only). The web app still *offers* those engines:
/// it tries local Ollama, then any URL you pass (query, dart-define, or
/// the setup fields). If nothing answers, the built-in tutor plays.
class RemoteEngineConfig {
  final String logosUrl;
  final String logosModel;
  final String? logosApiKey;
  final String? kataGoUrl;

  const RemoteEngineConfig({
    required this.logosUrl,
    required this.logosModel,
    this.logosApiKey,
    this.kataGoUrl,
  });

  static const defaultLogosUrl = 'http://127.0.0.1:11434';
  static const defaultLogosModel = 'logos-7b';

  static const String _defineLogosUrl = String.fromEnvironment('LOGOS_URL');
  static const String _defineLogosModel = String.fromEnvironment('LOGOS_MODEL');
  static const String _defineLogosKey = String.fromEnvironment('LOGOS_API_KEY');
  static const String _defineKataGoUrl = String.fromEnvironment('KATAGO_URL');

  factory RemoteEngineConfig.resolve({
    Uri? page,
    String? logosUrl,
    String? logosModel,
    String? logosApiKey,
    String? kataGoUrl,
  }) {
    final uri = page ?? Uri.base;
    return fromParts(
      page: uri,
      logosUrlDefine: _defineLogosUrl,
      logosModelDefine: _defineLogosModel,
      logosKeyDefine: _defineLogosKey,
      kataGoUrlDefine: _defineKataGoUrl,
      logosUrl: logosUrl,
      logosModel: logosModel,
      logosApiKey: logosApiKey,
      kataGoUrl: kataGoUrl,
    );
  }

  /// Testable constructor that does not read `fromEnvironment`.
  static RemoteEngineConfig fromParts({
    required Uri page,
    String logosUrlDefine = '',
    String logosModelDefine = '',
    String logosKeyDefine = '',
    String kataGoUrlDefine = '',
    String? logosUrl,
    String? logosModel,
    String? logosApiKey,
    String? kataGoUrl,
  }) {
    final q = page.queryParameters;
    return RemoteEngineConfig(
      logosUrl: _firstNonEmpty([
            logosUrl,
            q['logos_url'],
            logosUrlDefine,
          ]) ??
          defaultLogosUrl,
      logosModel: _firstNonEmpty([
            logosModel,
            q['logos_model'],
            logosModelDefine,
          ]) ??
          defaultLogosModel,
      logosApiKey: _firstNonEmpty([
        logosApiKey,
        q['logos_key'],
        logosKeyDefine,
      ]),
      kataGoUrl: _firstNonEmpty([
        kataGoUrl,
        q['katago_url'],
        kataGoUrlDefine,
      ]),
    );
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}
