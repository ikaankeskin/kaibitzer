# Download KataGo + LoGos-7B and leave local inference ready for Kaibitzer.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $PSScriptRoot) { $Root = "C:\Users\ikaan\Kaibitzer" }
$Engines = Join-Path $Root "engines"
$KataDir = Join-Path $Engines "katago"
New-Item -ItemType Directory -Force -Path $KataDir | Out-Null

function Get-File($Url, $Dest) {
  if ((Test-Path $Dest) -and ((Get-Item $Dest).Length -gt 1MB)) {
    Write-Host "Already have $Dest"
    return
  }
  Write-Host "Downloading $Url"
  curl.exe -L --retry 8 --retry-all-errors -C - -o $Dest $Url
  if (-not (Test-Path $Dest) -or (Get-Item $Dest).Length -eq 0) {
    throw "Download failed: $Url"
  }
}

Write-Host "=== KataGo ==="
$kataZip = Join-Path $Engines "katago-opencl.zip"
Get-File "https://github.com/lightvector/KataGo/releases/download/v1.18.1/katago-v1.18.1-opencl-windows-x64.zip" $kataZip
Get-File "https://media.katagotraining.org/uploaded/networks/models/kata1/kata1-b18c384nbt-s9996604416-d4316597426.bin.gz" (Join-Path $KataDir "default_model.bin.gz")
Expand-Archive -Path $kataZip -DestinationPath $KataDir -Force
if (-not (Test-Path (Join-Path $KataDir "katago.exe"))) {
  throw "katago.exe missing after unzip"
}

[Environment]::SetEnvironmentVariable("KATAGO_PATH", (Join-Path $KataDir "katago.exe"), "User")
[Environment]::SetEnvironmentVariable("KATAGO_HOME", $KataDir, "User")
[Environment]::SetEnvironmentVariable("KATAGO_MODEL", (Join-Path $KataDir "default_model.bin.gz"), "User")
[Environment]::SetEnvironmentVariable("KATAGO_CONFIG", (Join-Path $KataDir "default_gtp.cfg"), "User")
$env:KATAGO_PATH = Join-Path $KataDir "katago.exe"
$env:KATAGO_HOME = $KataDir
$env:KATAGO_MODEL = Join-Path $KataDir "default_model.bin.gz"
$env:KATAGO_CONFIG = Join-Path $KataDir "default_gtp.cfg"

Write-Host "KataGo:"
& $env:KATAGO_PATH version

Write-Host "=== LoGos-7B (Ollama + GGUF) ==="
[Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "User")
[Environment]::SetEnvironmentVariable("LOGOS_URL", "http://127.0.0.1:11434", "User")
[Environment]::SetEnvironmentVariable("LOGOS_MODEL", "logos-7b", "User")
$env:OLLAMA_ORIGINS = "*"
$env:LOGOS_URL = "http://127.0.0.1:11434"
$env:LOGOS_MODEL = "logos-7b"

$gguf = Join-Path $Engines "logos-7b-q8_0.gguf"
$import = Join-Path $PSScriptRoot "import_logos.ps1"
if (Test-Path $gguf) {
  & $import -Gguf $gguf
} else {
  Write-Host "No $gguf — skip Ollama import. See README (LoGos from scratch) or scripts/import_logos.ps1"
}

Write-Host "Local engines ready."
Write-Host "  KataGo: $env:KATAGO_PATH"
Write-Host "  LoGos:  $env:LOGOS_URL  model=$env:LOGOS_MODEL"
