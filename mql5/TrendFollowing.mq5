//+------------------------------------------------------------------+
//|                                               TrendFollowing.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Guardian Algo."
#property link      "https://guardian26.unaux.com/"
#property version   "1.02"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//================ INPUTS =================//
input double RiskPercent = 1.0;
input int EMA_Period = 50;
input int ATR_Period = 14;
input double RR_Ratio = 2.0;
input double ATR_Multiplier = 1.5;

input bool UseTrailingStop = true;

//--- Session Filter
input bool UseSessionFilter = true;
input int LondonStart = 8;
input int LondonEnd   = 17;
input int NYStart     = 13;
input int NYEnd       = 22;

//--- News Filter (SAFE VERSION)
input bool UseNewsFilter = true;
input int NewsPauseMinutes = 30;

input int ManualNewsHour = 14;
input int ManualNewsMinute = 30;

//================ GLOBALS =================//
int emaHandle, atrHandle;

//+------------------------------------------------------------------+
//| INIT                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   emaHandle = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_H1, ATR_Period);

   if(emaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| SESSION FILTER (FIXED)                                           |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
   if(!UseSessionFilter) return true;

   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);

   int hour = time.hour;

   bool london = (hour >= LondonStart && hour < LondonEnd);
   bool ny     = (hour >= NYStart && hour < NYEnd);

   return (london || ny);
}

//+------------------------------------------------------------------+
//| NEWS FILTER (SAFE VERSION)                                       |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   if(!UseNewsFilter) return false;

   MqlDateTime nowStruct;
   TimeToStruct(TimeCurrent(), nowStruct);

   int currentMinutes = nowStruct.hour * 60 + nowStruct.min;
   int newsMinutes = ManualNewsHour * 60 + ManualNewsMinute;

   int diff = MathAbs(currentMinutes - newsMinutes);

   if(diff <= NewsPauseMinutes)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| LOT CALC                                                        |
//+------------------------------------------------------------------+
double CalculateLot(double slPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = balance * RiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue == 0 || tickSize == 0) return 0.01;

   double lot = risk / (slPoints * tickValue / tickSize);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = NormalizeDouble(lot / step, 0) * step;

   return lot;
}

//+------------------------------------------------------------------+
//| CHECK POSITION                                                  |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| MAIN                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   DrawInfoPanel();
   
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_H1, 0);

   if(currentBar == lastBar) return;
   lastBar = currentBar;

   // FILTERS
   if(!IsTradingSession()) return;
   if(IsNewsTime()) return;

   if(HasOpenPosition())
   {
      ManageTrailingStop();
      return;
   }

   double ema[], atr[];
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(atr, true);

   CopyBuffer(emaHandle, 0, 0, 2, ema);
   CopyBuffer(atrHandle, 0, 0, 2, atr);

   double closePrev = iClose(_Symbol, PERIOD_H1, 1);
   double highPrev  = iHigh(_Symbol, PERIOD_H1, 1);
   double lowPrev   = iLow(_Symbol, PERIOD_H1, 1);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl, tp, lot;

   // BUY
   if(closePrev > ema[1] && ask > highPrev)
   {
      sl = ask - (atr[1] * ATR_Multiplier);
      double slPoints = (ask - sl) / _Point;

      lot = CalculateLot(slPoints);
      tp = ask + (atr[1] * ATR_Multiplier * RR_Ratio);

      trade.Buy(lot, _Symbol, ask, sl, tp);
   }

   // SELL
   if(closePrev < ema[1] && bid < lowPrev)
   {
      sl = bid + (atr[1] * ATR_Multiplier);
      double slPoints = (sl - bid) / _Point;

      lot = CalculateLot(slPoints);
      tp = bid - (atr[1] * ATR_Multiplier * RR_Ratio);

      trade.Sell(lot, _Symbol, bid, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                   |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!UseTrailingStop) return;

   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(atrHandle, 0, 0, 1, atr);

   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      double price, newSL;

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         newSL = price - atr[0];

         if(newSL > sl)
            trade.PositionModify(ticket, newSL, tp);
      }

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         newSL = price + atr[0];

         if(newSL < sl || sl == 0)
            trade.PositionModify(ticket, newSL, tp);
      }
   }
}
//+------------------------------------------------------------------+

void DrawInfoPanel()
{
   string session = "OFF";
   string news    = "OK";

   //--- SESSION DETECTION
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);

   int hour = time.hour;

   if(hour >= LondonStart && hour < LondonEnd)
      session = "LONDON";
   else if(hour >= NYStart && hour < NYEnd)
      session = "NEW YORK";

   //--- NEWS STATUS
   if(IsNewsTime())
      news = "BLOCKED";

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- DISPLAY TEXT
   string text =
      "=== TREND FOLLOWING EA ===\n" +
      "Session: " + session + "\n" +
      "News: " + news + "\n" +
      "Balance: R" + DoubleToString(balance, 2);

   Comment(text);
}
