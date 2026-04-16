param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [ValidateSet("dev", "test", "demo")]
    [string]$Terminal = "test"
)

. (Join-Path $PSScriptRoot "lib.ps1")

$platform = Get-TerminalPlatform -Terminal $Terminal
if ($platform -ne "mt5") {
    throw "Build script currently supports MQL5 only. Terminal '$Terminal' is '$platform'. Install MT5 (MQL5)."
}

$resolvedSource = Resolve-SourceFile -Source $Source
Sync-Mql5Source -Terminal $Terminal

$metaEditor = Get-TerminalExecutable -Terminal $Terminal -Kind metaeditor
if (-not $metaEditor) {
    throw "MetaEditor not found for terminal '$Terminal'."
}

$terminalSource = Convert-ToTerminalSourcePath -ResolvedSource $resolvedSource -Terminal $Terminal
$timestamp = New-Timestamp
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedSource)
$compileLog = Get-ArtifactPath -RelativePath ("logs/compile/{0}-{1}-{2}.log" -f $Terminal, $baseName, $timestamp)

$process = Start-Process -FilePath $metaEditor `
    -ArgumentList @("/portable", "/compile:$terminalSource", "/log:$compileLog") `
    -WorkingDirectory (Get-TerminalRoot -Terminal $Terminal) `
    -PassThru `
    -Wait

if (-not (Test-Path -LiteralPath $compileLog)) {
    throw "Compile log was not created: $compileLog"
}

$logContent = Get-Content -LiteralPath $compileLog -Encoding Unicode -Raw
$resultErrors = 0
$resultMatch = [regex]::Match($logContent, "(?im)Result:\s*(\d+)\s+errors?")
if ($resultMatch.Success) {
    $resultErrors = [int]$resultMatch.Groups[1].Value
}

if ($resultErrors -gt 0 -or $logContent -match "(?im)\b[1-9]\d*\s+error\(s\)") {
    throw "Compilation failed. See $compileLog"
}

$compiledFile = [System.IO.Path]::ChangeExtension($terminalSource, ".ex5")
if (-not (Test-Path -LiteralPath $compiledFile)) {
    throw "Compilation finished without EX5 output: $compiledFile"
}

Write-Host "Compiled: $compiledFile"
Write-Host "Log: $compileLog"
