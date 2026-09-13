# HFT Trend Pullback EA (Adaptive Trend Pullback)

本專案源自 YouTube 頻道 **Boxxocode** (Episode 92)：
* **影片連結**：[I Built an HFT Trading Bot with Claude AI… And The Results Shocked Me](https://www.youtube.com/watch?v=6pBix-Uauxo)
* **原始下載**：[Google Drive 原始資源](https://drive.google.com/file/d/1ReqGcXu5YnoNX8-h38DyunV5Tnb46TGK/view)

---

## 策略背景與本質

儘管宣傳標題使用了「HFT」（高頻交易），但實際上此策略為跑在 **EURUSD H1（或其他趨勢型商品與時框）** 的 **自適應多重指標趨勢回撤系統（Adaptive Trend Pullback Strategy）**。

---

## 核心交易邏輯

### 1. 指標設定
* **趨勢結構**：EMA 20（快線）、EMA 50（中線）、EMA 100/200（慢線）
* **動能指標**：RSI 7（中軸 50 穿越過濾）
* **趨勢強弱**：ADX 7（過濾震盪，要求 > 22.0）
* **波動度與風控**：ATR 7
* **波段回顧**：過去 20 根 K 線的波段高低點（Swing High / Low）

### 2. 做多 (BUY) 規則
1. **多頭排列**：EMA 20 > EMA 50 > EMA 100，且收盤價 > EMA 100
2. **趨勢強度**：ADX(7) > 22.0
3. **回踩測試（Pullback）**：K 線最低價觸碰或跌穿 EMA 20 或 EMA 50，且**收盤價不可跌破 EMA 50**
4. **動能翻多**：RSI(7) 由下往上穿越 50（前根 < 50，當前根 > 50）
5. **K 線型態確認**：當前 K 線為陽線（Close > Open），且收盤價突破前一根高點（Close > Previous High）
6. **進場**：於次根 K 線開盤時進場多單

### 3. 做空 (SELL) 規則
1. **空頭排列**：EMA 20 < EMA 50 < EMA 100，且收盤價 < EMA 100
2. **趨勢強度**：ADX(7) > 22.0
3. **回踩測試（Pullback）**：K 線最高價觸碰或升破 EMA 20 或 EMA 50，且**收盤價不可收在 EMA 50 之上**
4. **動能翻空**：RSI(7) 由上往下穿越 50（前根 > 50，當前根 < 50）
5. **K 線型態確認**：當前 K 線為陰線（Close < Open），且收盤價跌破前一根低點（Close < Previous Low）
6. **進場**：於次根 K 線開盤時進場空單

### 4. 風控與出場管理
* **動態停損 (SL)**：
  * 多單：$\text{Swing Low} - 0.20 \times \text{ATR}$（最低保證距離 $\ge 1.0 \times \text{ATR}$）
  * 空單：$\text{Swing High} + 0.20 \times \text{ATR}$（最低保證距離 $\ge 1.0 \times \text{ATR}$）
* **動態停利 (TP)**：固定盈虧比 $1 : 2$（$R:R = 2.0$）
* **手數管理**：支援 Fixed Lot（固定手數）與 Risk Percent（單筆風險 1% 權益計算）
* **可選模組**：
  * 12 根 K 棒唐奇安突破引擎（Breakout Engine）
  * 倫敦/紐約交易時間過濾（Session Filter）
  * ATR 移動停損追蹤（Trailing Stop）

---

## 檔案結構說明

| 檔案名稱 | 說明 |
| :--- | :--- |
| `AdaptiveTrendPullback_EA_CN.mq5` | **MT5 EA 繁體中文參數版原始代碼**（參數欄位與圖表提示全面中文化） |
| `AdaptiveTrendPullback_EA_CN.ex5` | **MT5 EA 繁體中文版已編譯執行檔**（可直接拖曳至圖表運行） |
| `HFT Trend Pullback (claude ai).mq5` | 原始英文版 MQL5 原始代碼 |
| `HFT Trend Pullback (claude ai).ex5` | 原始英文版 MT5 已編譯執行檔 |
| `HFT_Adaptive_Trend_Pullback_Strategy.docx` | 策略原始規格說明文件 |
| `HFT_Trend_Pullback.pine` | TradingView Pine Script v5 策略腳本（方便圖表回測與視覺化） |
| `Warning!!!.txt` | 原始免責聲明 |
| `README.md` | 本專案詳細指南與邏輯解析 |
