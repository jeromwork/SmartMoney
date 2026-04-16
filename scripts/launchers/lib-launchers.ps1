Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-DotEnv {
    param([Parameter(Mandatory = $true)][string]$Path)
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) { continue }
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ($key -ne "") { $values[$key] = $value }
    }
    return $values
}

function Resolve-Mt5Credentials {
    param(
        [string]$Login,
        [string]$Password,
        [string]$Server,
        [string]$EnvFile = ".env"
    )

    $projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
    $envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $projectRoot $EnvFile }
    $envValues = Read-DotEnv -Path $envPath

    if ([string]::IsNullOrWhiteSpace($Login) -and $envValues.ContainsKey("MT5_LOGIN")) { $Login = $envValues["MT5_LOGIN"] }
    if ([string]::IsNullOrWhiteSpace($Password) -and $envValues.ContainsKey("MT5_PASSWORD")) { $Password = $envValues["MT5_PASSWORD"] }
    if ([string]::IsNullOrWhiteSpace($Server) -and $envValues.ContainsKey("MT5_SERVER")) { $Server = $envValues["MT5_SERVER"] }

    if ([string]::IsNullOrWhiteSpace($Login) -or [string]::IsNullOrWhiteSpace($Password) -or [string]::IsNullOrWhiteSpace($Server)) {
        throw "MT5 credentials are incomplete. Provide -Login/-Password/-Server or fill MT5_LOGIN/MT5_PASSWORD/MT5_SERVER in .env"
    }

    return @{ Login = $Login; Password = $Password; Server = $Server }
}
