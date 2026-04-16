Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Get-TerminalRoot {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal
    )

    return Join-Path (Get-ProjectRoot) ("terminals/mt4-" + $Terminal)
}

function Get-SourceRoot {
    return Join-Path (Get-ProjectRoot) "src/MQL5"
}

function Get-ArtifactPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $path = Join-Path (Get-ProjectRoot) $RelativePath
    Ensure-Directory -Path ([System.IO.Path]::GetDirectoryName($path))
    return $path
}

function Get-ExecutablePath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal,
        [Parameter(Mandatory = $true)]
        [string]$ExecutableName
    )

    $terminalRoot = Get-TerminalRoot -Terminal $Terminal
    if (-not (Test-Path -LiteralPath $terminalRoot)) {
        return $null
    }

    $match = Get-ChildItem -LiteralPath $terminalRoot -Filter $ExecutableName -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -eq $match) {
        return $null
    }

    return $match.FullName
}

function Get-TerminalExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal,
        [Parameter(Mandatory = $true)]
        [ValidateSet("terminal", "metaeditor")]
        [string]$Kind
    )

    $candidates = @()
    if ($Kind -eq "terminal") {
        $candidates = @("terminal.exe", "terminal64.exe")
    } elseif ($Kind -eq "metaeditor") {
        $candidates = @("metaeditor.exe", "MetaEditor.exe", "MetaEditor64.exe")
    }

    foreach ($name in $candidates) {
        $path = Get-ExecutablePath -Terminal $Terminal -ExecutableName $name
        if ($path) {
            return $path
        }
    }

    return $null
}

function Get-TerminalPlatform {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal
    )

    $terminalRoot = Get-TerminalRoot -Terminal $Terminal
    if (Test-Path -LiteralPath (Join-Path $terminalRoot "MQL4")) {
        return "mt4"
    }

    if (Test-Path -LiteralPath (Join-Path $terminalRoot "MQL5")) {
        return "mt5"
    }

    return "unknown"
}

function Assert-TerminalInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal,
        [ValidateSet("any", "mt4", "mt5")]
        [string]$RequiredPlatform = "any"
    )

    $terminalExe = Get-TerminalExecutable -Terminal $Terminal -Kind terminal
    $metaEditorExe = Get-TerminalExecutable -Terminal $Terminal -Kind metaeditor
    $platform = Get-TerminalPlatform -Terminal $Terminal

    if (-not $terminalExe -or -not $metaEditorExe -or $platform -eq "unknown") {
        throw "Terminal $Terminal is not installed correctly. Install terminal files into the project and rerun scripts/install-finam-terminal.ps1."
    }

    if ($RequiredPlatform -ne "any" -and $platform -ne $RequiredPlatform) {
        throw "Terminal $Terminal platform mismatch: found $platform, required $RequiredPlatform."
    }
}

function Invoke-RobocopyMirror {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Ensure-Directory -Path $Destination
    $null = robocopy $Source $Destination /E /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -gt 7) {
        throw "Robocopy failed with exit code $LASTEXITCODE."
    }
}

function Sync-Mql5Source {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal
    )

    Assert-TerminalInstalled -Terminal $Terminal -RequiredPlatform mt5
    $sourceRoot = Get-SourceRoot
    $destinationRoot = Join-Path (Get-TerminalRoot -Terminal $Terminal) "MQL5"
    Invoke-RobocopyMirror -Source $sourceRoot -Destination $destinationRoot
}

function Resolve-SourceFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $projectRoot = Get-ProjectRoot
    $candidate = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $projectRoot $Source }
    $resolved = (Resolve-Path -LiteralPath $candidate).Path
    $sourceRoot = (Resolve-Path -LiteralPath (Get-SourceRoot)).Path

    if (-not $resolved.StartsWith($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Source file must live under $sourceRoot"
    }

    return $resolved
}

function Convert-ToTerminalSourcePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedSource,
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal
    )

    $sourceRoot = (Resolve-Path -LiteralPath (Get-SourceRoot)).Path
    $relative = $ResolvedSource.Substring($sourceRoot.Length).TrimStart("\")
    return Join-Path (Join-Path (Get-TerminalRoot -Terminal $Terminal) "MQL5") $relative
}

function Copy-PresetToTerminal {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "test", "demo")]
        [string]$Terminal,
        [Parameter(Mandatory = $true)]
        [string]$SetFile
    )

    $projectRoot = Get-ProjectRoot
    $presetPath = if ([System.IO.Path]::IsPathRooted($SetFile)) { $SetFile } else { Join-Path $projectRoot ("presets/" + $SetFile) }
    $presetPath = (Resolve-Path -LiteralPath $presetPath).Path

    $presetName = Split-Path -Leaf $presetPath
    $presetsDir = Join-Path (Join-Path (Get-TerminalRoot -Terminal $Terminal) "MQL5") "Profiles/Tester"
    $testerDir = Join-Path (Get-TerminalRoot -Terminal $Terminal) "Tester"
    Ensure-Directory -Path $presetsDir
    Ensure-Directory -Path $testerDir
    Copy-Item -LiteralPath $presetPath -Destination (Join-Path $presetsDir $presetName) -Force
    Copy-Item -LiteralPath $presetPath -Destination (Join-Path $testerDir $presetName) -Force

    return $presetName
}

function New-Timestamp {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Get-LatestFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Filter
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-ChildItem -LiteralPath $Path -Filter $Filter -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
