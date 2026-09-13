//+------------------------------------------------------------------------+
//|                                     AdaptiveTrendPullback_EA.mq5        |
//|                    Adaptive Trend Pullback (EMA/RSI/ADX/ATR) Strategy   |
//|                                                                          |
//|  Works on any symbol / any timeframe (default H1, as designed).         |
//|  Trend alignment (EMA20/50/200) + pullback + RSI-50 cross + ADX filter  |
//|  + ATR based dynamic SL/TP, optional breakout engine, optional session  |
//|  filter, spread / volatility / flat-market no-trade filters.            |
//+------------------------------------------------------------------------+
#property copyright "Enterprise EA Development"
#property version   "1.00"
#property strict
#property description "Adaptive Trend Pullback EA - EMA/RSI/ADX/ATR based trend-pullback system"

#include <Trade\Trade.mqh>

//============================== ENUMS ======================================
enum ENUM_LOT_MODE
  {
   LOT_MODE_FIXED = 0,      // Fixed Lot
   LOT_MODE_RISK_PERCENT=1  // Risk Percent
  };

//============================== INPUTS ======================================
input group "=== General Settings ==="
input long              InpMagicNumber        = 123456;          // Magic Number (unique per EA/chart)
input string            InpTradeComment       = "AdaptiveTrendPB";// Trade comment
input int               InpSlippagePoints     = 20;               // Max allowed slippage (points)
input ENUM_TIMEFRAMES   InpTimeframe          = PERIOD_H1;         // Working timeframe

input group "=== Indicator Periods ==="
input int                InpEmaFastPeriod     = 20;    // EMA Fast period
input int                InpEmaMediumPeriod   = 50;    // EMA Medium period
input int                InpEmaSlowPeriod     = 100;   // EMA Slow period
input int                InpRsiPeriod         = 7;    // RSI period
input int                InpAdxPeriod         = 7;    // ADX period
input int                InpAtrPeriod         = 7;    // ATR period

input group "=== Signal Filters ==="
input double             InpAdxMinThreshold   = 22.0;  // Minimum ADX to allow trading
input double             InpRsiCrossLevel     = 50.0;  // RSI cross level
input int                InpSwingLookback     = 20;    // Bars back to find swing High/Low
input double             InpMinEmaSeparationPts = 30;  // Min EMA20-EMA50 separation (points) - flat filter
input double             InpMinAtrPoints      = 50;    // Minimum ATR (points) required to trade
input double             InpMaxSpreadPoints   = 30;    // Maximum allowed spread (points)

input group "=== Risk Management ==="
input double             InpAtrSlBufferMult   = 0.20;  // SL buffer beyond swing = x * ATR
input double             InpMinSlAtrMult      = 1.00;  // Minimum SL distance = x * ATR
input double             InpRiskRewardRatio   = 2.00;  // Take Profit Risk:Reward ratio

input group "=== Position Sizing ==="
input ENUM_LOT_MODE      InpLotSizeMode       = LOT_MODE_FIXED; // Lot sizing mode
input double             InpFixedLotSize      = 0.10;  // Fixed lot size (used if mode=Fixed)
input double             InpRiskPercent       = 1.00;  // Risk % per trade (used if mode=RiskPercent)

input group "=== Optional Breakout Engine ==="
input bool                InpUseBreakoutEngine = false; // Enable breakout entries
input int                 InpBreakoutLookback  = 12;    // Breakout lookback bars
input double              InpBreakoutAdxMin    = 22.0;  // Min ADX for breakout entry
input double              InpBreakoutRsiBuyMin = 55.0;  // Min RSI for breakout BUY
input double              InpBreakoutRsiSellMax= 45.0;  // Max RSI for breakout SELL

input group "=== Session Filter (Server Time) ==="
input bool                InpUseSessionFilter  = false; // Enable trading-session filter
input int                 InpSession1StartHour = 7;     // London session start hour
input int                 InpSession1EndHour   = 16;    // London session end hour
input bool                InpUseSession2       = true;  // Enable 2nd session window (NY)
input int                 InpSession2StartHour = 12;    // New York session start hour
input int                 InpSession2EndHour   = 21;    // New York session end hour

input group "=== Trade Management ==="
input bool                InpOnePositionPerSide= true;  // Allow only 1 open position per direction
input bool                InpUseTrailingStop   = false; // Enable ATR based trailing stop
input double              InpTrailingStartAtrMult = 1.0;// Start trailing after x*ATR profit
input double              InpTrailingStepAtrMult  = 0.5;// Trailing distance = x*ATR

//============================== GLOBALS ======================================
CTrade   trade;

int      hEmaFast   = INVALID_HANDLE;
int      hEmaMedium = INVALID_HANDLE;
int      hEmaSlow   = INVALID_HANDLE;
int      hRsi       = INVALID_HANDLE;
int      hAdx       = INVALID_HANDLE;
int      hAtr       = INVALID_HANDLE;

datetime g_lastBarTime = 0;
double   g_point       = 0.0;
int      g_digits      = 0;

//+------------------------------------------------------------------------+
//| Expert initialization                                                   |
//+------------------------------------------------------------------------+
int OnInit()
  {
   if(InpEmaFastPeriod<=0 || InpEmaMediumPeriod<=0 || InpEmaSlowPeriod<=0 ||
      InpRsiPeriod<=0 || InpAdxPeriod<=0 || InpAtrPeriod<=0)
     {
      Print("AdaptiveTrendPullback_EA: invalid indicator period input(s).");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpEmaFastPeriod>=InpEmaMediumPeriod || InpEmaMediumPeriod>=InpEmaSlowPeriod)
     {
      Print("AdaptiveTrendPullback_EA: EMA periods must satisfy Fast < Medium < Slow.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRiskRewardRatio<=0.0 || InpMinSlAtrMult<=0.0)
     {
      Print("AdaptiveTrendPullback_EA: invalid risk/reward or SL multiplier.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLotSizeMode==LOT_MODE_RISK_PERCENT && InpRiskPercent<=0.0)
     {
      Print("AdaptiveTrendPullback_EA: Risk Percent must be > 0 in Risk Percent mode.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   hEmaFast   = iMA(_Symbol, InpTimeframe, InpEmaFastPeriod,   0, MODE_EMA, PRICE_CLOSE);
   hEmaMedium = iMA(_Symbol, InpTimeframe, InpEmaMediumPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow   = iMA(_Symbol, InpTimeframe, InpEmaSlowPeriod,   0, MODE_EMA, PRICE_CLOSE);
   hRsi       = iRSI(_Symbol, InpTimeframe, InpRsiPeriod, PRICE_CLOSE);
   hAdx       = iADX(_Symbol, InpTimeframe, InpAdxPeriod);
   hAtr       = iATR(_Symbol, InpTimeframe, InpAtrPeriod);

   if(hEmaFast==INVALID_HANDLE || hEmaMedium==INVALID_HANDLE || hEmaSlow==INVALID_HANDLE ||
      hRsi==INVALID_HANDLE || hAdx==INVALID_HANDLE || hAtr==INVALID_HANDLE)
     {
      Print("AdaptiveTrendPullback_EA: failed to create one or more indicator handles.");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   // Pick a filling mode the symbol actually supports (avoids "Unsupported
   // filling mode" rejects across different brokers/symbols)
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

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------------+
//| Expert deinitialization                                                 |
//+------------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hEmaFast  !=INVALID_HANDLE) IndicatorRelease(hEmaFast);
   if(hEmaMedium!=INVALID_HANDLE) IndicatorRelease(hEmaMedium);
   if(hEmaSlow  !=INVALID_HANDLE) IndicatorRelease(hEmaSlow);
   if(hRsi      !=INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAdx      !=INVALID_HANDLE) IndicatorRelease(hAdx);
   if(hAtr      !=INVALID_HANDLE) IndicatorRelease(hAtr);
  }

//+------------------------------------------------------------------------+
//| Returns true once per new closed bar on the working timeframe           |
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
//| Trade-data container for one evaluation pass                            |
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

//+------------------------------------------------------------------------+
//| Fill the snapshot with the last 3 bars (idx1=last closed, idx2=prior)   |
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

   // CopyBuffer/CopyXXX with start=1 returns arrays indexed 0..2 where
   // index 0 == bar shift 3 (oldest), index 2 == bar shift 1 (last closed).
   // We re-map so index [LAST]=last closed bar, [PREV]=bar before it.
   return(true);
  }

// convenient shift indices into the 3-element arrays filled above
#define IDX_PREV2  0   // shift 3 (two bars before last closed)
#define IDX_PREV1  1   // shift 2 (one bar before last closed)
#define IDX_LAST   2   // shift 1 (last closed bar)

//+------------------------------------------------------------------------+
//| No-trade filters: spread / ATR / flat-market                            |
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
//| Session filter (broker/server time)                                     |
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
//| Hour-range check, handles ranges that wrap past midnight                |
//+------------------------------------------------------------------------+
bool InRange(int hour, int startHour, int endHour)
  {
   if(startHour==endHour) return(true); // 24h window
   if(startHour < endHour)
      return(hour>=startHour && hour<endHour);
   // wraps midnight
   return(hour>=startHour || hour<endHour);
  }

//+------------------------------------------------------------------------+
//| Swing low / high over InpSwingLookback bars ending at the last closed  |
//| bar (shift 1)                                                           |
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
//| Pullback strategy signal: returns 1=BUY, -1=SELL, 0=no signal           |
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

   if(trendUpAligned)
     {
      bool pulledBack = (s.low[IDX_LAST] <= s.emaFast[IDX_LAST] || s.low[IDX_LAST] <= s.emaMedium[IDX_LAST]);
      bool noCloseBelowMedium = (s.close[IDX_LAST] >= s.emaMedium[IDX_LAST]);
      bool bullishCandle = (s.close[IDX_LAST] > s.open[IDX_LAST]);
      bool confirmation  = (s.close[IDX_LAST] > s.high[IDX_PREV1]);

      if(pulledBack && noCloseBelowMedium && rsiCrossUp && bullishCandle && confirmation)
         return(1);
     }

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
//| Optional breakout signal: returns 1=BUY, -1=SELL, 0=no signal           |
//+------------------------------------------------------------------------+
int CheckBreakoutSignal(const MarketSnapshot &s)
  {
   if(!InpUseBreakoutEngine) return(0);

   int bars = InpBreakoutLookback;
   if(bars<2) bars = 2;

   double highArr[], lowArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr,  true);

   // exclude the last closed bar itself: start copy from shift 2
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
//| Count open positions for this EA/symbol, optionally by direction        |
//+------------------------------------------------------------------------+
int CountOwnPositions(int direction) // 1=buy,-1=sell,0=any
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
//| Position sizing                                                         |
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
         lot = InpFixedLotSize; // fallback if broker data unavailable
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
//| Open a position in the given direction using ATR based SL/TP            |
//+------------------------------------------------------------------------+
void OpenPosition(int direction, const MarketSnapshot &s, const string signalTag)
  {
   if(InpOnePositionPerSide && CountOwnPositions(direction) > 0)
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
//| Optional ATR based trailing stop, applied to own open positions         |
//+------------------------------------------------------------------------+
void ManageTrailingStop(const MarketSnapshot &s)
  {
   if(!InpUseTrailingStop) return;

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
      double curSl      = PositionGetDouble(POSITION_SL);
      double curTp      = PositionGetDouble(POSITION_TP);

      if(type==POSITION_TYPE_BUY)
        {
         double profit = tick.bid - openPrice;
         if(profit >= InpTrailingStartAtrMult*atr)
           {
            double newSl = NormalizeDouble(tick.bid - InpTrailingStepAtrMult*atr, g_digits);
            if(newSl > curSl)
               trade.PositionModify(ticket, newSl, curTp);
           }
        }
      else if(type==POSITION_TYPE_SELL)
        {
         double profit = openPrice - tick.ask;
         if(profit >= InpTrailingStartAtrMult*atr)
           {
            double newSl = NormalizeDouble(tick.ask + InpTrailingStepAtrMult*atr, g_digits);
            if(newSl < curSl || curSl==0.0)
               trade.PositionModify(ticket, newSl, curTp);
           }
        }
     }
  }

//+------------------------------------------------------------------------+
//| Expert tick function                                                    |
//+------------------------------------------------------------------------+
void OnTick()
  {
   //Show Equity and Balance
   Comment ( StringFormat ( "Equity is %.2f and Balance is %.2f", AccountInfoDouble (ACCOUNT_EQUITY), AccountInfoDouble(ACCOUNT_BALANCE)));
   MarketSnapshot s;

   // Trailing stop can be managed every tick (uses latest closed-bar ATR)
   if(InpUseTrailingStop)
     {
      if(FillSnapshot(s))
         ManageTrailingStop(s);
     }

   if(!IsNewBar())
      return;

   if(!FillSnapshot(s))
      return;

   if(!PassesSessionFilter())
      return;

   if(!PassesNoTradeFilters(s))
      return;

   int pullbackSignal = CheckPullbackSignal(s);
   if(pullbackSignal!=0)
     {
      OpenPosition(pullbackSignal, s, "Pullback");
      return;
     }

   int breakoutSignal = CheckBreakoutSignal(s);
   if(breakoutSignal!=0)
     {
      OpenPosition(breakoutSignal, s, "Breakout");
     }
  }
//+------------------------------------------------------------------------+