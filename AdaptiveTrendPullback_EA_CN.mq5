//+------------------------------------------------------------------------+
//|                                AdaptiveTrendPullback_EA_CN.mq5          |
//|                    自適應趨勢回撤交易系統 (商業旗艦全功能版)           |
//|                                                                        |
//|  適用商品: 任意貨幣對 / 指數 (最佳推薦 EURUSD, H1 時框)                |
//|  核心模組:                                                             |
//|   1. 均線趨勢排列 (EMA 20/50/100) + 價格回踩確認 + RSI 穿越 + ADX 強度 |
//|   2. 大週期 H4 趨勢閘門 (Higher-TF EMA Gate, 順大勢過濾逆勢雜訊)       |
//|   3. 兩階段保本鎖利 (1.0 ATR 移損開倉價保本 + 1.8 ATR 寬幅追蹤鎖利)   |
//|   4. 進場冷卻機制 (Cooldown Bars, 阻斷震盪連敗割肉)                    |
//|   5. 交易時段與週五避險過濾 (Session Filter & Weekend Guard)          |
//|   6. 現代化圖表半透明視覺儀表板 (GUI Dashboard)                        |
//+------------------------------------------------------------------------+
#property copyright "Enterprise EA Development / Chinese Flagship Edition"
#property version   "2.00"
#property strict
#property description "自適應趨勢回撤交易系統 (Adaptive Trend Pullback EA) - 商業旗艦全功能版"

#include <Trade\Trade.mqh>

//============================== 列舉選單 (ENUMS) ===========================
enum ENUM_LOT_MODE
  {
   LOT_MODE_FIXED        = 0, // 固定手數 (Fixed Lot)
   LOT_MODE_RISK_PERCENT = 1  // 依帳戶權益風險比例 (Risk Percent)
  };

//============================== 參數設定 (INPUTS) ==========================
input group "=== 基礎設定 (General Settings) ==="
input long              InpMagicNumber        = 123456;          // 魔術編號 (Magic Number，每圖表唯一)
input string            InpTradeComment       = "TrendPB_CN";    // 訂單註解 (Order Comment)
input int               InpSlippagePoints     = 20;              // 最大允許滑點點數 (Max Slippage in Points)
input ENUM_TIMEFRAMES   InpTimeframe          = PERIOD_H1;       // 策略運作時框 (Working Timeframe)

input group "=== 指標週期設定 (Indicator Periods) ==="
input int                InpEmaFastPeriod     = 20;              // 快線 EMA 週期 (Fast EMA Period)
input int                InpEmaMediumPeriod   = 50;              // 中線 EMA 週期 (Medium EMA Period)
input int                InpEmaSlowPeriod     = 100;             // 慢線 EMA 週期 (Slow EMA Period)
input int                InpRsiPeriod         = 7;               // RSI 週期 (RSI Period)
input int                InpAdxPeriod         = 7;               // ADX 週期 (ADX Period)
input int                InpAtrPeriod         = 7;               // ATR 週期 (ATR Period)

input group "=== 訊號與市場過濾 (Signal Filters) ==="
input double             InpAdxMinThreshold   = 25.0;            // 最小 ADX 趨勢門檻 (低於此值視為盤整不開倉)
input double             InpRsiCrossLevel     = 50.0;            // RSI 穿越分水嶺 (預設 50 中軸)
input int                InpSwingLookback     = 20;              // 波段高低點回溯根數 (Swing Lookback Bars)
input double             InpMinEmaSeparationPts = 35;            // 快中均線最小間距 (點數，盤整黏合過濾)
input double             InpMinAtrPoints      = 50;              // 最小 ATR 點數門檻 (過濾死寂市場)
input double             InpMaxSpreadPoints   = 30;              // 最大允許點差點數 (點差過大不開倉)

input group "=== 大週期趨勢閘門 (Higher-TF Filter) ==="
input bool               InpUseHtfFilter      = true;            // 啟用大週期趨勢閘門 (順大勢過濾雜訊)
input ENUM_TIMEFRAMES    InpHtfTimeframe      = PERIOD_H4;       // 大週期時框 (Higher Timeframe)
input int                InpHtfEmaPeriod      = 200;             // 大週期基準均線週期 (EMA Period)

input group "=== 風險與動態保本鎖利 (Risk & Two-Stage Trailing) ==="
input double             InpAtrSlBufferMult   = 0.20;            // 波段外加 ATR 停損緩衝倍數 (SL = Swing ± x*ATR)
input double             InpMinSlAtrMult      = 1.00;            // 最小停損距離 (至少 x*ATR 距離)
input double             InpRiskRewardRatio   = 2.00;            // 停利風險報酬比 (R:R，例: 2.0 表示 1:2)
input bool               InpUseBreakEven      = true;            // 啟用第一階段保本機制 (Break-Even)
input double             InpBreakEvenAtrMult  = 1.0;             // 獲利達 x 倍 ATR 時觸發保本移損
input double             InpBreakEvenBufferPts= 20;              // 保本加碼緩衝點數 (覆蓋點差與手續費)
input bool               InpUseTrailingStop   = true;            // 啟用第二階段動態移動鎖利 (Trailing Stop)
input double             InpTrailingStartAtrMult = 1.8;          // 獲利達 x 倍 ATR 後啟動移動鎖利
input double             InpTrailingStepAtrMult  = 1.0;          // 移動鎖利跟隨距離 (x 倍 ATR)

input group "=== 部位與手數管理 (Position Sizing) ==="
input ENUM_LOT_MODE      InpLotSizeMode       = LOT_MODE_FIXED;  // 手數計算模式 (固定手數 / 風險比例)
input double             InpFixedLotSize      = 0.10;            // 固定手數大小 (固定手數模式生效)
input double             InpRiskPercent       = 1.00;            // 每筆交易風險比例 % (風險比例模式生效)

input group "=== 平倉冷卻與風控機制 (Cooldown Filter) ==="
input bool               InpUseCooldown       = true;            // 啟用平倉後進場冷卻 (防洗盤連續割肉)
input int                InpCooldownBars      = 3;               // 平倉後冷卻 K 棒根數 (Cooldown Bars)

input group "=== 交易時段與週末避險過濾 (Session & Weekend Guard) ==="
input bool               InpUseSessionFilter  = true;            // 啟用交易時段過濾 (僅在指定窗口開倉)
input int                InpSession1StartHour = 7;               // 第一時段起始小時 (倫敦盤 7)
input int                InpSession1EndHour   = 16;              // 第一時段結束小時 (倫敦盤 16)
input bool               InpUseSession2       = true;            // 啟用第二時段窗口
input int                InpSession2StartHour = 12;              // 第二時段起始小時 (紐約盤 12)
input int                InpSession2EndHour   = 21;              // 第二時段結束小時 (紐約盤 21)
input bool               InpUseFridayFilter   = true;            // 啟用週五週末避險過濾
input int                InpFridayStopHour    = 20;              // 週五停止開倉小時 (伺服器時間 20:00 後停開)

input group "=== 可選：突破進場引擎 (Breakout Engine) ==="
input bool               InpUseBreakoutEngine = false;           // 啟用突破進場模式 (Breakout Mode)
input int                InpBreakoutLookback  = 12;              // 突破回溯 K 棒根數 (Breakout Lookback Bars)
input double             InpBreakoutAdxMin    = 22.0;            // 突破進場最小 ADX 門檻
input double             InpBreakoutRsiBuyMin = 55.0;            // 突破做多最小 RSI (高於此值確認強勢)
input double             InpBreakoutRsiSellMax= 45.0;            // 突破做空最大 RSI (低於此值確認弱勢)

input group "=== 訂單追蹤與視覺看板 (Dashboard & UI) ==="
input bool               InpOnePositionPerSide= true;            // 限制單方向僅持有一倉 (防止同向重複加倉)
input bool               InpShowDashboard     = true;            // 顯示圖表半透明視覺儀表板

//============================== 全域變數 (GLOBALS) ==========================
CTrade   trade;

int      hEmaFast   = INVALID_HANDLE;
int      hEmaMedium = INVALID_HANDLE;
int      hEmaSlow   = INVALID_HANDLE;
int      hRsi       = INVALID_HANDLE;
int      hAdx       = INVALID_HANDLE;
int      hAtr       = INVALID_HANDLE;
int      hEmaHtf    = INVALID_HANDLE;

datetime g_lastBarTime = 0;
double   g_point       = 0.0;
int      g_digits      = 0;
string   g_dashPrefix  = "ATPB_Dash_";

// 前向宣告子函數
struct MarketSnapshot;
bool FillSnapshot(MarketSnapshot &s);
bool PassesNoTradeFilters(const MarketSnapshot &s);
bool PassesSessionFilter();
bool PassesFridayFilter();
bool PassesCooldownFilter();
bool PassesHtfFilter(int direction);
bool InRange(int hour, int startHour, int endHour);
bool GetSwingLowHigh(double &swingLow, double &swingHigh);
int  CheckPullbackSignal(const MarketSnapshot &s);
int  CheckBreakoutSignal(const MarketSnapshot &s);
int  CountOwnPositions(int direction);
double CalculateLotSize(double slDistance);
void OpenPosition(int direction, const MarketSnapshot &s, const string signalTag);
void ManageStops(const MarketSnapshot &s);
void UpdateDashboard(const MarketSnapshot &s);
void CleanupDashboard();

//+------------------------------------------------------------------------+
//| 市場數據快照結構                                                        |
//+------------------------------------------------------------------------+
struct MarketSnapshot
  {
   double emaFast[3];
   double emaMedium[3];
   double emaSlow[3];
   double rsi[3];
   double adxMain[3];
   double atr[3];
   double open[3];
   double high[3];
   double low[3];
   double close[3];
  };

#define IDX_PREV2  0   // shift 3 (倒數第 3 根收盤 K)
#define IDX_PREV1  1   // shift 2 (倒數第 2 根收盤 K)
#define IDX_LAST   2   // shift 1 (剛收盤的第 1 根 K)

//+------------------------------------------------------------------------+
//| 初始化函數 (OnInit)                                                    |
//+------------------------------------------------------------------------+
int OnInit()
  {
   if(InpEmaFastPeriod<=0 || InpEmaMediumPeriod<=0 || InpEmaSlowPeriod<=0 ||
      InpRsiPeriod<=0 || InpAdxPeriod<=0 || InpAtrPeriod<=0)
     {
      Print("錯誤: 指標週期參數必須大於 0。");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpEmaFastPeriod>=InpEmaMediumPeriod || InpEmaMediumPeriod>=InpEmaSlowPeriod)
     {
      Print("錯誤: EMA 週期必須滿足 快線 < 中線 < 慢線 (Fast < Medium < Slow)。");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRiskRewardRatio<=0.0 || InpMinSlAtrMult<=0.0)
     {
      Print("錯誤: 風險報酬比或最小停損倍數無效。");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLotSizeMode==LOT_MODE_RISK_PERCENT && InpRiskPercent<=0.0)
     {
      Print("錯誤: 風險比例模式下，風險百分比必須大於 0。");
      return(INIT_PARAMETERS_INCORRECT);
     }

   hEmaFast   = iMA(_Symbol, InpTimeframe, InpEmaFastPeriod,   0, MODE_EMA, PRICE_CLOSE);
   hEmaMedium = iMA(_Symbol, InpTimeframe, InpEmaMediumPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow   = iMA(_Symbol, InpTimeframe, InpEmaSlowPeriod,   0, MODE_EMA, PRICE_CLOSE);
   hRsi       = iRSI(_Symbol, InpTimeframe, InpRsiPeriod, PRICE_CLOSE);
   hAdx       = iADX(_Symbol, InpTimeframe, InpAdxPeriod);
   hAtr       = iATR(_Symbol, InpTimeframe, InpAtrPeriod);

   if(InpUseHtfFilter)
      hEmaHtf = iMA(_Symbol, InpHtfTimeframe, InpHtfEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(hEmaFast==INVALID_HANDLE || hEmaMedium==INVALID_HANDLE || hEmaSlow==INVALID_HANDLE ||
      hRsi==INVALID_HANDLE || hAdx==INVALID_HANDLE || hAtr==INVALID_HANDLE)
     {
      Print("錯誤: 無法建立主要指標 Handle，請檢查圖表數據。");
      return(INIT_FAILED);
     }
   if(InpUseHtfFilter && hEmaHtf==INVALID_HANDLE)
     {
      Print("警告: 無法建立大週期指標 Handle，大週期過濾將暫時跳過。");
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   // 自動適配券商支援的成交模式
   int fillingMask = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillingMask & SYMBOL_FILLING_FOK) != 0)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((fillingMask & SYMBOL_FILLING_IOC) != 0)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);

   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_lastBarTime = 0;

   Print("Adaptive Trend Pullback EA (商業旗艦全功能版 v2.00) 初始化成功。");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------------+
//| 反初始化函數 (OnDeinit)                                                |
//+------------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hEmaFast  !=INVALID_HANDLE) IndicatorRelease(hEmaFast);
   if(hEmaMedium!=INVALID_HANDLE) IndicatorRelease(hEmaMedium);
   if(hEmaSlow  !=INVALID_HANDLE) IndicatorRelease(hEmaSlow);
   if(hRsi      !=INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAdx      !=INVALID_HANDLE) IndicatorRelease(hAdx);
   if(hAtr      !=INVALID_HANDLE) IndicatorRelease(hAtr);
   if(hEmaHtf   !=INVALID_HANDLE) IndicatorRelease(hEmaHtf);

   CleanupDashboard();
   Comment("");
  }

//+------------------------------------------------------------------------+
//| 檢查新 K 棒生成                                                         |
//+------------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t = iTime(_Symbol, InpTimeframe, 0);
   if(t==0) return(false);
   if(t!=g_lastBarTime)
     {
      g_lastBarTime = t;
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------------+
//| 填入最新 3 根已收盤 K 棒之數據快照                                     |
//+------------------------------------------------------------------------+
bool FillSnapshot(MarketSnapshot &s)
  {
   if(CopyBuffer(hEmaFast,   0, 1, 3, s.emaFast)   != 3) return(false);
   if(CopyBuffer(hEmaMedium, 0, 1, 3, s.emaMedium) != 3) return(false);
   if(CopyBuffer(hEmaSlow,   0, 1, 3, s.emaSlow)   != 3) return(false);
   if(CopyBuffer(hRsi,       0, 1, 3, s.rsi)       != 3) return(false);
   if(CopyBuffer(hAdx,       0, 1, 3, s.adxMain)   != 3) return(false);
   if(CopyBuffer(hAtr,       0, 1, 3, s.atr)       != 3) return(false);

   double o[3], h[3], l[3], c[3];
   if(CopyOpen (_Symbol, InpTimeframe, 1, 3, o) != 3) return(false);
   if(CopyHigh (_Symbol, InpTimeframe, 1, 3, h) != 3) return(false);
   if(CopyLow  (_Symbol, InpTimeframe, 1, 3, l) != 3) return(false);
   if(CopyClose(_Symbol, InpTimeframe, 1, 3, c) != 3) return(false);

   for(int i=0; i<3; i++)
     {
      s.open[i]  = o[i];
      s.high[i]  = h[i];
      s.low[i]   = l[i];
      s.close[i] = c[i];
     }
   return(true);
  }

//+------------------------------------------------------------------------+
//| 不開倉環境過濾: 點差 / ATR 波動度 / 均線黏合 / ADX                     |
//+------------------------------------------------------------------------+
bool PassesNoTradeFilters(const MarketSnapshot &s)
  {
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spreadPoints > InpMaxSpreadPoints)
      return(false);

   double atrPoints = s.atr[IDX_LAST] / g_point;
   if(atrPoints < InpMinAtrPoints)
      return(false);

   double emaSeparationPts = MathAbs(s.emaFast[IDX_LAST] - s.emaMedium[IDX_LAST]) / g_point;
   if(emaSeparationPts < InpMinEmaSeparationPts)
      return(false);

   if(s.adxMain[IDX_LAST] < InpAdxMinThreshold)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------------+
//| 檢查是否符合交易時段 (以伺服器時間為準)                                 |
//+------------------------------------------------------------------------+
bool PassesSessionFilter()
  {
   if(!InpUseSessionFilter) return(true);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   bool inSession1 = InRange(hour, InpSession1StartHour, InpSession1EndHour);
   bool inSession2 = InpUseSession2 ? InRange(hour, InpSession2StartHour, InpSession2EndHour) : false;

   return(inSession1 || inSession2);
  }

//+------------------------------------------------------------------------+
//| 週五避險過濾 (週五美盤尾聲禁止新開倉)                                   |
//+------------------------------------------------------------------------+
bool PassesFridayFilter()
  {
   if(!InpUseFridayFilter) return(true);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= InpFridayStopHour)
      return(false);
   return(true);
  }

//+------------------------------------------------------------------------+
//| 進場冷卻機制 (平倉後 N 根 K 棒內禁止同 EA 重新進場)                    |
//+------------------------------------------------------------------------+
bool PassesCooldownFilter()
  {
   if(!InpUseCooldown || InpCooldownBars <= 0) return(true);
   datetime fromTime = TimeCurrent() - 7 * 86400;
   if(!HistorySelect(fromTime, TimeCurrent())) return(true);

   int totalDeals = HistoryDealsTotal();
   for(int i = totalDeals - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
        {
         datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         int barsSinceDeal = iBarShift(_Symbol, InpTimeframe, dealTime);
         if(barsSinceDeal >= 0 && barsSinceDeal < InpCooldownBars)
            return(false); // 仍在冷卻期內
         break;
        }
     }
   return(true);
  }

//+------------------------------------------------------------------------+
//| 大週期趨勢閘門過濾 (Higher-TF Gate)                                     |
//+------------------------------------------------------------------------+
bool PassesHtfFilter(int direction)
  {
   if(!InpUseHtfFilter) return(true);
   if(hEmaHtf == INVALID_HANDLE) return(true);

   double emaHtf[1];
   double closeHtf[1];
   if(CopyBuffer(hEmaHtf, 0, 1, 1, emaHtf) != 1) return(true);
   if(CopyClose(_Symbol, InpHtfTimeframe, 1, 1, closeHtf) != 1) return(true);

   if(direction == 1)  // 做多: H4 收盤價高於 H4 EMA
      return(closeHtf[0] >= emaHtf[0]);
   if(direction == -1) // 做空: H4 收盤價低於 H4 EMA
      return(closeHtf[0] <= emaHtf[0]);

   return(true);
  }

//+------------------------------------------------------------------------+
//| 時段範圍判定 (支援跨午夜)                                              |
//+------------------------------------------------------------------------+
bool InRange(int hour, int startHour, int endHour)
  {
   if(startHour==endHour) return(true);
   if(startHour < endHour)
      return(hour>=startHour && hour<endHour);
   return(hour>=startHour || hour<endHour);
  }

//+------------------------------------------------------------------------+
//| 計算過去 N 根已收盤 K 棒之波段高低點                                    |
//+------------------------------------------------------------------------+
bool GetSwingLowHigh(double &swingLow, double &swingHigh)
  {
   int bars = InpSwingLookback;
   if(bars<2) bars = 2;

   double lowArr[], highArr[];
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(highArr, true);

   if(CopyLow (_Symbol, InpTimeframe, 1, bars, lowArr)  != bars) return(false);
   if(CopyHigh(_Symbol, InpTimeframe, 1, bars, highArr) != bars) return(false);

   swingLow  = lowArr[ArrayMinimum(lowArr, 0, bars)];
   swingHigh = highArr[ArrayMaximum(highArr, 0, bars)];
   return(true);
  }

//+------------------------------------------------------------------------+
//| 趨勢回撤核心訊號: 回傳 1=做多(BUY), -1=做空(SELL), 0=無訊號            |
//+------------------------------------------------------------------------+
int CheckPullbackSignal(const MarketSnapshot &s)
  {
   bool trendUpAligned   = (s.emaFast[IDX_LAST] > s.emaMedium[IDX_LAST] &&
                            s.emaMedium[IDX_LAST] > s.emaSlow[IDX_LAST] &&
                            s.close[IDX_LAST] > s.emaSlow[IDX_LAST]);
   bool trendDownAligned = (s.emaFast[IDX_LAST] < s.emaMedium[IDX_LAST] &&
                            s.emaMedium[IDX_LAST] < s.emaSlow[IDX_LAST] &&
                            s.close[IDX_LAST] < s.emaSlow[IDX_LAST]);

   bool rsiCrossUp   = (s.rsi[IDX_PREV1] < InpRsiCrossLevel && s.rsi[IDX_LAST] > InpRsiCrossLevel);
   bool rsiCrossDown = (s.rsi[IDX_PREV1] > InpRsiCrossLevel && s.rsi[IDX_LAST] < InpRsiCrossLevel);

   // 做多條件
   if(trendUpAligned)
     {
      bool pulledBack = (s.low[IDX_LAST] <= s.emaFast[IDX_LAST] || s.low[IDX_LAST] <= s.emaMedium[IDX_LAST]);
      bool noCloseBelowMedium = (s.close[IDX_LAST] >= s.emaMedium[IDX_LAST]);
      bool bullishCandle = (s.close[IDX_LAST] > s.open[IDX_LAST]);
      bool confirmation  = (s.close[IDX_LAST] > s.high[IDX_PREV1]);

      if(pulledBack && noCloseBelowMedium && rsiCrossUp && bullishCandle && confirmation)
         return(1);
     }

   // 做空條件
   if(trendDownAligned)
     {
      bool pulledBack = (s.high[IDX_LAST] >= s.emaFast[IDX_LAST] || s.high[IDX_LAST] >= s.emaMedium[IDX_LAST]);
      bool noCloseAboveMedium = (s.close[IDX_LAST] <= s.emaMedium[IDX_LAST]);
      bool bearishCandle = (s.close[IDX_LAST] < s.open[IDX_LAST]);
      bool confirmation  = (s.close[IDX_LAST] < s.low[IDX_PREV1]);

      if(pulledBack && noCloseAboveMedium && rsiCrossDown && bearishCandle && confirmation)
         return(-1);
     }

   return(0);
  }

//+------------------------------------------------------------------------+
//| 可選突破訊號引擎: 回傳 1=做多, -1=做空, 0=無訊號                       |
//+------------------------------------------------------------------------+
int CheckBreakoutSignal(const MarketSnapshot &s)
  {
   if(!InpUseBreakoutEngine) return(0);

   int bars = InpBreakoutLookback;
   if(bars<2) bars = 2;

   double highArr[], lowArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr,  true);

   if(CopyHigh(_Symbol, InpTimeframe, 2, bars, highArr) != bars) return(0);
   if(CopyLow (_Symbol, InpTimeframe, 2, bars, lowArr)  != bars) return(0);

   double highestPrev = highArr[ArrayMaximum(highArr, 0, bars)];
   double lowestPrev  = lowArr[ArrayMinimum(lowArr, 0, bars)];

   bool trendUpAligned   = (s.emaFast[IDX_LAST] > s.emaMedium[IDX_LAST] && s.emaMedium[IDX_LAST] > s.emaSlow[IDX_LAST]);
   bool trendDownAligned = (s.emaFast[IDX_LAST] < s.emaMedium[IDX_LAST] && s.emaMedium[IDX_LAST] < s.emaSlow[IDX_LAST]);

   if(s.close[IDX_LAST] > highestPrev && trendUpAligned &&
      s.adxMain[IDX_LAST] > InpBreakoutAdxMin && s.rsi[IDX_LAST] > InpBreakoutRsiBuyMin)
      return(1);

   if(s.close[IDX_LAST] < lowestPrev && trendDownAligned &&
      s.adxMain[IDX_LAST] > InpBreakoutAdxMin && s.rsi[IDX_LAST] < InpBreakoutRsiSellMax)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------------+
//| 統計當前 EA 依魔術編號與方向之持倉數量                                  |
//+------------------------------------------------------------------------+
int CountOwnPositions(int direction) // 1=多單, -1=空單, 0=任一
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i=0; i<total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(direction==0) count++;
      else if(direction==1 && type==POSITION_TYPE_BUY) count++;
      else if(direction==-1 && type==POSITION_TYPE_SELL) count++;
     }
   return(count);
  }

//+------------------------------------------------------------------------+
//| 計算開倉手數 (支援固定手數與單筆風險比例模式)                           |
//+------------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
  {
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double lot;

   if(InpLotSizeMode==LOT_MODE_FIXED || slDistance<=0.0)
     {
      lot = InpFixedLotSize;
     }
   else
     {
      double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * InpRiskPercent / 100.0;

      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize<=0.0) tickSize = g_point;
      if(tickValue<=0.0)
        {
         lot = InpFixedLotSize;
        }
      else
        {
         double valuePerPriceUnitPerLot = tickValue / tickSize;
         double riskPerLot = slDistance * valuePerPriceUnitPerLot;
         if(riskPerLot<=0.0)
            lot = InpFixedLotSize;
         else
            lot = riskAmount / riskPerLot;
        }
     }

   if(lotStep>0.0)
      lot = MathFloor(lot/lotStep) * lotStep;

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   return(NormalizeDouble(lot, 2));
  }

//+------------------------------------------------------------------------+
//| 開倉進場邏輯 (動態計算波段高低 + ATR 停損與固定盈虧比停利)             |
//+------------------------------------------------------------------------+
void OpenPosition(int direction, const MarketSnapshot &s, const string signalTag)
  {
   if(InpOnePositionPerSide && CountOwnPositions(direction) > 0)
      return;

   // 順大勢 H4 閘門審查
   if(!PassesHtfFilter(direction))
      return;

   double swingLow=0.0, swingHigh=0.0;
   if(!GetSwingLowHigh(swingLow, swingHigh))
      return;

   double atr = s.atr[IDX_LAST];
   double minSlDist = InpMinSlAtrMult * atr;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   double entryPrice, slPrice, tpPrice, slDistance;

   if(direction==1)
     {
      entryPrice = tick.ask;
      slPrice    = swingLow - InpAtrSlBufferMult*atr;
      slDistance = entryPrice - slPrice;
      if(slDistance < minSlDist)
         slPrice = entryPrice - minSlDist;
      slDistance = entryPrice - slPrice;
      tpPrice    = entryPrice + InpRiskRewardRatio * slDistance;
     }
   else
     {
      entryPrice = tick.bid;
      slPrice    = swingHigh + InpAtrSlBufferMult*atr;
      slDistance = slPrice - entryPrice;
      if(slDistance < minSlDist)
         slPrice = entryPrice + minSlDist;
      slDistance = slPrice - entryPrice;
      tpPrice    = entryPrice - InpRiskRewardRatio * slDistance;
     }

   if(slDistance<=0.0)
      return;

   double lot = CalculateLotSize(slDistance);
   if(lot<=0.0)
      return;

   slPrice = NormalizeDouble(slPrice, g_digits);
   tpPrice = NormalizeDouble(tpPrice, g_digits);

   string comment = InpTradeComment + "_" + signalTag;

   if(direction==1)
      trade.Buy(lot, _Symbol, 0.0, slPrice, tpPrice, comment);
   else
      trade.Sell(lot, _Symbol, 0.0, slPrice, tpPrice, comment);
  }

//+------------------------------------------------------------------------+
//| 兩階段保本與動態鎖利管理 (Break-Even & Two-Stage Trailing)              |
//+------------------------------------------------------------------------+
void ManageStops(const MarketSnapshot &s)
  {
   if(!InpUseBreakEven && !InpUseTrailingStop) return;

   double atr = s.atr[IDX_LAST];
   if(atr<=0.0) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   int total = PositionsTotal();
   for(int i=0; i<total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      long   type      = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSl     = PositionGetDouble(POSITION_SL);
      double curTp     = PositionGetDouble(POSITION_TP);

      // 多單部位
      if(type==POSITION_TYPE_BUY)
        {
         double profit = tick.bid - openPrice;

         // 1. 第一階段：保本移損 (達到 1.0 ATR 後拉至開倉價 + 緩衝點數)
         if(InpUseBreakEven && profit >= InpBreakEvenAtrMult * atr)
           {
            double beSl = NormalizeDouble(openPrice + InpBreakEvenBufferPts * g_point, g_digits);
            if(beSl > curSl)
              {
               trade.PositionModify(ticket, beSl, curTp);
               curSl = beSl;
              }
           }

         // 2. 第二階段：動態移動鎖利 (達到 1.8 ATR 後寬幅跟隨)
         if(InpUseTrailingStop && profit >= InpTrailingStartAtrMult * atr)
           {
            double trailSl = NormalizeDouble(tick.bid - InpTrailingStepAtrMult * atr, g_digits);
            if(trailSl > curSl)
              {
               trade.PositionModify(ticket, trailSl, curTp);
              }
           }
        }
      // 空單部位
      else if(type==POSITION_TYPE_SELL)
        {
         double profit = openPrice - tick.ask;

         // 1. 第一階段：保本移損
         if(InpUseBreakEven && profit >= InpBreakEvenAtrMult * atr)
           {
            double beSl = NormalizeDouble(openPrice - InpBreakEvenBufferPts * g_point, g_digits);
            if(beSl < curSl || curSl==0.0)
              {
               trade.PositionModify(ticket, beSl, curTp);
               curSl = beSl;
              }
           }

         // 2. 第二階段：動態移動鎖利
         if(InpUseTrailingStop && profit >= InpTrailingStartAtrMult * atr)
           {
            double trailSl = NormalizeDouble(tick.ask + InpTrailingStepAtrMult * atr, g_digits);
            if(trailSl < curSl || curSl==0.0)
              {
               trade.PositionModify(ticket, trailSl, curTp);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------------+
//| 更新圖表視覺化儀表板 (GUI Dashboard)                                   |
//+------------------------------------------------------------------------+
void UpdateDashboard(const MarketSnapshot &s)
  {
   if(!InpShowDashboard) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;

   int startX = 20;
   int startY = 30;
   int width  = 280;
   int height = 210;

   // 背景面板
   string bgName = g_dashPrefix + "BG";
   if(ObjectFind(0, bgName) < 0)
     {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, startX);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, startY);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,24,35');
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'50,60,85');
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
     }

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double floatPnL= equity - balance;
   int    spread  = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   string htfStatus = "未啟用";
   if(InpUseHtfFilter && hEmaHtf != INVALID_HANDLE)
     {
      double emaHtf[1], closeHtf[1];
      if(CopyBuffer(hEmaHtf, 0, 1, 1, emaHtf)==1 && CopyClose(_Symbol, InpHtfTimeframe, 1, 1, closeHtf)==1)
         htfStatus = (closeHtf[0] >= emaHtf[0]) ? "多頭 (Bullish)" : "空頭 (Bearish)";
     }

   string lines[8];
   lines[0] = "【趨勢回撤旗艦系統 v2.0】";
   lines[1] = StringFormat("帳戶餘額: $%.2f | 浮動: $%.2f", balance, floatPnL);
   lines[2] = StringFormat("商品/時框: %s (%s)", _Symbol, EnumToString(InpTimeframe));
   lines[3] = StringFormat("當前點差: %d pts (門檻 %d)", spread, (int)InpMaxSpreadPoints);
   lines[4] = StringFormat("ADX 強度: %.1f (門檻 %.1f)", s.adxMain[IDX_LAST], InpAdxMinThreshold);
   lines[5] = StringFormat("H4 趨勢閘門: %s", htfStatus);
   lines[6] = StringFormat("多單持倉: %d | 空單持倉: %d", CountOwnPositions(1), CountOwnPositions(-1));
   lines[7] = "風控機制: 保本(1.0) + 追蹤(1.8) + 週五避險";

   for(int i=0; i<8; i++)
     {
      string lblName = g_dashPrefix + "Lbl_" + IntegerToString(i);
      if(ObjectFind(0, lblName) < 0)
        {
         ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, startX + 12);
         ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, startY + 12 + i * 23);
         ObjectSetString(0,  lblName, OBJPROP_FONT, "Segoe UI");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, (i==0)? 10 : 9);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
        }
      color txtColor = (i==0) ? C'0,220,255' : (i==1 && floatPnL>=0)? C'70,255,140' : (i==1 && floatPnL<0)? C'255,100,100' : C'220,225,235';
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, txtColor);
      ObjectSetString(0,  lblName, OBJPROP_TEXT, lines[i]);
     }
  }

//+------------------------------------------------------------------------+
//| 清除圖表視覺化儀表板物件                                               |
//+------------------------------------------------------------------------+
void CleanupDashboard()
  {
   ObjectsDeleteAll(0, g_dashPrefix);
  }

//+------------------------------------------------------------------------+
//| 主行情處理函數 (OnTick)                                                |
//+------------------------------------------------------------------------+
void OnTick()
  {
   MarketSnapshot s;
   if(!FillSnapshot(s))
      return;

   // 1. 每 tick 執行保本移損與動態移動鎖利管理
   ManageStops(s);

   // 2. 更新儀表板顯示
   UpdateDashboard(s);

   // 3. 進場訊號僅在新 K 棒生成 (剛收盤一根) 判定
   if(!IsNewBar())
      return;

   // 4. 時段窗口過濾
   if(!PassesSessionFilter())
      return;

   // 5. 週五收盤避險過濾
   if(!PassesFridayFilter())
      return;

   // 6. 平倉後冷卻期過濾
   if(!PassesCooldownFilter())
      return;

   // 7. 市場雜訊與波動度過濾 (點差 / ATR / 均線黏合 / ADX)
   if(!PassesNoTradeFilters(s))
      return;

   // 8. 核心趨勢回踩訊號判定
   int pullbackSignal = CheckPullbackSignal(s);
   if(pullbackSignal!=0)
     {
      OpenPosition(pullbackSignal, s, "Pullback");
      return;
     }

   // 9. 可選突破進場引擎判定
   int breakoutSignal = CheckBreakoutSignal(s);
   if(breakoutSignal!=0)
     {
      OpenPosition(breakoutSignal, s, "Breakout");
     }
  }
//+------------------------------------------------------------------------+
