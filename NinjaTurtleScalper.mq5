//+------------------------------------------------------------------+
//|                      NinjaTurtleScalperEA.mq5                    |
//|                        Copyright 2025, AutomateX           |
//|                     Complete Working Version                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, AutomateX"
#property link      "https://automatex.vercel.app/"
#property version   "5.0"
#include <Trade/Trade.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
input int      DonchianPeriod   = 20;       // Channel period (15-50)
input double   RiskPercent      = 1.0;      // Risk per trade (0.1-2%)
input double   TrailingStopATR  = 1.5;      // ATR multiplier for stop (1.0-3.0)
input double   TakeProfitATR    = 3.0;      // ATR multiplier for TP (2.0-5.0)
input int      MaxTrades        = 1;        // Max simultaneous trades
input int      Slippage         = 3;        // Max allowed slippage
input string   TradeComment     = "NinjaTurtle"; 
input bool     UseTimeFilter    = true;     // Enable time filter
input string   TradeStartTime   = "08:00";  // Start time (HH:MM)
input string   TradeEndTime     = "16:00";  // End time (HH:MM)
input bool     ShowVisuals      = true;     // Show channel visuals
input bool     EnableAlerts     = true;     // Enable popup alerts

//+------------------------------------------------------------------+
//| Global Variables                                                |
//+------------------------------------------------------------------+
CTrade trade;
int atrHandle;
double lotSize;
datetime lastBarTime;
double upperChannel, lowerChannel, currentATR;
CChartObjectLabel infoLabel;
bool tradeOpenedToday = false;
ulong currentTicket = 0;

//+------------------------------------------------------------------+
//| Expert Initialization Function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize ATR indicator
   atrHandle = iATR(_Symbol, _Period, 14);
   
   if(atrHandle == INVALID_HANDLE)
   {
      Alert("Error creating ATR indicator!");
      return(INIT_FAILED);
   }
   
   // Configure trade object
   trade.SetExpertMagicNumber(12347);
   trade.SetDeviationInPoints(Slippage);
   
   // Create info panel if visuals enabled
   if(ShowVisuals) 
   {
      createInfoPanel();
      drawChannelVisuals();
   }
   
   // Check for existing positions
   checkExistingPositions();
   
   if(EnableAlerts) Alert("Ninja Turtle Scalper EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ShowVisuals) ObjectsDeleteAll(0, -1, -1);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process on new bar or if we have open positions
   if(!isNewBar() && PositionsTotal() == 0) return;
   
   // Calculate Donchian Channel
   calculateDonchianChannel();
   
   // Update ATR value
   updateATR();
   
   // Update visuals if enabled
   if(ShowVisuals) 
   {
      updateInfoPanel();
      drawChannelVisuals();
   }
   
   // Manage existing trades first
   if(PositionsTotal() > 0) 
   {
      manageTrades();
      return;
   }
   
   // Check for new entry signals
   if(canTrade() && checkEntrySignals())
   {
      if(EnableAlerts) Alert("New trade signal detected");
   }
}

//+------------------------------------------------------------------+
//| Calculate Donchian Channel                                      |
//+------------------------------------------------------------------+
void calculateDonchianChannel()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, _Period, 0, DonchianPeriod, rates) < DonchianPeriod)
   {
      Print("Error copying price data for Donchian Channel");
      return;
   }
   
   double highestHigh = rates[0].high;
   double lowestLow = rates[0].low;
   
   for(int i = 1; i < DonchianPeriod; i++)
   {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow) lowestLow = rates[i].low;
   }
   
   upperChannel = highestHigh;
   lowerChannel = lowestLow;
}

//+------------------------------------------------------------------+
//| Update ATR Value                                                |
//+------------------------------------------------------------------+
void updateATR()
{
   double atrArray[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) != 1)
   {
      Print("Error copying ATR buffer");
      return;
   }
   currentATR = atrArray[0];
   
   // Calculate position size whenever ATR updates
   calculateLotSize();
}

//+------------------------------------------------------------------+
//| Create Information Panel                                        |
//+------------------------------------------------------------------+
void createInfoPanel()
{
   infoLabel.Create(0, "NinjaTurtleInfo", 0, 10, 20);
   infoLabel.Description("Ninja Turtle Scalper EA\nInitializing...");
   infoLabel.Color(clrDodgerBlue);
   infoLabel.FontSize(10);
   infoLabel.Font("Arial");
}

//+------------------------------------------------------------------+
//| Update Information Panel                                        |
//+------------------------------------------------------------------+
void updateInfoPanel()
{
   string status = StringFormat(
      "Ninja Turtle Scalper EA\nUpper: %.5f\nLower: %.5f\nATR: %.5f\nLots: %.2f\n%s",
      upperChannel, lowerChannel, currentATR, lotSize,
      PositionsTotal() > 0 ? "POSITION OPEN" : "Waiting for signal"
   );
   infoLabel.Description(status);
}

//+------------------------------------------------------------------+
//| Draw Channel Visuals                                            |
//+------------------------------------------------------------------+
void drawChannelVisuals()
{
   ObjectDelete(0, "UpperChannel");
   ObjectDelete(0, "LowerChannel");
   
   ObjectCreate(0, "UpperChannel", OBJ_HLINE, 0, 0, upperChannel);
   ObjectSetInteger(0, "UpperChannel", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "UpperChannel", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "UpperChannel", OBJPROP_WIDTH, 2);
   
   ObjectCreate(0, "LowerChannel", OBJ_HLINE, 0, 0, lowerChannel);
   ObjectSetInteger(0, "LowerChannel", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "LowerChannel", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "LowerChannel", OBJPROP_WIDTH, 2);
}

//+------------------------------------------------------------------+
//| Check Existing Positions                                        |
//+------------------------------------------------------------------+
void checkExistingPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_COMMENT) == TradeComment)
      {
         currentTicket = ticket;
         tradeOpenedToday = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Check Trading Conditions                                        |
//+------------------------------------------------------------------+
bool canTrade()
{
   if(PositionsTotal() >= MaxTrades) return false;
   if(UseTimeFilter && !isTradingTime()) return false;
   if(tradeOpenedToday) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Check for Entry Signals                                         |
//+------------------------------------------------------------------+
bool checkEntrySignals()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Long signal
   if(bid > upperChannel)
   {
      double sl = NormalizeDouble(bid - (currentATR * TrailingStopATR), _Digits);
      double tp = NormalizeDouble(bid + (currentATR * TakeProfitATR), _Digits);
      
      if(trade.Buy(lotSize, _Symbol, ask, sl, tp, TradeComment))
      {
         currentTicket = trade.ResultOrder();
         tradeOpenedToday = true;
         if(EnableAlerts) Alert("Long position opened at ", ask);
         return true;
      }
   }
   // Short signal
   else if(ask < lowerChannel)
   {
      double sl = NormalizeDouble(ask + (currentATR * TrailingStopATR), _Digits);
      double tp = NormalizeDouble(ask - (currentATR * TakeProfitATR), _Digits);
      
      if(trade.Sell(lotSize, _Symbol, bid, sl, tp, TradeComment))
      {
         currentTicket = trade.ResultOrder();
         tradeOpenedToday = true;
         if(EnableAlerts) Alert("Short position opened at ", bid);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage Open Trades                                              |
//+------------------------------------------------------------------+
void manageTrades()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_COMMENT) == TradeComment)
      {
         checkTrailingStop(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Check and Update Trailing Stop                                  |
//+------------------------------------------------------------------+
void checkTrailingStop(ulong ticket)
{
   double currentStop = PositionGetDouble(POSITION_SL);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   long type = PositionGetInteger(POSITION_TYPE);
   
   double newStop = 0;
   
   if(type == POSITION_TYPE_BUY)
   {
      newStop = NormalizeDouble(currentPrice - (currentATR * TrailingStopATR), _Digits);
      if(newStop > currentStop && newStop > entryPrice)
      {
         trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      newStop = NormalizeDouble(currentPrice + (currentATR * TrailingStopATR), _Digits);
      if(newStop < currentStop && newStop < entryPrice)
      {
         trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                         |
//+------------------------------------------------------------------+
void calculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tickValue == 0 || currentATR == 0)
   {
      Print("Error: Invalid tick value or ATR");
      lotSize = 0.1;
      return;
   }
   
   double riskAmount = balance * (RiskPercent / 100);
   double pointsAtRisk = currentATR * TrailingStopATR / _Point;
   lotSize = NormalizeDouble(riskAmount / (pointsAtRisk * tickValue), 2);
   
   // Apply broker limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lotSize = fmax(minLot, fmin(lotSize, maxLot));
}

//+------------------------------------------------------------------+
//| Check for New Bar                                               |
//+------------------------------------------------------------------+
bool isNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check Trading Time                                              |
//+------------------------------------------------------------------+
bool isTradingTime()
{
   MqlDateTime currentTime, startTime, endTime;
   TimeCurrent(currentTime);
   
   // Parse start time
   string startArray[];
   if(StringSplit(TradeStartTime, ':', startArray) != 2) return false;
   startTime.hour = (int)StringToInteger(startArray[0]);
   startTime.min = (int)StringToInteger(startArray[1]);
   
   // Parse end time
   string endArray[];
   if(StringSplit(TradeEndTime, ':', endArray) != 2) return false;
   endTime.hour = (int)StringToInteger(endArray[0]);
   endTime.min = (int)StringToInteger(endArray[1]);
   
   int currentMinutes = currentTime.hour * 60 + currentTime.min;
   int startMinutes = startTime.hour * 60 + startTime.min;
   int endMinutes = endTime.hour * 60 + endTime.min;
   
   return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}
//+------------------------------------------------------------------+
