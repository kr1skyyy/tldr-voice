# Install Piper TTS and download a voice for tldr-voice.
# Usage: setup.ps1 [voice-name]
param(
    [Parameter(Position = 0)]
    [string]$VoiceName
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$paths = Get-TldrPaths
if ($VoiceName) {
    $paths.Voice = $VoiceName
    $paths.Model = Join-Path $paths.Voices "$VoiceName.onnx"
}

New-Item -ItemType Directory -Path $paths.Data -Force | Out-Null
$log = Join-Path $paths.Data "setup.log"
$marker = Join-Path $paths.Data "setup.running"
$mutex = New-Object System.Threading.Mutex($false, "Local\tldr-voice-setup")
$owned = $false
try {
    try { $owned = $mutex.WaitOne(0) } catch { $owned = $true }
    if (-not $owned) {
        Write-Host "tldr-voice: setup already running."
        exit 0
    }
    New-Item -ItemType File -Path $marker -Force | Out-Null
    try { Start-Transcript -Path $log -Append -Force | Out-Null } catch { }
    try {
        $venv = Join-Path $paths.Data "venv"
        $venvPy = Join-Path $venv "Scripts\python.exe"
        $launcher = Get-TldrPythonLauncher
        if (-not $launcher) { throw "Python 3 is required. Install it from python.org and make sure the py launcher is on PATH." }

        $needsInstall = -not (Test-Path $venvPy)
        if (-not $needsInstall) {
            & $venvPy -c "import piper" 2>$null
            if ($LASTEXITCODE -ne 0) { $needsInstall = $true }
        }
        if ($needsInstall) {
            if (-not (Test-Path $venvPy)) {
                Write-Host "Creating a private Python environment in $venv"
                & $launcher.Exe @($launcher.Args + @("-m", "venv", $venv))
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPy)) { throw "Could not create the Python virtual environment." }
            }
            Write-Host "Installing piper-tts"
            & $venvPy -m pip install --disable-pip-version-check --quiet piper-tts
            if ($LASTEXITCODE -ne 0) { throw "pip install piper-tts failed." }
        } else {
            Write-Host "Piper already installed."
        }

        New-Item -ItemType Directory -Path $paths.Voices -Force | Out-Null
        if (Test-Path $paths.Model) {
            Write-Host "Voice $($paths.Voice) already downloaded."
        } else {
            Write-Host "Downloading voice $($paths.Voice)"
            & $venvPy -m piper.download_voices $paths.Voice --data-dir $paths.Voices
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $paths.Model)) {
                $found = Get-ChildItem $paths.Voices -Recurse -Filter "$($paths.Voice).onnx" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($found -and $found.FullName -ne $paths.Model) {
                    Copy-Item $found.FullName $paths.Model -Force
                    $config = "$($found.FullName).json"
                    if (Test-Path $config) { Copy-Item $config "$($paths.Model).json" -Force }
                }
            }
            if (-not (Test-Path $paths.Model)) { throw "Voice download failed for $($paths.Voice)." }
        }

        $env:TLDR_VOICE = $paths.Voice
        $env:TLDR_VOICE_DIR = $paths.Voices
        & (Join-Path $PSScriptRoot "speak.ps1") "Voice summaries are ready."
        Write-Host "Done. You should hear a test sentence."
    } finally {
        try { Stop-Transcript | Out-Null } catch { }
    }
} catch {
    [Console]::Error.WriteLine("tldr-voice setup failed: $($_.Exception.Message)")
    exit 1
} finally {
    Remove-Item $marker -Force -ErrorAction SilentlyContinue
    if ($owned) {
        try { $mutex.ReleaseMutex() | Out-Null } catch { }
    }
    $mutex.Dispose()
}
