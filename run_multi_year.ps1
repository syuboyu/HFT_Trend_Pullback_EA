$dTermDir = "D:\MetaTrader 5 EXNESS-2"
$iniPath = "$dTermDir\tester_hft.ini"
$projectDir = "i:\我的雲端硬碟\scratch\HFT_Trend_Pullback_EA"

$runs = @(
    @{
        Name = "1Year"
        FromDate = "2025.09.01"
        ToDate = "2026.09.07"
        Report = "EURUSD_H1_Report_1Year.html"
        Desc = "1 年期驗證 (2025.09.01 - 2026.09.07)"
    },
    @{
        Name = "2Year"
        FromDate = "2024.09.01"
        ToDate = "2026.09.07"
        Report = "EURUSD_H1_Report_2Year.html"
        Desc = "2 年期驗證 (2024.09.01 - 2026.09.07)"
    },
    @{
        Name = "3Year"
        FromDate = "2023.09.01"
        ToDate = "2026.09.07"
        Report = "EURUSD_H1_Report_3Year.html"
        Desc = "3 年全週期壓力測試 (2023.09.01 - 2026.09.07)"
    }
)

Remove-Item "$dTermDir\MQL5\Profiles\Tester\AdaptiveTrendPullback_EA_CN.set" -ErrorAction SilentlyContinue

foreach ($run in $runs) {
    Write-Host "=========================================="
    Write-Host "開始執行: $($run.Desc)..."
    
    $iniContent = @"
[Tester]
Expert=AdaptiveTrendPullback_EA_CN.ex5
Symbol=EURUSD
Period=H1
Optimization=0
Model=1
FromDate=$($run.FromDate)
ToDate=$($run.ToDate)
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=100
ExecutionMode=0
Report=$($run.Report)
ReplaceReport=1
ShutdownTerminal=1
Visual=0
"@
    Set-Content -Path $iniPath -Value $iniContent -Encoding unicode
    
    $proc = Start-Process -FilePath "$dTermDir\terminal64.exe" -ArgumentList "/portable /config:`"$iniPath`"" -PassThru
    $timeout = 180
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        if (!(Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
            break
        }
    }
    Write-Host "完成 $($run.Name) 回測 (耗時 $elapsed 秒)"
    
    $src = Join-Path $dTermDir $run.Report
    if (Test-Path $src) {
        $dest = Join-Path $projectDir $run.Report
        Copy-Item $src -Destination $dest -Force
        Write-Host "報表已同步: $dest"
    } else {
        Write-Host "警告: 未能找到報表 $src"
    }
}
