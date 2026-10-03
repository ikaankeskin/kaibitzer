# LoGos reliability investigation — 3 October 2026

The first change rejects unreliable move extraction: a completed `<answer>` must identify the current player, and the move must be explicit. The existing legal-move check and built-in tutor fallback remain in use for moves and hints. This does not establish model board understanding or validate its win-rate claims.

## Prompt/template evidence

The [original model card](https://huggingface.co/YichuanMa/LoGos-7B) tokenizes concatenated system and user text directly. The retained `logos-7b` Ollama template also concatenates message contents with no chat-role markers. With seed 4, temperature 0.2, and 512 output tokens, `/api/chat` and raw `/api/generate` produced identical response text on the `Q16` fixture. No template change is justified by this comparison. The app adds an explicit next-player sentence to the published prompt; it was present in every probe and did not prevent the empty-board wrong-player reply.

The app's board rows run from rank 19 to rank 1, consistent with the model card's `y = 19 - rank` conversion. Tests replay all recorded positions and compare their complete prompts/matrices with app serialization, including a captured stone and a pass. No serialization defect was found in these fixtures. The trained model's broader suitability for 9×9/13×13 boards, handicap positions, and long games remains unmeasured.

## Local inference results

Existing Q8 weights were reused on the M5 MacBook Air (24 GB), Ollama 0.35.1. Every probe used temperature 0.2, seed 4, and a 512-token limit. These are diagnostic examples, not independent strength samples. Raw responses, prompts, and API timing fields are in [logos-fidelity.json](../outputs/logos-fidelity.json); template and model metadata are in [logos-model-metadata.json](../outputs/logos-model-metadata.json).

| Position | Expected side | Endpoint | Wall | Tokens/end | Result under new guard |
| --- | --- | --- | --- | --- | --- |
| Empty | Black | chat | 38.78 s | 512/length | Reject White D16; fallback |
| Q16 | White | chat | 34.37 s | 512/length | No closed answer; fallback |
| Q16 | White | raw | 34.18 s | 512/length | Identical to chat; fallback |
| Q16, D4 | Black | chat | 39.23 s | 512/length | Accept legal Black Q3 |
| D16, Q4, C16, D15, C17, C15, pass, B16 | Black | chat | 41.24 s | 480/stop | Accept legal Black E15 |
| C16, C15, Q16, D16, Q4, C17, pass, B16 | Black | chat | 35.63 s | 512/length | No closed answer; fallback |

The empty-board commentary describes nonexistent stones. The one-stone response recognizes Q16 and White to play, but mislabels some coordinates and never reaches an answer. The two-stone response names the correct player but calls Q3 a star point. The final fixture captures C16: the board matrix correctly removes it, yet the model describes it and nonexistent P4 as existing Black stones. Its narrative also counts Black's pass as a placement. The first tactical fixture leaves a connected Black group alive; it is not a capture fixture.

Thus, accepting a legal coordinate is insufficient evidence of board fidelity. The change prevents the observed wrong-player and reasoning-only replies from becoming moves/hints; it cannot catch hallucinations in otherwise valid answers. A reply hitting the token limit can still be accepted if its answer closed before later commentary was cut off. Increasing the cap or rewriting the prompt has not been shown to repair fidelity and is deferred.

## Validation and reproduction

- 42 Flutter tests pass, including both HTTP response formats, wrong/missing/conflicting players, unfinished answers, prose coordinates, pass handling, and six actual inference-response replays.
- Flutter static analysis passes.
- Release web build passes. Interactive gameplay was not checked in this step.
- Flutter 3.47.6 resolves newer compatible packages for testing; automatic lockfile and analysis-option migrations were restored to keep this change focused.

To repeat inference against an already-running local server (no downloads):

```sh
python3 scripts/logos_fidelity_probe.py --url http://127.0.0.1:11435 --model logos-7b --output /tmp/logos-fidelity-repeat.json
```

Run Flutter tests first to verify fixture prompts still match the app. The repeat script uses the saved prompts and does not verify another server's chat template; inspect that server's `/api/show` separately.

## Native macOS status

Full Xcode is now installed: `xcode-select -p` points to `/Applications/Xcode.app/Contents/Developer`, and `xcodebuild -version` reports Xcode 27.0 (27A266a). The earlier missing-Xcode report is stale. At the time of the initial reliability step, this repository had no `macos/` runner. After the user confirmed Xcode readiness, the macOS runner was generated with Flutter 3.47.6 and outbound network entitlements added to debug/profile and release configurations. App Sandbox remains enabled. `flutter build macos --release --dart-define=LOGOS_URL=http://127.0.0.1:11435` succeeded (44.2 MB), and the resulting `Kaibitzer.app` launched. Native UI smoke testing started a 9×9 built-in-tutor game: Black C7 received White G7. All 42 tests and static analysis passed again.

The release app is at `build/macos/Build/Products/Release/Kaibitzer.app`. This build targets the retained local Ollama server on port 11435; the normal source default remains port 11434. Native LoGos network requests have not been exercised interactively. External Ollama/KataGo executable launch and access to engine weights remain unverified under App Sandbox; start the engine server separately and use an HTTP endpoint. No licenses were accepted, and nothing was deployed or published.

## Follow-up: native fallback report

After the native app successfully reached Ollama but rejected a 512-token reply, the answer budget was increased to 1,024 for both API formats. The same 19×19 Q16 fixture completed at 603 tokens, correctly naming White and legal D16. A 9×9 C7 fixture completed at 435 tokens but proposed off-board D17. An explicitly bounded, answer-only 9×9 diagnostic prompt still generated reasoning with D17/D16 and hit its 256-token cap. Accordingly, the engine now routes 9×9/13×13 directly to the tutor and labels LoGos as 19×19 in engine selection. This is an application support restriction based on observed failures, not a claim that every possible smaller-board prompt must fail.

Answer validation uses distinct reply-rejection logs with concrete reasons and preserves API termination metadata. Transport failures retain request-failure logs. New tests cover both termination formats, updated budgets, log classification, and smaller-board routing without HTTP calls. The existing guard remains; model board understanding and commentary accuracy are still not assured. Evidence: `outputs/logos-budget-probes.json`, `outputs/logos-concise-probe.json`.
