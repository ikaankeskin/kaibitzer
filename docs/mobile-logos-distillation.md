# LoGos → small iPhone language model

Status: design and tested teacher-data filtering, not a trained student. The user wants local Go moves with explanations, iPhone first, English and/or Chinese, on phones with sufficient memory. This document proposes the next experiment; strength and phone performance have not been demonstrated.

## Student and deployment proposal

Start with **Qwen3-0.6B**, using its native chat template and non-thinking mode for a move followed by a short explanation. Its model card describes a multilingual 0.6-billion-parameter causal language model and explicitly supports disabling thinking. [Qwen model card](https://huggingface.co/Qwen/Qwen3-0.6B).

At four bits per parameter, 600 million parameters account for approximately 300 MB of packed weight values. Scales, unquantized tensors, tokenizer, KV cache, GPU buffers, and Flutter add overhead. Target a complete-app peak below **1 GB** initially, with a bounded context of roughly 2,048 tokens and a short response budget, then measure it. These are engineering targets, not measured resource requirements or a compatibility promise. Ship a supported-device list only after physical-iPhone memory, latency, and sustained-temperature tests; available RAM alone does not establish safe app allocation.

Use **MLX LM** for local adapter training on the M5 Mac, then fuse the adapter, quantize, and integrate **MLX Swift LM** through a Flutter platform channel. Apple demonstrates this training-to-Swift path; the official example collection includes an iOS/macOS chat application. Pin a tested package release, compatible iOS deployment target, tokenizer, and student revision before implementation. [Apple MLX session](https://developer.apple.com/videos/play/wwdc2025/298/), [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm), [Swift examples](https://github.com/ml-explore/mlx-swift-examples).

Keep a 1–2B student as an experimental comparison only if 0.6B does not learn enough. A smaller language model fitting in memory does not imply adequate Go strength or faithful explanations. Benchmark the unfine-tuned student before distillation so improvement can be measured.

## What is distilled

Use **response distillation**: LoGos labels positions; the student learns those reviewed outputs via supervised fine-tuning. This transfers teacher behavior through training examples. It does not shrink LoGos's architecture or obtain its move-policy logits. Quantization happens separately after training and evaluation.

The pilot target is a strict output object containing `color`, `move`, and a short `explanation`. The app validates the move independently and displays the explanation only with the accepted move. For low latency, generate the move first; a streamed explanation must not change the committed move. Constrain generated coordinates to legal actions where the runtime supports it, and retain the deterministic rules check and fallback regardless.

Use Chinese for the first corpus to preserve the teacher language. Add reviewed English explanations afterward; translation must preserve stones, coordinates, captures, and side-to-play. Avoid training on long theatrical commentary or unverified win-rate numbers. Student output should be concise reasoning for the player, not a verbatim copy of every teacher token.

Initially train/evaluate on **19×19, Japanese rules, komi 6.5, no handicap**. This matches the retained local fixtures. Smaller boards, other rules, and handicap require separate valid data and evaluation. Our teacher repeatedly emitted 19×19 coordinates on 9×9, so cropping a board or relabeling coordinates is not a valid way to create smaller-board examples.

## Data pipeline

1. Replay positions through Kaibitzer's own Go rules. Store source game identity, moves, captures/current board, side, rules, komi, and handicap. Use an authoritative current board with a compact coordinate-labeled representation for student inputs; include legal actions and sufficient history for ko/superko. Version that representation and use it identically for training and inference.
2. Query the retained LoGos weights with reproducible model identity, template, sampling seed, and completion metadata. Keep rejected outputs for diagnostics. Start with opening, tactical, capture, ko, midgame, and endgame positions rather than repeatedly sampling empty boards.
3. Reject unfinished/malformed answers, wrong players, ambiguous moves, off-board/occupied/suicidal/ko-illegal actions, finished games, and unsupported teacher board sizes. Legality is a necessary filter, not a measure of move quality.
4. Check move quality with a fixed KataGo evaluation configuration and inspect explanation claims against the actual board. Record verifier identity and results. KataGo is a verifier of LoGos labels here, not silently substituted as the training teacher. If its moves become targets, label that as mixed supervision and evaluate that experiment separately.
5. Review concise explanations, including distinctions between stones currently present and hypothetical variations. A legal move with hallucinated prose must not enter explanation training. The current tool marks legal examples `needs_review`, not accepted training data.
6. Deduplicate positions and divide train/validation/test by **source game**, before sampling adjacent positions or applying symmetries. Keep teacher-generated labels and transformations from the same game in the same split. Do not train on the published benchmark positions or overlap them with training games.

The authors list a **1K distillation corpus attributed to their 32B teacher**, a 100K SFT dataset, and a 1K evaluation benchmark. Inspect schema, provenance, game overlap, and each dataset's applicable terms before use; the repository README contains a research/noncommercial notice while its code/model metadata also shows Apache-2.0. Do not assume the model's license covers all datasets. None of those external datasets has been imported into this project. [Author repository](https://github.com/Entarochuan/InternGo-LoGos), [rollout dataset](https://huggingface.co/datasets/YichuanMa/LoGos-Rollout-1K), [teacher model](https://huggingface.co/YichuanMa/LoGos-7B).

The 1K corpus is useful as a pilot candidate pool; it is not evidence that 1,000 examples will produce a strong mobile opponent. Generating 1,000 local responses at the observed roughly 40 seconds each would take about **11 hours**, before retries and quality rejection. Reuse suitable published examples where permitted and measure local label yield before generating a large corpus.

## Training and evaluation experiment

First create a reviewed 500–1,000-example pilot spanning the above position types. Train low-rank adapters rather than all student weights. Use assistant-only training loss with the student's own chat template; test that the formatting/non-thinking mode at inference matches training. Keep full-precision/fused and quantized checkpoints for comparison. Choose adapter rank, batch size, and learning rate from a short measured smoke run, not an assumed memory budget. Unload LoGos before training the student to free memory.

Measure the base student, distilled student, and quantized distilled student on the same held-out games: correct player, explicit valid move, pre-mask illegal-move rate, verifier move quality, explanation factuality, and head-to-head performance against the built-in tutor. Track agreement with LoGos separately from playing strength. Report fallback-assisted results separately so the tutor cannot hide student failures.

On a physical iPhone, measure model load time, peak app memory, prompt processing, time to move, explanation generation, cancellations, thermal behavior, and offline operation over multiple games. Run decoding off the UI thread; support cancellation when a game changes, unload on memory pressure, and reject stale results. Continue to offer the tutor when the model is unavailable or unsupported.

## Implemented first step

- `lib/distillation/teacher_example.dart`: rules-backed teacher-label filter with explicit rejection reasons, raw provenance, and separate unreviewed quality/explanation flags. It deliberately emits no teacher win-rate target.
- `tool/prepare_distillation.dart`: offline adapter for the existing local inference evidence. It checks exact prompt replay, deduplicates identical prompt/response pairs, and writes a review queue. It makes no inference calls and downloads no weights.
- `outputs/distillation-review.jsonl`: seven unique examples; four rejected and three pending review. These few diagnostics are not a training dataset.
- `test/teacher_example_test.dart`: legality, player, ambiguity, incomplete-answer, pass, smaller-board, and review-status checks.

Reproduce the queue:

```sh
flutter test tool/prepare_distillation.dart --no-pub
```

Optionally specify `--dart-define=DISTILLATION_REVIEW_OUTPUT=/tmp/teacher-review.jsonl`. Training, new student weights, native MLX integration, and physical-iPhone benchmarking remain to be implemented. The immediate next milestone is a reviewed pilot corpus and a measured base-student baseline; the current project has no distilled phone model yet.
