# Publish the Kaibitzer LoGos GGUF

Original model: [YichuanMa/LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B) (Apache-2.0).

## Hugging Face (source of truth)

Repo: [ikaankeskin/logos-7b-gguf](https://huggingface.co/ikaankeskin/logos-7b-gguf)

```bash
hf upload ikaankeskin/logos-7b-gguf docs/logos-gguf-card.md README.md
hf upload ikaankeskin/logos-7b-gguf engines/logos-7b-q8_0.gguf logos-7b-q8_0.gguf
```

Consumers:

```bash
ollama pull hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf
ollama cp hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf logos-7b
```

## Ollama library (optional)

Needs an [ollama.com](https://ollama.com) account and an Ollama public key in Settings.

```bash
ollama cp logos-7b ikaankeskin/logos-7b
ollama push ikaankeskin/logos-7b
```

Consumers: `ollama pull ikaankeskin/logos-7b`.

The library README is **not** part of `ollama push`. While signed in as the owner, paste `docs/logos-ollama-readme.md` into the Readme editor on https://ollama.com/ikaankeskin/logos-7b (or POST `readme=` to that URL). Optional one-line summary (max 255 chars): `Q8_0 GGUF of YichuanMa/LoGos-7B: a 7B Go reasoning model. Not a new training run.`
