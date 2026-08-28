# Changelog

All notable changes to Kaibitzer are listed here. Version numbers follow [SemVer](https://semver.org/) while the app is in **0.x** (the public API can still change).

The `+N` suffix in `pubspec.yaml` is the store build number (Android `versionCode` / iOS `CFBundleVersion`).

## 0.1.0 — 2026-08-28

First public cut: a playable **web** game.

- Goban, rule variants, vs computer or pass-and-play, on-device tutor and hints
- Optional LoGos-7B (Ollama or any OpenAI-compatible URL) and KataGo (desktop binary or HTTP analysis URL)
- If those servers are missing, the tutor still plays
- GitHub Pages deploy from the `prod` branch
