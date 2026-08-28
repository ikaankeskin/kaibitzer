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
          'AlphaGo-line neural net via GTP. Needs katago.exe, a model, and a config (Windows desktop).',
        EngineKind.logos =>
          'Local Go LLM (YichuanMa/LoGos-7B). Serve it with Ollama, llama.cpp, or LM Studio.',
      };

  bool get isNeuralNet => this != EngineKind.heuristic;
}
