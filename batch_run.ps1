$dTermDir = "D:\MetaTrader 5 EXNESS-2"
$iniPath = "$dTermDir\tester_hft.ini"
$setPath = "$dTermDir\MQL5\Profiles\Tester\AdaptiveTrendPullback_EA_CN.set"
$projectDir = "i:\我的雲端硬碟\scratch\HFT_Trend_Pullback_EA"

$configs = @(
    @{
        Name = "Candidate_A"
        Desc = "寬幅保本 (BE 1.5, H4 EMA 100, RR 2.0)"
        Params = @{
            InpUseBreakEven = "true"
            InpBreakEvenAtrMult = "1.5"
            InpBreakEvenBufferPts = "10.0"
            InpUseTrailingStop = "true"
            InpTrailingStartAtrMult = "2.0"
            InpTrailingStepAtrMult = "1.0"
            InpHtfEmaPeriod = "100"
            InpRiskRewardRatio = "2.0"
        }
    },
    @{
        Name = "Candidate_B"
        Desc = "高轉化率型 (BE 1.3, H4 EMA 100, RR 1.6)"
        Params = @{
            InpUseBreakEven = "true"
            InpBreakEvenAtrMult = "1.3"
            InpBreakEvenBufferPts = "10.0"
            InpUseTrailingStop = "true"
            InpTrailingStartAtrMult = "2.0"
            InpTrailingStepAtrMult = "1.0"
            InpHtfEmaPeriod = "100"
            InpRiskRewardRatio = "1.6"
        }
    },
    @{
        Name = "Candidate_C"
        Desc = "純波段無保本 (BE OFF, H4 EMA 100, RR 2.0)"
        Params = @{
            InpUseBreakEven = "false"
            InpBreakEvenAtrMult = "1.0"
            InpUseTrailingStop = "false"
            InpHtfEmaPeriod = "100"
            InpRiskRewardRatio = "2.0"
        }
    },
    @{
        Name = "Candidate_D"
        Desc = "純波段大獲利 (BE OFF, H4 EMA 100, RR 2.5, Trail 2.0)"
        Params = @{
            InpUseBreakEven = "false"
            InpUseTrailingStop = "true"
            InpTrailingStartAtrMult = "2.0"
            InpTrailingStepAtrMult = "1.0"
            InpHtfEmaPeriod = "100"
            InpRiskRewardRatio = "2.5"
        }
    }
)

foreach ($cfg in $configs) {
    Write-Host "=========================================="
    Write-Host "開始運行: $($cfg.Name) - $($cfg.Desc)"
    
    # 1. 產生 .set 檔
    $lines = @(
        "; Auto-generated set for $($cfg.Name)",
        "InpMagicNumber=123456||123456||1||1234560||N",
        "InpTradeComment=TrendPB_CN",
        "InpSlippagePoints=20||20||1||200||N",
        "InpTimeframe=16385||0||0||49153||N",
        "InpEmaFastPeriod=20||20||1||200||N",
        "InpEmaMediumPeriod=50||50||1||500||N",
        "InpEmaSlowPeriod=100||100||1||1000||N",
        "InpRsiPeriod=7||7||1||70||N",
        "InpAdxPeriod=7||7||1||70||N",
        "InpAtrPeriod=7||7||1||70||N",
        "InpAdxMinThreshold=25.0||25.0||2.5||250.0||N",
        "InpRsiCrossLevel=50.0||50.0||5.0||500.0||N",
        "InpSwingLookback=20||20||1||200||N",
        "InpMinEmaSeparationPts=35.0||35.0||3.5||350.0||N",
        "InpMinAtrPoints=50.0||50.0||5.0||500.0||N",
        "InpMaxSpreadPoints=30.0||30.0||3.0||300.0||N",
        "InpUseHtfFilter=true||false||0||true||N",
        "InpHtfTimeframe=16388||0||0||49153||N",
        "InpHtfEmaPeriod=$($cfg.Params['InpHtfEmaPeriod'])||100||10||1000||N",
        "InpAtrSlBufferMult=0.2||0.2||0.02||2.0||N",
        "InpMinSlAtrMult=1.0||1.0||0.1||10.0||N",
        "InpRiskRewardRatio=$($cfg.Params['InpRiskRewardRatio'])||2.0||0.2||20.0||N",
        "InpUseBreakEven=$($cfg.Params['InpUseBreakEven'])||false||0||true||N",
        "InpBreakEvenAtrMult=$($cfg.Params['InpBreakEvenAtrMult'])||1.0||0.1||10.0||N",
        "InpBreakEvenBufferPts=10.0||10.0||1.0||100.0||N",
        "InpUseTrailingStop=$($cfg.Params['InpUseTrailingStop'])||false||0||true||N",
        "InpTrailingStartAtrMult=$($cfg.Params['InpTrailingStartAtrMult'])||2.0||0.2||20.0||N",
        "InpTrailingStepAtrMult=$($cfg.Params['InpTrailingStepAtrMult'])||1.0||0.1||10.0||N",
        "InpLotSizeMode=0||0||0||1||N",
        "InpFixedLotSize=0.1||0.1||0.01||1.0||N",
        "InpRiskPercent=1.0||1.0||0.1||10.0||N",
        "InpUseCooldown=true||false||0||true||N",
        "InpCooldownBars=3||3||1||30||N",
        "InpUseSessionFilter=true||false||0||true||N",
        "InpSession1StartHour=7||7||1||70||N",
        "InpSession1EndHour=16||16||1||160||N",
        "InpUseSession2=true||false||0||true||N",
        "InpSession2StartHour=12||12||1||120||N",
        "InpSession2EndHour=21||21||1||210||N",
        "InpUseFridayFilter=true||false||0||true||N",
        "InpFridayStopHour=20||20||1||200||N",
        "InpUseBreakoutEngine=false||false||0||true||N",
        "InpBreakoutLookback=12||12||1||120||N",
        "InpBreakoutAdxMin=22.0||22.0||2.2||220.0||N",
        "InpBreakoutRsiBuyMin=55.0||55.0||5.5||550.0||N",
        "InpBreakoutRsiSellMax=45.0||45.0||4.5||450.0||N",
        "InpOnePositionPerSide=true||false||0||true||N",
        "InpShowDashboard=false||false||0||true||N"
    )
    $lines | Set-Content $setPath -Encoding utf8

    # 2. 寫入 ini 配置
    $reportFileName = "$($cfg.Name)_Report.html"
    $iniContent = @"
[Tester]
Expert=AdaptiveTrendPullback_EA_CN.ex5
ExpertParameters=AdaptiveTrendPullback_EA_CN.set
Symbol=EURUSD
Period=H1
Optimization=0
Model=1
FromDate=2026.01.01
ToDate=2026.09.07
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=100
ExecutionMode=0
Report=$reportFileName
ReplaceReport=1
ShutdownTerminal=1
Visual=0
"@
    Set-Content -Path $iniPath -Value $iniContent -Encoding unicode

    # 3. 執行回測
    $proc = Start-Process -FilePath "$dTermDir\terminal64.exe" -ArgumentList "/portable /config:`"$iniPath`"" -PassThru
    $timeout = 90
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        if (!(Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
            break
        }
    }
    Write-Host "完成 $($cfg.Name) (耗時 $elapsed 秒)"

    # 4. 同步報表
    $repSrc = Join-Path $dTermDir $reportFileName
    if (Test-Path $repSrc) {
        $repDest = Join-Path $projectDir $reportFileName
        Copy-Item $repSrc -Destination $repDest -Force
        Write-Host "已同步報表: $repDest"
    } else {
        Write-Host "警告: 找不到報表檔案 $repSrc"
    }
}
