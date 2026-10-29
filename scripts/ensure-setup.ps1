# Session start hook: install Piper in the background when the voice is missing.
# Disable with TLDR_AUTO_SETUP=0. Log: %LOCALAPPDATA%\tldr-voice\setup.log
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

try {
    if ($env:TLDR_AUTO_SETUP -eq "0") { return }
    if (Test-TldrPiperReady) { return }

    $paths = Get-TldrPaths
    if (-not (Test-Path $paths.Data)) { New-Item -ItemType Directory -Path $paths.Data -Force | Out-Null }
    $setup = Join-Path $PSScriptRoot "setup.ps1"
    $powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    Start-Process -FilePath $powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$setup`"" -WindowStyle Hidden | Out-Null
    [Console]::Error.WriteLine("tldr-voice: installing the Piper voice in the background (log: $(Join-Path $paths.Data 'setup.log')).")
} catch {
    [Console]::Error.WriteLine("tldr-voice: $($_.Exception.Message)")
} finally {
    Write-Output "{}"
}
