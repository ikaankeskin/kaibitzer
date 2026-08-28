# Kaibitzer

A Flutter Go app: play on a customizable goban, switch rule variants, play a friend or a computer, and ask a sideline coach for recommended moves.

The **built-in tutor** always works. **LoGos-7B** and **KataGo** are optional local engines. You do not need them to play; turn them on only where the machine can actually run them.

## Features

- **Vs computer** or pass-and-play, with a choice of engine
- **Hints:** **H** (or `/`) for recommended moves, then **1 2 3** to play them
- **Engine console** (terminal icon): model switches, the prompt sent to LoGos, Ollama timings, and the raw reply
- **Board sizes** 5×5–21×21 (presets 9, 13, 19)
- **Rules:** Japanese, Chinese, AGA, New Zealand
- **Capture Go**, handicap, komi, board themes
- Coach chat for “who’s ahead”, weak groups, and rules questions

## What runs where

Kaibitzer is a Flutter app. The **game and tutor** run everywhere Flutter does. Heavy engines are extra processes or HTTP servers, so support is per platform.

| Surface | Built-in tutor | LoGos-7B (local LLM) | KataGo (GTP binary) |
| --- | --- | --- | --- |
| **Windows desktop** (`flutter run -d windows`) | Yes | Yes — Ollama (NVIDIA/AMD/CPU) | Yes — OpenCL build + network |
| **macOS desktop** (`flutter run -d macos`) | Yes | Yes — Ollama (Metal) | Yes — download a **macOS** KataGo build, not the Windows zip |
| **Linux desktop** | Yes | Yes — Ollama | Yes — OpenCL, CUDA, or Eigen build |
| **Chrome / Edge** (`flutter run -d chrome`) | Yes | Yes — browser talks to Ollama over HTTP | No — the browser cannot spawn `katago` |
| **Android / iOS** | Yes | Not as a local 7B yet — use a remote OpenAI-compatible URL later | No |

**Rule of thumb:** local LoGos needs Ollama (or llama.cpp / LM Studio) on the **same machine** as the app, or a reachable URL. Local KataGo needs a native binary. Phones and the web browser never run KataGo in-process.

VRAM for the verified Q8 GGUF is about **8 GB**. A 6–8 GB GPU can still run a smaller quant; CPU-only Ollama works but is slow.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.9+ (Dart 3.9)
- Optional: [Ollama](https://ollama.com/download) 0.18+ for LoGos
- Optional: [KataGo](https://github.com/lightvector/KataGo/releases) for the neural-net opponent
- Optional: Visual Studio **Desktop development with C++** on Windows if the KataGo OpenCL binary needs the MSVC runtime

Do not commit weights. `engines/` binaries and `*.gguf` are gitignored.

## Run the app

From the repo root:

```bash
flutter test
flutter run -d chrome      # tutor + LoGos (if Ollama is up)
flutter run -d windows     # tutor + LoGos + KataGo
flutter run -d macos
```

If `flutter` is not on `PATH`, add your SDK `bin` directory first.

Play-screen keys: **H** hint, **1 2 3** play a suggestion. Robot icon = engine, speed icon = difficulty, terminal icon = engine console.

## Engines

Pick an engine on **New game** or from the robot icon during play. Hints use the same engine as the opponent. Illegal or empty LoGos replies fall back to the built-in tutor for that turn.

### Built-in tutor

Always available. Opening sense and tactics for teaching — not AlphaGo strength.

### LoGos-7B

[LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B) (Apache-2.0, Qwen2.5-7B Go specialist) is served as an OpenAI-compatible chat API.

**Local setup:** pull the [GGUF conversion](https://huggingface.co/ikaankeskin/logos-7b-gguf) into Ollama (or import a GGUF you already have). Experimental Ollama safetensors import of Qwen2 failed; GGUF is the working path.

Default endpoint: `http://127.0.0.1:11434`, model name `logos-7b`.

| Variable | Meaning |
| --- | --- |
| `LOGOS_URL` | Server root (`http://127.0.0.1:11434` or `http://127.0.0.1:11434/v1`) |
| `LOGOS_MODEL` | Model id (default `logos-7b`) |
| `OLLAMA_ORIGINS` | Set to `*` so Chrome can call Ollama |

On **Windows / macOS / Linux desktop**, the app starts `ollama serve` if port 11434 is down. **Chrome** cannot spawn Ollama — start it yourself, with CORS allowed:

```bash
# Windows (user env) or export on macOS/Linux
set OLLAMA_ORIGINS=*
ollama serve
```

Install the model (downloads ~8 GB the first time):

```bash
ollama pull hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf
ollama cp hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf logos-7b
```

Or from this repo if you already have `engines/logos-7b-q8_0.gguf`:

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\scripts\import_logos.ps1
```

```bash
# macOS / Linux — pulls from Hugging Face if no local GGUF
chmod +x scripts/import_logos.sh
./scripts/import_logos.sh
```

LoGos is trained on a **Chinese** board template (move list + `1 / -1 / 0` matrix). The app sends that format. Expect **a few minutes per move** at Q8 on a 3080-class GPU (long chain-of-thought, ~2 tok/s in our test).

Production can point `LOGOS_URL` / `LOGOS_MODEL` at a hosted API instead of localhost.

### KataGo

[KataGo](https://github.com/lightvector/KataGo) via GTP. The app looks for `engines/katago/katago` (or `katago.exe`) and honors:

| Variable | Meaning |
| --- | --- |
| `KATAGO_PATH` | Binary |
| `KATAGO_HOME` | Working directory |
| `KATAGO_MODEL` | Network (`.bin.gz`) |
| `KATAGO_CONFIG` | GTP config |

**Windows:** OpenCL zip from KataGo releases, plus a `kata1-b18c384nbt` network. First launch autotunes the GPU.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_local_engines.ps1
```

That script is **Windows-only** (downloads the Windows OpenCL build). On macOS or Linux, install a matching KataGo release yourself and set `KATAGO_PATH`.

Chrome cannot use KataGo.

## LoGos from scratch (advanced)

Only needed if you do not already have a GGUF:

1. Download [YichuanMa/LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B) (~14 GB safetensors) into `engines/logos-7b/`.
2. Convert with [llama.cpp](https://github.com/ggml-org/llama.cpp) `convert_hf_to_gguf.py` to `engines/logos-7b-q8_0.gguf`.
3. Run `scripts/import_logos.ps1` or `scripts/import_logos.sh`.

Do **not** `ollama create` from the raw safetensors folder on current Ollama (Qwen2ForCausalLM / MLX runner error). Use GGUF.

## Sharing the converted model

The model card is live at [ikaankeskin/logos-7b-gguf](https://huggingface.co/ikaankeskin/logos-7b-gguf). The Q8 GGUF upload to Hugging Face and `ollama push ikaankeskin/logos-7b` were paused mid-transfer; resume later with `scripts/publish_logos.md`.

Until those finish, import a local GGUF (`scripts/import_logos.ps1` / `import_logos.sh`) or use an Ollama model already named `logos-7b`.

When the Hub file is complete:

```bash
ollama pull hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf
ollama cp hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf logos-7b
```

## Project layout

```
lib/           Game engine, UI, LoGos/KataGo clients
scripts/       Windows KataGo fetch, LoGos Ollama import
engines/       Local weights (gitignored)
modelfiles/    Ollama Modelfile templates
```
