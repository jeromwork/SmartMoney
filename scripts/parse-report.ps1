param(
    [Parameter(Mandatory = $true)]
    [string]$Report
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$reportPath = (Resolve-Path -LiteralPath $Report).Path
$html = Get-Content -LiteralPath $reportPath -Raw

function Get-MetricValue {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Labels
    )

    foreach ($label in $Labels) {
        $pattern = [regex]::Escape($label) + "</td>\s*<td[^>]*>(?<value>.*?)</td>"
        $match = [regex]::Match($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            return ($match.Groups["value"].Value -replace "<.*?>", "").Trim()
        }
    }

    return $null
}

$metrics = [ordered]@{
    Report = $reportPath
    NetProfit = Get-MetricValue -Labels @("Total net profit", "Чистая прибыль")
    ProfitFactor = Get-MetricValue -Labels @("Profit factor", "Профит фактор")
    ExpectedPayoff = Get-MetricValue -Labels @("Expected payoff", "Ожидаемая прибыль")
    AbsoluteDrawdown = Get-MetricValue -Labels @("Absolute drawdown", "Абсолютная просадка")
    MaximalDrawdown = Get-MetricValue -Labels @("Maximal drawdown", "Максимальная просадка")
    Trades = Get-MetricValue -Labels @("Total trades", "Всего сделок")
    BarsInTest = Get-MetricValue -Labels @("Bars in test", "Баров в тесте")
}

$jsonPath = [System.IO.Path]::ChangeExtension($reportPath, ".json")
$metrics | ConvertTo-Json | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$metrics.GetEnumerator() | ForEach-Object {
    Write-Host ("{0}: {1}" -f $_.Key, $_.Value)
}
