enum EngineKind {
  heuristic,
  katago,
  logos,
}

extension EngineKindLabels on EngineKind {
  String get title => switch (this) {
        EngineKind.heuristic => 'Built-in tutor',
        EngineKind.katago => 'KataGo',
        EngineKind.logos => 'LoGos-7B (19×19)',
      };

  String get summary => switch (this) {
        EngineKind.heuristic =>
          'On-device tactics and opening sense. Always available, modest strength.',
        EngineKind.katago =>
          'Neural net. Desktop runs katago.exe; the web app can call an HTTP analysis server if you set a URL. There is no public free KataGo API.',
        EngineKind.logos =>
          'Go LLM for 19×19 boards. Uses Ollama or an OpenAI-compatible URL. Smaller boards and rejected answers use the built-in tutor.',
      };

  bool get isNeuralNet => this != EngineKind.heuristic;
}
