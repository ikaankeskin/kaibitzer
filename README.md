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
| **Chrome / Edge** (`flutter run -d chrome`) or **GitHub Pages** | Yes | Yes, if Ollama (or another OpenAI-compatible URL) is reachable from the browser | Only if you set a KataGo **HTTP** URL |
| **Android / iOS** | Yes | Remote OpenAI-compatible URL if you set one | HTTP URL only; no in-app binary |

**Rule of thumb:** the goban and tutor run in the browser with no extras. Local LoGos needs Ollama (CORS allowed) or a URL you provide. Local KataGo needs a native binary; the web build can only talk to an HTTP analysis server if you have one. There is **no public free KataGo or LoGos-7B inference API** with CORS today (Hugging Face serverless needs a token and a GPU; Ollama.com is a download, not a hosted chat API).

VRAM for the verified Q8 GGUF is about **8 GB**. A 6–8 GB GPU can still run a smaller quant; CPU-only Ollama works but is slow.

## Play on the web (GitHub Pages)

Each push to **`prod`** builds the Flutter web app and deploys to GitHub Pages:

**https://ikaankeskin.github.io/kaibitzer/**

First time: in the GitHub repo, Settings → Pages → Source **GitHub Actions**. After that, `.github/workflows/deploy-pages.yml` publishes on every push to `prod`. Tags (`v0.1.0`, …) mark releases; they do not deploy by themselves.

`master` is development. Merge (or cherry-pick) into `prod` when you want the site updated. Do not push WIP to `prod`.

The published game is the **base version**: vs computer, pass-and-play, hints, and the built-in tutor. LoGos and KataGo stay in the engine list. They are used only when a server answers; otherwise that turn uses the tutor.

| Engine on the web | What it tries | If it fails |
| --- | --- | --- |
| Built-in tutor | On-device | — |
| LoGos-7B | `http://127.0.0.1:11434` (local Ollama), or `?logos_url=` / setup field / `LOGOS_URL` | Tutor for that move |
| KataGo | `?katago_url=` / setup field / `KATAGO_URL` HTTP analysis API | Tutor |

For local Ollama from the GitHub Pages origin, allow CORS:

```bash
# Windows
set OLLAMA_ORIGINS=https://ikaankeskin.github.io
ollama serve
```

Optional query string: `?logos_url=https://your-openai-compatible/v1&logos_model=…&logos_key=…&katago_url=https://…`

Do not put secrets in a public URL unless you accept that they are visible.

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
| `LOGOS_API_KEY` | Optional Bearer token for a hosted OpenAI-compatible API |
| `OLLAMA_ORIGINS` | Set to `*` or your Pages origin so Chrome can call Ollama |

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

Production can point `LOGOS_URL` / `LOGOS_MODEL` / `LOGOS_API_KEY` at a hosted OpenAI-compatible API. No free public host currently serves LoGos-7B.

### KataGo

[KataGo](https://github.com/lightvector/KataGo) via GTP. The app looks for `engines/katago/katago` (or `katago.exe`) and honors:

| Variable | Meaning |
| --- | --- |
| `KATAGO_PATH` | Binary |
| `KATAGO_HOME` | Working directory |
| `KATAGO_MODEL` | Network (`.bin.gz`) |
| `KATAGO_CONFIG` | GTP config |
| `KATAGO_URL` | Optional HTTP analysis server (web, or desktop fallback) |

**Windows:** OpenCL zip from KataGo releases, plus a `kata1-b18c384nbt` network. First launch autotunes the GPU.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_local_engines.ps1
```

That script is **Windows-only** (downloads the Windows OpenCL build). On macOS or Linux, install a matching KataGo release yourself and set `KATAGO_PATH`.

Chrome cannot spawn `katago.exe`. On the web, KataGo only works if you provide an HTTP analysis server URL. If that URL is missing or down, the tutor plays.

## LoGos from scratch (advanced)

Only needed if you do not already have a GGUF:

1. Download [YichuanMa/LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B) (~14 GB safetensors) into `engines/logos-7b/`.
2. Convert with [llama.cpp](https://github.com/ggml-org/llama.cpp) `convert_hf_to_gguf.py` to `engines/logos-7b-q8_0.gguf`.
3. Run `scripts/import_logos.ps1` or `scripts/import_logos.sh`.

Do **not** `ollama create` from the raw safetensors folder on current Ollama (Qwen2ForCausalLM / MLX runner error). Use GGUF.

## Sharing the converted model

The Q8 GGUF is on [Hugging Face](https://huggingface.co/ikaankeskin/logos-7b-gguf) and as [ikaankeskin/logos-7b](https://ollama.com/ikaankeskin/logos-7b) on the Ollama library.

```bash
ollama pull ikaankeskin/logos-7b
# or from the Hub file:
ollama pull hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf
ollama cp hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf logos-7b
```

You can still import a local GGUF with `scripts/import_logos.ps1` / `import_logos.sh`.

## Versions, branches, and later store apps

The app is **0.x** SemVer (`pubspec.yaml` + [CHANGELOG.md](CHANGELOG.md)). Right now that is **0.1.0**: the first public web cut. The `+N` build number is what Android/iOS stores will use later.

| Branch | Role |
| --- | --- |
| `master` | Day-to-day development |
| `prod` | What GitHub Pages ships. Tag releases as `v0.1.0`, `v0.2.0`, … |

To ship a web release: bump `version` and `lib/app_version.dart` default, add a CHANGELOG entry, merge to `prod`, tag `vX.Y.Z`, push `prod` and the tag.

### Phones and tablets (after the website)

The same Flutter project already has Android and iOS runners. Store listing is a later **0.2+** step, once the GitHub Pages game feels right:

1. Play the web build; fix the tutor, layout, and rules.
2. `flutter run -d android` / `-d ios` (or Windows if you want a desktop installer too).
3. App icons, splash, package id (`com.ikaankeskin.kaibitzer` or similar), signing keys.
4. Play Console / App Store Connect accounts, privacy text, and screenshots.

We are not submitting store builds in 0.1.0.

## Project layout

```
lib/           Game engine, UI, LoGos/KataGo clients
scripts/       Windows KataGo fetch, LoGos Ollama import
engines/       Local weights (gitignored)
modelfiles/    Ollama Modelfile templates
```
