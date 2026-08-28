# Import LoGos into Ollama as logos-7b.
# Prefers a local GGUF; otherwise pulls hf.co/ikaankeskin/logos-7b-gguf.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\scripts\import_logos.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\import_logos.ps1 -Gguf C:\path\to\model.gguf

param(
  [string]$Gguf = "",
  [string]$Name = "logos-7b",
  [string]$HfRef = "hf.co/ikaankeskin/logos-7b-gguf:logos-7b-q8_0.gguf"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Gguf) {
  $Gguf = Join-Path $Root "engines\logos-7b-q8_0.gguf"
}

$ollama = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"
if (-not (Test-Path $ollama)) { $ollama = "ollama" }

[Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "User")
[Environment]::SetEnvironmentVariable("LOGOS_URL", "http://127.0.0.1:11434", "User")
[Environment]::SetEnvironmentVariable("LOGOS_MODEL", $Name, "User")
$env:OLLAMA_ORIGINS = "*"
$env:LOGOS_URL = "http://127.0.0.1:11434"
$env:LOGOS_MODEL = $Name

try { Invoke-RestMethod "http://127.0.0.1:11434/api/tags" | Out-Null } catch {
  Write-Host "Starting Ollama…"
  Start-Process $ollama -ArgumentList "serve" -WindowStyle Hidden
  Start-Sleep -Seconds 4
}

$names = @()
try { $names = @((Invoke-RestMethod "http://127.0.0.1:11434/api/tags").models.name) } catch {}
if ($names -contains "${Name}:latest" -or $names -contains $Name) {
  Write-Host "Ollama already has $Name"
  exit 0
}

if (Test-Path $Gguf) {
  $modelFile = Join-Path $env:TEMP "kaibitzer-logos.Modelfile"
  @"
FROM $Gguf
PARAMETER temperature 0.7
PARAMETER num_ctx 4096
PARAMETER num_predict 512
"@ | Set-Content -Encoding ascii $modelFile
  Write-Host "Creating Ollama model $Name from $Gguf"
  & $ollama create $Name -f $modelFile
  if ($LASTEXITCODE -ne 0) { throw "ollama create failed" }
} else {
  Write-Host "No local GGUF. Pulling $HfRef …"
  & $ollama pull $HfRef
  if ($LASTEXITCODE -ne 0) { throw "ollama pull failed" }
  & $ollama cp $HfRef $Name
  if ($LASTEXITCODE -ne 0) { throw "ollama cp failed" }
}

Write-Host "Ready. LOGOS_MODEL=$Name  LOGOS_URL=http://127.0.0.1:11434"
