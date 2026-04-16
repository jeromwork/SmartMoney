param(
    [string]$Symbol = "EURUSD",
    [string]$Period = "H1",
    [string]$SetFile = "SmartMoneyEA.set",
    [string]$Login = "",
    [string]$Password = "",
    [string]$Server = "",
    [string]$EnvFile = ".env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib-launchers.ps1")
$credentials = Resolve-Mt5Credentials -Login $Login -Password $Password -Server $Server -EnvFile $EnvFile
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$demoScript = Join-Path $projectRoot "scripts/demo-launch.ps1"

& $demoScript -Expert "SmartMoneyEA" -Symbol $Symbol -Period $Period -SetFile $SetFile -Login $credentials.Login -Password $credentials.Password -Server $credentials.Server
