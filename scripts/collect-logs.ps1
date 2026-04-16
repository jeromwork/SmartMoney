param(
    [ValidateSet("dev", "test", "demo")]
    [string]$Terminal = "test"
)

. (Join-Path $PSScriptRoot "lib.ps1")

$terminalRoot = Get-TerminalRoot -Terminal $Terminal
Assert-TerminalInstalled -Terminal $Terminal -RequiredPlatform any
$timestamp = New-Timestamp

$mappings = @(
    @{ Source = Join-Path $terminalRoot "logs"; Destination = "logs/terminal" },
    @{ Source = Join-Path $terminalRoot "tester/logs"; Destination = "logs/tester" },
    @{ Source = Join-Path $terminalRoot "Tester/logs"; Destination = "logs/tester" },
    @{ Source = Join-Path $terminalRoot "MQL4/Logs"; Destination = "logs/experts" },
    @{ Source = Join-Path $terminalRoot "MQL5/Logs"; Destination = "logs/experts" }
)

$copied = @{}
foreach ($mapping in $mappings) {
    $latest = Get-LatestFile -Path $mapping.Source -Filter "*.log"
    if ($latest) {
        $target = Get-ArtifactPath -RelativePath ("{0}/{1}-{2}" -f $mapping.Destination, $Terminal, $latest.Name)
        if (-not $copied.ContainsKey($target)) {
            Copy-Item -LiteralPath $latest.FullName -Destination $target -Force
            $copied[$target] = $true
            Write-Host "Collected: $target"
        }
    }
}
