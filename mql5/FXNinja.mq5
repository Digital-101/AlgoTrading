//+------------------------------------------------------------------+
//|                                                      FXNinja.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.20"

//+------------------------------------------------------------------+
//| Includes                                                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>
#include <Indicators\BillWilliams.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
input int      MAPeriod = 14;             // MA Period
input int      RSIPeriod = 14;            // RSI Period
input int      BBPeriod = 20;             // Bollinger Bands Period
input double   BBDeviation = 2.0;         // Bollinger Bands Deviation
input double   StopLoss = 50;             // Stop Loss (pips)
input double   TakeProfit = 100;          // Take Profit (pips)
input double   RiskPerTrade = 1.0;        // Risk % per trade (1.0 = 1%)
input int      MaxSlippage = 3;           // Maximum slippage (points)
input color    BuyColor = clrDodgerBlue;  // Buy signal color
input color    SellColor = clrOrangeRed;  // Sell signal color
input int      FontSize = 10;             // Display font size
input double   MaxPositionSize = 10.0;    // Maximum lot size allowed

//+------------------------------------------------------------------+
//| Global Variables                                                |
//+------------------------------------------------------------------+
CTrade trade;
int maHandle, rsiHandle, bbHandle;
datetime lastBarTime;
CChartObjectLabel infoLabel, signalLabel, maLabel, rsiLabel, bbLabel;

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicators
   maHandle = iMA(_Symbol, _Period, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   bbHandle = iBands(_Symbol, _Period, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   
   if(maHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || bbHandle == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return(INIT_FAILED);
   }
   
   // Configure trade settings
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Create display labels
   CreateInfoLabels();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Create information labels on chart                              |
//+------------------------------------------------------------------+
void CreateInfoLabels()
{
   // Info label
   infoLabel.Create(0, "InfoLabel", 0, 10, 20);
   infoLabel.Description("FX Ninja EA v2.20");
   infoLabel.Color(clrWhite);
   infoLabel.FontSize(FontSize);
   
   // Signal label
   signalLabel.Create(0, "SignalLabel", 0, 10, 50);
   signalLabel.Description("Waiting for signal...");
   signalLabel.Color(clrGray);
   signalLabel.FontSize(FontSize + 2);
   signalLabel.Font("Arial Bold");
   
   // MA label
   maLabel.Create(0, "MALabel", 0, 10, 80);
   maLabel.Description("MA: -");
   maLabel.Color(clrGold);
   maLabel.FontSize(FontSize);
   
   // RSI label
   rsiLabel.Create(0, "RSILabel", 0, 10, 110);
   rsiLabel.Description("RSI: -");
   rsiLabel.Color(clrDeepSkyBlue);
   rsiLabel.FontSize(FontSize);
   
   // BB label
   bbLabel.Create(0, "BBLabel", 0, 10, 140);
   bbLabel.Description("BB: -");
   bbLabel.Color(clrLimeGreen);
   bbLabel.FontSize(FontSize);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicators
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   
   // Remove labels
   infoLabel.Delete();
   signalLabel.Delete();
   maLabel.Delete();
   rsiLabel.Delete();
   bbLabel.Delete();
}

//+------------------------------------------------------------------+
//| Calculate safe lot size with volume limits                      |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * RiskPerTrade / 100;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue == 0 || tickSize == 0 || point == 0 || StopLoss == 0)
   {
      Print("Error in lot size calculation parameters");
      return(0);
   }
   
   // Calculate lot size based on risk
   double lotSize = riskAmount / (StopLoss * tickValue * (point / tickSize));
   
   // Get broker volume constraints
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Apply user-defined maximum position size
   maxLot = MathMin(maxLot, MaxPositionSize);
   
   // Normalize lot size
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Margin check
   double marginRequired;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginRequired))
   {
      Print("Error calculating margin requirements");
      return(0);
   }
      
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(marginRequired > freeMargin)
   {
      // Reduce lot size to fit available margin
      double maxLotByMargin = freeMargin / marginRequired * lotSize;
      maxLotByMargin = MathFloor(maxLotByMargin / lotStep) * lotStep;
      lotSize = MathMax(minLot, MathMin(maxLotByMargin, lotSize));
   }
   
   return(lotSize);
}

//+------------------------------------------------------------------+
//| Validate stop levels                                            |
//+------------------------------------------------------------------+
bool ValidateStops(double entryPrice, double &sl, double &tp, bool isBuy)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   
   // Get broker stop level requirements
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   
   // Calculate minimum distances
   double minDist = stopLevel * point;
   double freezeDist = freezeLevel * point;
   
   // Set reasonable defaults if zero
   if(minDist <= 0) minDist = 10 * point;
   if(freezeDist <= 0) freezeDist = minDist;
   
   // Calculate required minimum distance
   double requiredDist = MathMax(minDist, freezeDist) + spread;
   
   if(isBuy) // Buy order
   {
      sl = entryPrice - StopLoss * point;
      tp = entryPrice + TakeProfit * point;
      
      // Adjust if too close
      if((entryPrice - sl) < requiredDist) sl = entryPrice - requiredDist;
      if((tp - entryPrice) < requiredDist) tp = entryPrice + requiredDist;
      
      // Final validation
      if(sl >= entryPrice || tp <= entryPrice) return false;
   }
   else // Sell order
   {
      sl = entryPrice + StopLoss * point;
      tp = entryPrice - TakeProfit * point;
      
      // Adjust if too close
      if((sl - entryPrice) < requiredDist) sl = entryPrice + requiredDist;
      if((entryPrice - tp) < requiredDist) tp = entryPrice - requiredDist;
      
      // Final validation
      if(sl <= entryPrice || tp >= entryPrice) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update display labels                                           |
//+------------------------------------------------------------------+
void UpdateDisplay(double maValue, double rsiValue, double bbUpper, double bbLower, double bbMiddle, string signal)
{
   // Update info label
   string infoText = StringFormat("FX Ninja EA v2.20\nSymbol: %s\nTime: %s\nBalance: %.2f %s",
                                 _Symbol, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                                 AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoString(ACCOUNT_CURRENCY));
   infoLabel.Description(infoText);
   
   // Update signal label
   signalLabel.Description("Signal: " + signal);
   signalLabel.Color(signal == "BUY" ? BuyColor : (signal == "SELL" ? SellColor : clrGray));
   
   // Update MA label
   maLabel.Description(StringFormat("MA(%d): %.5f", MAPeriod, maValue));
   
   // Update RSI label
   rsiLabel.Description(StringFormat("RSI(%d): %.2f", RSIPeriod, rsiValue));
   rsiLabel.Color((rsiValue > 70) ? SellColor : ((rsiValue < 30) ? BuyColor : clrDeepSkyBlue));
   
   // Update BB label
   bbLabel.Description(StringFormat("BB(%d,%.1f): %.5f | %.5f | %.5f", 
                                   BBPeriod, BBDeviation, bbUpper, bbMiddle, bbLower));
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;
   
   // Get indicator values
   double ma[1], rsi[1], bbUpper[1], bbLower[1], bbMiddle[1];
   if(CopyBuffer(maHandle, 0, 0, 1, ma) != 1 ||
      CopyBuffer(rsiHandle, 0, 0, 1, rsi) != 1 ||
      CopyBuffer(bbHandle, 1, 0, 1, bbUpper) != 1 ||
      CopyBuffer(bbHandle, 2, 0, 1, bbLower) != 1 ||
      CopyBuffer(bbHandle, 0, 0, 1, bbMiddle) != 1)
   {
      Print("Error copying indicator buffers");
      UpdateDisplay(0, 0, 0, 0, 0, "Data Error");
      return;
   }
   
   // Get current prices
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Check for open positions
   if(PositionsTotal() > 0)
   {
      UpdateDisplay(ma[0], rsi[0], bbUpper[0], bbLower[0], bbMiddle[0], "Position Open");
      return;
   }
   
   // Calculate lot size
   double lotSize = CalculateLotSize();
   if(lotSize <= 0)
   {
      Print("Invalid lot size calculation");
      UpdateDisplay(ma[0], rsi[0], bbUpper[0], bbLower[0], bbMiddle[0], "Lot Size Error");
      return;
   }
   
   // Trading logic - RSI + Bollinger Bands strategy
   string signal = "None";
   if(rsi[0] < 30 && bid < bbLower[0]) // Buy signal (oversold and below lower band)
   {
      signal = "BUY";
      double sl, tp;
      if(ValidateStops(ask, sl, tp, true))
      {
         if(!trade.Buy(lotSize, _Symbol, ask, sl, tp, "RSI/BB Buy"))
            Print("Buy order failed. Error: ", GetLastError(), " Lot Size: ", lotSize);
      }
   }
   else if(rsi[0] > 70 && bid > bbUpper[0]) // Sell signal (overbought and above upper band)
   {
      signal = "SELL";
      double sl, tp;
      if(ValidateStops(bid, sl, tp, false))
      {
         if(!trade.Sell(lotSize, _Symbol, bid, sl, tp, "RSI/BB Sell"))
            Print("Sell order failed. Error: ", GetLastError(), " Lot Size: ", lotSize);
      }
   }
   
   // Update display
   UpdateDisplay(ma[0], rsi[0], bbUpper[0], bbLower[0], bbMiddle[0], signal);
}
//+------------------------------------------------------------------+