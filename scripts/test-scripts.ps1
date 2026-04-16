Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scripts = @(
    "lib.ps1",
    "install-finam-terminal.ps1",
    "build.ps1",
    "backtest.ps1",
    "collect-logs.ps1",
    "parse-report.ps1",
    "demo-launch.ps1",
    "sync-data.ps1"
)

foreach ($script in $scripts) {
    $path = Join-Path $PSScriptRoot $script
    [void][System.Management.Automation.PSParser]::Tokenize((Get-Content -LiteralPath $path -Raw), [ref]$null)
    Write-Host "OK $script"
}
