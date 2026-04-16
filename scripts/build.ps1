param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [ValidateSet("dev", "test", "demo")]
    [string]$Terminal = "test"
)

. (Join-Path $PSScriptRoot "lib.ps1")

$resolvedSource = Resolve-SourceFile -Source $Source
Sync-Mql4Source -Terminal $Terminal

$metaEditor = Get-ExecutablePath -Terminal $Terminal -ExecutableName "metaeditor.exe"
if (-not $metaEditor) {
    throw "MetaEditor not found for terminal '$Terminal'."
}

$terminalSource = Convert-ToTerminalSourcePath -ResolvedSource $resolvedSource -Terminal $Terminal
$timestamp = New-Timestamp
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedSource)
$compileLog = Get-ArtifactPath -RelativePath ("logs/compile/{0}-{1}-{2}.log" -f $Terminal, $baseName, $timestamp)

$process = Start-Process -FilePath $metaEditor `
    -ArgumentList @("/compile:$terminalSource", "/log:$compileLog") `
    -PassThru `
    -Wait

if (-not (Test-Path -LiteralPath $compileLog)) {
    throw "Compile log was not created: $compileLog"
}

$logContent = Get-Content -LiteralPath $compileLog -Raw
if ($process.ExitCode -ne 0 -or $logContent -match "(?im)\\b\\d+\\s+error\\(s\\)") {
    throw "Compilation failed. See $compileLog"
}

$compiledFile = [System.IO.Path]::ChangeExtension($terminalSource, ".ex4")
if (-not (Test-Path -LiteralPath $compiledFile)) {
    throw "Compilation finished without EX4 output: $compiledFile"
}

Write-Host "Compiled: $compiledFile"
Write-Host "Log: $compileLog"
