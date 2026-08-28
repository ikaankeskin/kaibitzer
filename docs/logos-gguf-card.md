---
license: apache-2.0
base_model: YichuanMa/LoGos-7B
pipeline_tag: text-generation
tags:
  - gguf
  - go
  - weiqi
  - qwen2
  - ollama
---

# LoGos-7B GGUF (Kaibitzer)

GGUF conversion of [YichuanMa/LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B) for local inference with [Ollama](https://ollama.com) and llama.cpp. Used by the [Kaibitzer](https://github.com/ikaankeskin/kaibitzer) Go app.

This is a **quantized conversion**, not a new training run. Credit and license follow the original model (Apache-2.0).

## Files

| File | Quant | Size | Notes |
| --- | --- | --- | --- |
| `logos-7b-q8_0.gguf` | Q8_0 | ~8.1 GB | Verified in Kaibitzer via Ollama on an RTX 3080 Laptop (~8 GB VRAM, ~2.3 tok/s, long CoT) |

Q4_K_M is not published yet. Requantizing from Q8_0 is a quality loss; a proper Q4 will be converted from higher precision later.

## Ollama

```bash
ollama pull hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf
ollama cp hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf logos-7b
```

Then Kaibitzer defaults (`LOGOS_URL=http://127.0.0.1:11434`, `LOGOS_MODEL=logos-7b`) work. For Chrome, set `OLLAMA_ORIGINS=*`.

## Conversion

From the original Hugging Face safetensors, using llama.cpp `convert_hf_to_gguf.py` to Q8_0. Direct Ollama safetensors import of `Qwen2ForCausalLM` failed on Ollama 0.18 (unsupported architecture); GGUF is the supported path.

Context length used in Kaibitzer: **4096**. `num_predict` 512.

## Prompt

LoGos expects its **Chinese** training template: move record (`1.X-Q16`), board matrix (`1` black, `-1` white, `0` empty), then boxed `下一步位置`. Kaibitzer builds that prompt for you.

## License

Apache-2.0, same as [YichuanMa/LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B).
