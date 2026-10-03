# Resume Kaibitzer — 3 October 2026

## Next planned development step

**Distill LoGos into a small language model that plays Go and explains moves locally on iPhone.** The user chose moves plus explanations (not a board-policy-only network), iPhone first, English and/or Chinese, with support limited to phones that can run it within measured memory limits.

Start by reading [the distillation design](docs/mobile-logos-distillation.md), then build a reviewed pilot corpus and measure an unfine-tuned student baseline. Proposed student: Qwen3-0.6B, adapter fine-tuning on the Mac, then 4-bit deployment via MLX Swift and a Flutter platform channel. The approximate 300 MB packed-weight estimate and under-1-GB complete-app peak memory target are unmeasured planning estimates. Determine supported iPhones from physical-device tests. Use Chinese for the initial corpus; add reviewed English explanations later.

### Resume checklist

1. Check current Git state, repository guidance, SDK/runtime versions, and local model/server availability. Preserve user changes.
2. Inspect the authors' LoGos distillation corpus (reported as 1K responses from a 32B teacher): verify format, provenance, dataset terms, and benchmark overlap before importing. The teacher model's license must not be assumed to cover external datasets. No external training dataset has been imported yet.
3. Prepare a diverse 500–1,000-example pilot of **19×19 Japanese-rules, komi 6.5, no-handicap** positions. Replay with this app's rules. Reject malformed/incomplete answers, wrong players, ambiguous/off-board/illegal moves, and unsupported positions.
4. Verify move quality with a fixed KataGo configuration and check explanation facts against the board. Keep LoGos as the teacher; record any different supervision explicitly. Legal moves alone are not training-ready.
5. Create game-disjoint train/validation/test splits, pin model and tokenizer revisions, and version the compact student board representation. Keep nearby positions/symmetries from one game in one split.
6. Measure base Qwen3-0.6B first, then run an adapter-training smoke test. Compare distilled and quantized models on move quality, factual explanations, illegal actions, fallback frequency, and play against the built-in tutor.
7. Integrate a passing model with MLX Swift on iPhone; measure peak memory, time to move, explanation latency, cancellation, thermal behavior, and offline play before declaring supported devices.

Do not describe a model as distilled/trained or phone-compatible until the corresponding training and evaluation have actually happened. No student model, adapter, or phone benchmark exists yet. Do not generate a large teacher corpus blindly: 1,000 responses at roughly 40 seconds each already imply about 11 hours before retries/rejections.

## Completed and verified

- Added a macOS runner; release build and native 9×9 built-in-tutor play were verified with Xcode 27.0. The sandbox allows outgoing network connections. External engine process launch/weight access remains unverified; start servers separately.
- Native Ollama connectivity was subsequently confirmed by the user's app console. LoGos receives up to 1,024 tokens on both supported APIs. A previously truncated 19×19 Q16 fixture completed at 603 tokens with White D16.
- Replies require a closed answer, correct player, explicit move, and legality. Logs distinguish answer rejection from transport failure and report concrete reasons.
- LoGos inference is restricted to 19×19; 9×9/13×13 use the tutor immediately. The teacher proposed off-board D17 on 9×9 even after an explicit bounds prompt. This remains an application support restriction; distillation has not solved smaller-board play.
- Added rules-backed teacher-example filtering and an offline review-queue tool. Seven unique local examples produced four rejections and three candidates awaiting move-quality/explanation review. No examples are approved training labels.
- Most recent validation: **54 Flutter tests pass**, static analysis passes; native release build passed before the offline-only distillation additions. Web release build passed during the initial reliability step. Nothing was deployed or submitted to an app store.

Relevant artifacts:

- [Teacher reliability investigation](docs/logos-reliability-investigation.md)
- [Distillation design](docs/mobile-logos-distillation.md)
- [Teacher review queue](outputs/distillation-review.jsonl)
- [Offline preparation tool](tool/prepare_distillation.dart)
- [Rules-backed filter](lib/distillation/teacher_example.dart)

## Local setup retained on this Mac

These are development-machine paths, not portable repository dependencies. Recheck existence before using them. Do not re-download the retained teacher weights unnecessarily.

- Flutter SDK: `/Users/ikaankeskin/Documents/Codex/2026-10-03/cr/work/tools/flutter`
- Ollama binary: `/Users/ikaankeskin/Documents/Codex/2026-10-03/cr/work/tools/ollama/ollama`
- Ollama models: `/Users/ikaankeskin/Documents/Codex/2026-10-03/cr/work/models`
- Teacher alias: `logos-7b`; retained server was at `http://127.0.0.1:11435`.
- Full Xcode now works. Do not accept licenses on the user's behalf.

```sh
flutter test
flutter analyze
flutter test tool/prepare_distillation.dart --no-pub
flutter run -d macos --dart-define=LOGOS_URL=http://127.0.0.1:11435 --dart-define=LOGOS_MODEL=logos-7b
```

If the retained server is unavailable, restart it using the existing model directory:

```sh
OLLAMA_MODELS=/Users/ikaankeskin/Documents/Codex/2026-10-03/cr/work/models OLLAMA_HOST=127.0.0.1:11435 /Users/ikaankeskin/Documents/Codex/2026-10-03/cr/work/tools/ollama/ollama serve
```

The previous native build is `build/macos/Build/Products/Release/Kaibitzer.app` (ignored, not stored in Git). It was built with port 11435; the source default remains 11434.

Development branch is `master`. `prod` triggers GitHub Pages publication; do not merge to or push `prod` as part of this planned work unless the user requests a release.
