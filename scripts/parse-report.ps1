param(
    [Parameter(Mandatory = $true)]
    [string]$Report
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$reportPath = (Resolve-Path -LiteralPath $Report).Path
$raw = Get-Content -LiteralPath $reportPath -Raw
$ext = [System.IO.Path]::GetExtension($reportPath).ToLowerInvariant()

function Get-MetricFromHtmlTable {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Labels
    )

    foreach ($label in $Labels) {
        $pattern = [regex]::Escape($label) + "</td>\s*<td[^>]*>(?<value>.*?)</td>"
        $match = [regex]::Match($raw, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            return ($match.Groups["value"].Value -replace "<.*?>", "").Trim()
        }
    }

    return $null
}

function Get-MetricFromText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Labels,
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    foreach ($label in $Labels) {
        $pattern = "(?im)" + [regex]::Escape($label) + "[^\r\n0-9\\-]*([\\-]?[0-9][0-9\\s\\.,%]*)"
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value.Trim()
        }
    }

    return $null
}

$plain = ($raw -replace "<[^>]+>", " " -replace "\s+", " ").Trim()

$metrics = [ordered]@{
    Report = $reportPath
    Format = $ext
    NetProfit = $null
    ProfitFactor = $null
    ExpectedPayoff = $null
    AbsoluteDrawdown = $null
    MaximalDrawdown = $null
    Trades = $null
    BarsInTest = $null
}

if ($ext -eq ".htm" -or $ext -eq ".html") {
    $metrics.NetProfit = Get-MetricFromHtmlTable -Labels @("Total net profit", "Чистая прибыль")
    $metrics.ProfitFactor = Get-MetricFromHtmlTable -Labels @("Profit factor", "Профит фактор")
    $metrics.ExpectedPayoff = Get-MetricFromHtmlTable -Labels @("Expected payoff", "Ожидаемая прибыль")
    $metrics.AbsoluteDrawdown = Get-MetricFromHtmlTable -Labels @("Absolute drawdown", "Абсолютная просадка")
    $metrics.MaximalDrawdown = Get-MetricFromHtmlTable -Labels @("Maximal drawdown", "Максимальная просадка")
    $metrics.Trades = Get-MetricFromHtmlTable -Labels @("Total trades", "Всего сделок")
    $metrics.BarsInTest = Get-MetricFromHtmlTable -Labels @("Bars in test", "Баров в тесте")
}

if (-not $metrics.NetProfit) {
    $metrics.NetProfit = Get-MetricFromText -Labels @("Total net profit", "Net profit", "Чистая прибыль") -Text $plain
}
if (-not $metrics.ProfitFactor) {
    $metrics.ProfitFactor = Get-MetricFromText -Labels @("Profit factor", "Профит фактор") -Text $plain
}
if (-not $metrics.ExpectedPayoff) {
    $metrics.ExpectedPayoff = Get-MetricFromText -Labels @("Expected payoff", "Ожидаемая прибыль") -Text $plain
}
if (-not $metrics.AbsoluteDrawdown) {
    $metrics.AbsoluteDrawdown = Get-MetricFromText -Labels @("Absolute drawdown", "Абсолютная просадка") -Text $plain
}
if (-not $metrics.MaximalDrawdown) {
    $metrics.MaximalDrawdown = Get-MetricFromText -Labels @("Maximal drawdown", "Максимальная просадка") -Text $plain
}
if (-not $metrics.Trades) {
    $metrics.Trades = Get-MetricFromText -Labels @("Total trades", "Всего сделок", "Trades") -Text $plain
}
if (-not $metrics.BarsInTest) {
    $metrics.BarsInTest = Get-MetricFromText -Labels @("Bars in test", "Баров в тесте") -Text $plain
}

$jsonPath = [System.IO.Path]::ChangeExtension($reportPath, ".json")
$metrics | ConvertTo-Json | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$metrics.GetEnumerator() | ForEach-Object {
    Write-Host ("{0}: {1}" -f $_.Key, $_.Value)
}
