enum EngineKind {
  heuristic,
  katago,
  logos,
}

extension EngineKindLabels on EngineKind {
  String get title => switch (this) {
        EngineKind.heuristic => 'Built-in tutor',
        EngineKind.katago => 'KataGo',
        EngineKind.logos => 'LoGos-7B',
      };

  String get summary => switch (this) {
        EngineKind.heuristic =>
          'On-device tactics and opening sense. Always available, modest strength.',
        EngineKind.katago =>
          'Neural net. Desktop runs katago.exe; the web app can call an HTTP analysis server if you set a URL. There is no public free KataGo API.',
        EngineKind.logos =>
          'Go LLM (YichuanMa/LoGos-7B). Tries local Ollama, or any OpenAI-compatible URL you set. If nothing answers, the tutor plays.',
      };

  bool get isNeuralNet => this != EngineKind.heuristic;
}
