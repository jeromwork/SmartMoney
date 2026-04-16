param(
    [string]$InstallerPath = (Join-Path ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))) "downloads/finam5setup.exe")
)

. (Join-Path $PSScriptRoot "lib.ps1")

$projectRoot = Get-ProjectRoot
$stagingRoot = Join-Path $projectRoot "artifacts/terminal-staging"

if (-not (Test-Path -LiteralPath $InstallerPath)) {
    throw "Installer not found: $InstallerPath"
}

Ensure-Directory -Path $stagingRoot

$existingTerminal = Get-ChildItem -LiteralPath $stagingRoot -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @("terminal.exe", "terminal64.exe") } |
    Select-Object -First 1

$existingEditor = Get-ChildItem -LiteralPath $stagingRoot -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -in @("metaeditor.exe", "MetaEditor.exe", "MetaEditor64.exe") } |
    Select-Object -First 1

$installed = $false
if ($existingTerminal -and $existingEditor) {
    $installed = $true
}

$attempts = @(
    @("/auto", "/portable", "/dir=$stagingRoot"),
    @("/silent", "/portable", "/dir=$stagingRoot"),
    @("/verysilent", "/portable", "/dir=$stagingRoot")
)

if (-not $installed) {
    foreach ($attempt in $attempts) {
        Write-Host "Trying installer arguments: $($attempt -join ' ')"
        try {
            $process = Start-Process -FilePath $InstallerPath -ArgumentList $attempt -PassThru -Wait
            $terminalExe = Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -in @("terminal.exe", "terminal64.exe") } |
                Select-Object -First 1
            $editorExe = Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -in @("metaeditor.exe", "MetaEditor.exe", "MetaEditor64.exe") } |
                Select-Object -First 1
            if ($process.ExitCode -eq 0 -and $terminalExe -and $editorExe) {
                $installed = $true
                break
            }
        } catch {
            Write-Warning $_
        }
    }
}

if (-not $installed) {
    throw "Automatic installation did not produce a valid terminal layout under $stagingRoot. Install manually into artifacts/terminal-staging and rerun this script."
}

$platform = "unknown"
if (Test-Path -LiteralPath (Join-Path $stagingRoot "MQL5")) {
    $platform = "mt5"
}

$originFile = Join-Path $stagingRoot "origin.txt"
Set-Content -Path $originFile -Value "Installed from $InstallerPath at $(Get-Date -Format s); platform=$platform"

foreach ($terminal in @("dev", "test", "demo")) {
    $target = Get-TerminalRoot -Terminal $terminal
    Invoke-RobocopyMirror -Source $stagingRoot -Destination $target
}

Write-Host "Broker terminal cloned into dev/test/demo. Platform: $platform"
