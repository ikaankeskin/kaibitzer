#!/usr/bin/env bash
# Import LoGos into Ollama as logos-7b.
# Prefers a local GGUF; otherwise pulls hf.co/ikaankeskin/logos-7b-gguf.
# Usage: ./scripts/import_logos.sh [path/to/model.gguf]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GGUF="${1:-$ROOT/engines/logos-7b-q8_0.gguf}"
NAME="${LOGOS_MODEL:-logos-7b}"
HF_REF="${LOGOS_HF_REF:-hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf}"

export OLLAMA_ORIGINS="${OLLAMA_ORIGINS:-*}"
export LOGOS_URL="${LOGOS_URL:-http://127.0.0.1:11434}"
export LOGOS_MODEL="$NAME"

if ! curl -sf "$LOGOS_URL/api/tags" >/dev/null; then
  echo "Starting Ollama…"
  ollama serve >/dev/null 2>&1 &
  sleep 4
fi

if curl -sf "$LOGOS_URL/api/tags" | grep -q "\"$NAME\""; then
  echo "Ollama already has $NAME"
  exit 0
fi

if [[ -f "$GGUF" ]]; then
  TMP="$(mktemp)"
  cat > "$TMP" <<EOF
FROM $GGUF
PARAMETER temperature 0.7
PARAMETER num_ctx 4096
PARAMETER num_predict 512
EOF
  echo "Creating Ollama model $NAME from $GGUF"
  ollama create "$NAME" -f "$TMP"
  rm -f "$TMP"
else
  echo "No local GGUF. Pulling $HF_REF …"
  ollama pull "$HF_REF"
  ollama cp "$HF_REF" "$NAME"
fi

echo "Ready. LOGOS_MODEL=$NAME  LOGOS_URL=$LOGOS_URL"
