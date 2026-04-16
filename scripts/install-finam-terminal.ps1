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

$attempts = @(
    @("/auto", "/portable", "/dir=$stagingRoot"),
    @("/silent", "/portable", "/dir=$stagingRoot"),
    @("/verysilent", "/portable", "/dir=$stagingRoot")
)

$installed = $false
foreach ($attempt in $attempts) {
    Write-Host "Trying installer arguments: $($attempt -join ' ')"
    try {
        $process = Start-Process -FilePath $InstallerPath -ArgumentList $attempt -PassThru -Wait
        $terminalExe = Get-ChildItem -LiteralPath $stagingRoot -Filter "terminal.exe" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        $mql4Dir = Get-ChildItem -LiteralPath $stagingRoot -Directory -Filter "MQL4" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($process.ExitCode -eq 0 -and $terminalExe -and $mql4Dir) {
            $installed = $true
            break
        }
    } catch {
        Write-Warning $_
    }
}

if (-not $installed) {
    throw "Automatic installation did not produce a valid MT4 layout under $stagingRoot. Verify that downloads/finam5setup.exe is really an MT4 installer, not MT5, and install it manually into artifacts/terminal-staging."
}

$originFile = Join-Path $stagingRoot "origin.txt"
Set-Content -Path $originFile -Value "Installed from $InstallerPath at $(Get-Date -Format s)"

foreach ($terminal in @("dev", "test", "demo")) {
    $target = Get-TerminalRoot -Terminal $terminal
    Invoke-RobocopyMirror -Source $stagingRoot -Destination $target
}

Write-Host "Broker terminal cloned into dev/test/demo."
