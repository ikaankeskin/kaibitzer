# LoGos-7B (Q8_0 GGUF)

Local **8-bit GGUF** conversion of [YichuanMa/LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B) for Ollama and llama.cpp. Used by [Kaibitzer](https://github.com/ikaankeskin/kaibitzer).

This is **not a new training run**. Weights come from the original model; they are stored as **Q8_0** so they fit on a consumer GPU. Credit, paper, and Apache-2.0 license follow the original authors.

Hugging Face file: [ikaankeskin/logos-7b-gguf](https://huggingface.co/ikaankeskin/logos-7b-gguf)

## What is LoGos?

**LoGos-7B** is a 7B language model for **Go (weiqi) reasoning**: it reads a board position, thinks in a long chain-of-thought, and proposes the next move (color, coordinate, and a win-rate estimate).

It is built on **Qwen2.5-7B**, then mixed **cold-start** training plus **GRPO** so professional Go knowledge and long-CoT reasoning transfer onto actual games. It is a **tutor / analysis** model, not a replacement for a full-strength engine like KataGo.

Paper: [Mixing Expert Knowledge: Bring Human Thoughts Back To the Game of Go](https://arxiv.org/abs/2601.16447) (Ma et al., 2026).

Original weights are BF16 safetensors (~14 GB). This Ollama model is the same weights in **Q8_0 GGUF** (~8.1 GB).

## Quantization

This library model is **Q8_0** (8-bit). That is a light quant: small quality drop vs the original BF16, much closer to the original than a 4-bit (Q4) file.

It is **not** the original Hugging Face safetensors, and it is **not** Q4. A Q4 built by requantizing this Q8 file would lose more quality.

Verified in Kaibitzer via Ollama on an RTX 3080 Laptop (~8 GB VRAM, ~2.3 tok/s on long CoT). Generation is slow at Q8; that is expected.

## Run it

```bash
ollama pull ikaankeskin/logos-7b
```

Kaibitzer defaults: `LOGOS_URL=http://127.0.0.1:11434`, `LOGOS_MODEL=logos-7b`. For the Chrome/web client, set `OLLAMA_ORIGINS=*`.

Same file from Hugging Face:

```bash
ollama pull hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf
ollama cp hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf logos-7b
```

## Prompt

LoGos expects its **Chinese** training template: move record (`1.X-Q16`), board matrix (`1` black, `-1` white, `0` empty), then boxed `下一步位置`. Kaibitzer builds that prompt for you. See the [original model card](https://huggingface.co/YichuanMa/LoGos-7B) for the full template.

Kaibitzer uses context **4096** and `num_predict` 512.

## License

Apache-2.0, same as [YichuanMa/LoGos-7B](https://huggingface.co/YichuanMa/LoGos-7B).

```
@misc{ma2026mixingexpertknowledgebring,
      title={Mixing Expert Knowledge: Bring Human Thoughts Back To the Game of Go},
      author={Yichuan Ma and Linyang Li and Yongkang Chen and Peiji Li and Jiasheng Ye and Qipeng Guo and Dahua Lin and Kai Chen},
      year={2026},
      eprint={2601.16447},
      archivePrefix={arXiv},
      primaryClass={cs.CL},
      url={https://arxiv.org/abs/2601.16447},
}
```
