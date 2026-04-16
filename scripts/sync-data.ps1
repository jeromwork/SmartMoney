param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("test", "demo")]
    [string]$Terminal,
    [Parameter(Mandatory = $true)]
    [ValidateSet("broker", "import")]
    [string]$Source,
    [Parameter(Mandatory = $true)]
    [string]$Symbol
)

. (Join-Path $PSScriptRoot "lib.ps1")

$targetRoot = Get-TerminalRoot -Terminal $Terminal
Assert-TerminalInstalled -Terminal $Terminal

switch ($Source) {
    "broker" {
        $sourceRoot = Get-TerminalRoot -Terminal "dev"
        Assert-TerminalInstalled -Terminal "dev"
        $candidates = @(
            @{ From = Join-Path $sourceRoot "history"; To = Join-Path $targetRoot "history" },
            @{ From = Join-Path $sourceRoot "Tester/history"; To = Join-Path $targetRoot "Tester/history" }
        )
    }
    "import" {
        $projectRoot = Get-ProjectRoot
        $candidates = @(
            @{ From = Join-Path $projectRoot ("data/import/" + $Symbol); To = Join-Path $targetRoot "history/import" },
            @{ From = Join-Path $projectRoot ("data/ticks/" + $Symbol); To = Join-Path $targetRoot "Tester/history" }
        )
    }
}

foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate.From) {
        Invoke-RobocopyMirror -Source $candidate.From -Destination $candidate.To
        Write-Host "Synced $($candidate.From) -> $($candidate.To)"
    }
}
