# Shared paths and speech limits for tldr-voice on Windows.

function Get-TldrPaths {
    $data = if ($env:TLDR_DATA_DIR) { $env:TLDR_DATA_DIR } else { Join-Path $env:LOCALAPPDATA "tldr-voice" }
    $voices = if ($env:TLDR_VOICE_DIR) { $env:TLDR_VOICE_DIR } else { Join-Path $data "voices" }
    $voice = if ($env:TLDR_VOICE) { $env:TLDR_VOICE } else { "en_US-hfc_female-medium" }
    [pscustomobject]@{
        Data   = $data
        Voices = $voices
        Voice  = $voice
        Model  = (Join-Path $voices "$voice.onnx")
    }
}

function Test-TldrMuted {
    if ($env:TLDR_MUTE -eq "1") { return $true }
    return Test-Path (Join-Path (Get-TldrPaths).Data "muted")
}

function Test-TldrPiperReady {
    $paths = Get-TldrPaths
    $python = Join-Path $paths.Data "venv\Scripts\python.exe"
    $piper = Join-Path $paths.Data "venv\Scripts\piper.exe"
    return (Test-Path $paths.Model) -and ((Test-Path $python) -or (Test-Path $piper))
}

function Limit-TldrSpeech([string]$Text) {
    $flat = ([regex]::Replace($Text, "\s+", " ")).Trim()
    if (-not $flat) { return "" }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($flat, "[^.!?]+[.!?]*")) {
        if ($parts.Count -ge 3) { break }
        $sentence = $match.Value.Trim()
        if ($sentence) { $parts.Add($sentence) }
    }
    $spoken = if ($parts.Count -gt 0) { $parts -join " " } else { $flat }
    $words = @($spoken -split "\s+" | Where-Object { $_ })
    if ($words.Count -gt 70) { $spoken = ($words | Select-Object -First 70) -join " " }
    return $spoken
}

function Test-TldrMultipleProjects {
    $root = Join-Path $env:USERPROFILE ".cursor\projects"
    if (-not (Test-Path $root)) { return $false }
    $cutoff = (Get-Date).AddMinutes(-20)
    $active = 0
    foreach ($proj in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Select-Object -First 50)) {
        $hits = Get-ChildItem "$($proj.FullName)\agent-transcripts\*\*.jsonl" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $cutoff } |
            Select-Object -First 1
        if ($hits) { $active++ }
        if ($active -gt 1) { return $true }
    }
    return $false
}

function Add-TldrProjectPrefix([string]$Text) {
    $mode = if ($env:TLDR_SAY_PROJECT) { $env:TLDR_SAY_PROJECT } else { "auto" }
    $say = $false
    if ($mode -eq "always") { $say = $true }
    elseif ($mode -eq "auto") {
        try { $say = Test-TldrMultipleProjects } catch { $say = $false }
    }
    if (-not $say) { return $Text }
    $root = $env:CURSOR_PROJECT_DIR
    if (-not $root) { $root = $env:CLAUDE_PROJECT_DIR }
    if (-not $root) { $root = (Get-Location).Path }
    $profileHome = $env:USERPROFILE.TrimEnd("\")
    if ($root.TrimEnd("\") -eq $profileHome) {
        $name = "home folder"
    } else {
        $name = (Split-Path $root -Leaf) -replace "[-_.]", " "
    }
    return "Project $name. $Text"
}

function Add-TldrLog([string]$Message) {
    try {
        $dir = (Get-TldrPaths).Data
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $line = "{0} {1}" -f (Get-Date -Format "s"), $Message
        Add-Content -Path (Join-Path $dir "speak.log") -Value $line -Encoding utf8
    } catch {
        # Logging must not stop playback.
    }
}

function Get-TldrPythonLauncher {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py -and $py.Source -notlike "*\WindowsApps\*") {
        return [pscustomobject]@{ Exe = $py.Source; Args = @("-3") }
    }
    foreach ($name in @("python", "python3")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -notlike "*\WindowsApps\*") {
            return [pscustomobject]@{ Exe = $cmd.Source; Args = @() }
        }
    }
    return $null
}
