# Speak a short summary aloud. Returns immediately; audio plays in the background.
# Usage: speak.ps1 "Text to speak."
[CmdletBinding(DefaultParameterSetName = "Speak", PositionalBinding = $false)]
param(
    [Parameter(ParameterSetName = "Play", Mandatory = $true)]
    [switch]$BackgroundPlay,

    [Parameter(ParameterSetName = "Play", Mandatory = $true)]
    [string]$TextFile,

    [Parameter(ParameterSetName = "Speak", Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Words
)

. (Join-Path $PSScriptRoot "common.ps1")

function Stop-TldrPlayback {
    $lock = Join-Path (Get-TldrPaths).Data "playback.pid"
    if (-not (Test-Path $lock)) { return }
    $old = Get-Content $lock -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($old -match "^\d+$") {
        $procId = [int]$old
        if ($procId -gt 0 -and $procId -ne $PID) {
            & taskkill.exe /PID $procId /T /F *> $null
        }
    }
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}

function Invoke-PiperWav([string]$Text, [string]$Wav) {
    $paths = Get-TldrPaths
    $piper = Join-Path $paths.Data "venv\Scripts\piper.exe"
    $python = Join-Path $paths.Data "venv\Scripts\python.exe"
    if (Test-Path $piper) {
        $exe = $piper
        $arguments = "-m `"$($paths.Model)`" -f `"$Wav`""
    } elseif (Test-Path $python) {
        $exe = $python
        $arguments = "-m piper -m `"$($paths.Model)`" -f `"$Wav`""
    } else {
        return $false
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $writer = New-Object System.IO.StreamWriter($proc.StandardInput.BaseStream, [Text.UTF8Encoding]::new($false))
    $writer.Write($Text)
    $writer.Close()
    $proc.WaitForExit()
    return ($proc.ExitCode -eq 0 -and (Test-Path $Wav) -and ((Get-Item $Wav).Length -gt 100))
}

function Invoke-WindowsSpeech([string]$Text) {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $synth.Speak($Text)
    $synth.Dispose()
}

function Play-TldrWav([string]$Wav) {
    $player = New-Object System.Media.SoundPlayer $Wav
    $player.PlaySync()
    $player.Dispose()
}

function Invoke-TldrPlayback([string]$Text) {
    $wav = Join-Path $env:TEMP ("tldr-voice-{0}.wav" -f [guid]::NewGuid().ToString("n"))
    $played = $false
    try {
        if (Test-TldrPiperReady) {
            if (Invoke-PiperWav $Text $wav) {
                Play-TldrWav $wav
                $played = $true
            } else {
                Add-TldrLog "piper produced no audio; using Windows speech"
            }
        }
    } catch {
        Add-TldrLog ("piper failed: " + $_.Exception.Message)
    }
    if (-not $played) {
        try {
            Invoke-WindowsSpeech $Text
        } catch {
            Add-TldrLog ("windows speech failed: " + $_.Exception.Message)
            throw
        }
    }
    Remove-Item $wav -Force -ErrorAction SilentlyContinue
}

if ($BackgroundPlay) {
    $lock = Join-Path (Get-TldrPaths).Data "playback.pid"
    try {
        if (-not $TextFile -or -not (Test-Path $TextFile)) { exit 1 }
        $spoken = [System.IO.File]::ReadAllText($TextFile, [Text.UTF8Encoding]::new($false))
        if ($spoken) { Invoke-TldrPlayback $spoken }
    } catch {
        Add-TldrLog $_.Exception.Message
        exit 1
    } finally {
        if ($TextFile) { Remove-Item $TextFile -Force -ErrorAction SilentlyContinue }
        Remove-Item $lock -Force -ErrorAction SilentlyContinue
    }
    exit 0
}

if (Test-TldrMuted) { exit 0 }

$text = (($Words | Where-Object { $_ }) -join " ").Trim()
if (-not $text) {
    [Console]::Error.WriteLine('usage: speak.ps1 "text"')
    exit 1
}

$text = Limit-TldrSpeech $text
$text = Add-TldrProjectPrefix $text
if (-not $text) { exit 0 }

$paths = Get-TldrPaths
if (-not (Test-TldrPiperReady) -and -not (Test-Path (Join-Path $paths.Data "setup.running"))) {
    $warned = Join-Path $paths.Data "sapi-fallback.warned"
    if (-not (Test-Path $warned)) {
        if (-not (Test-Path $paths.Data)) { New-Item -ItemType Directory -Path $paths.Data -Force | Out-Null }
        New-Item -ItemType File -Path $warned -Force | Out-Null
        Write-Warning "tldr-voice: Piper is not installed yet. Speaking with the Windows voice. Run scripts/setup.ps1 to install Piper."
    }
}

Stop-TldrPlayback
if (-not (Test-Path $paths.Data)) { New-Item -ItemType Directory -Path $paths.Data -Force | Out-Null }
$lock = Join-Path $paths.Data "playback.pid"
Set-Content -Path $lock -Value $PID -Encoding ascii
try {
    Invoke-TldrPlayback $text
} finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
exit 0
