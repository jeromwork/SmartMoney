param(
    [string]$Symbol = "EURUSD",
    [string]$Period = "H1",
    [string]$SetFile = "SmartMoneyEA.set",
    [string]$From = "2024.01.01",
    [string]$To = "2024.12.31",
    [int]$Model = 0,
    [switch]$Visual,
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
$backtestScript = Join-Path $projectRoot "scripts/backtest.ps1"

$params = @{
    Expert = "SmartMoneyEA"
    Symbol = $Symbol
    Period = $Period
    SetFile = $SetFile
    From = $From
    To = $To
    Model = $Model
    Login = $credentials.Login
    Password = $credentials.Password
    Server = $credentials.Server
}
if ($Visual.IsPresent) { $params["Visual"] = $true }
& $backtestScript @params
