//+------------------------------------------------------------------+
//|                                               TrendFollowing.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Guardian Algo."
#property link      "https://guardian26.unaux.com/"
#property version   "1.01"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//---------------- INPUT PARAMETERS --------------------------------//
input double RiskPercent      = 1.0;
input int    EMA_Period       = 50;
input int    ATR_Period       = 14;
input double RR_Ratio         = 2.0;
input double ATR_Multiplier   = 1.5;
input bool   UseTrailingStop  = true;

//---------------- GLOBAL HANDLES ----------------------------------//
int emaHandle;
int atrHandle;

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   emaHandle = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_H1, ATR_Period);

   if(emaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("❌ Indicator initialization failed");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Check if there's already a trade on this symbol                  |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i=0; i<PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLot(double stopLossPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue == 0 || tickSize == 0) return 0.01;

   double lot = riskMoney / (stopLossPoints * tickValue / tickSize);

   // Broker limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = NormalizeDouble(lot / lotStep, 0) * lotStep;

   return lot;
}

//+------------------------------------------------------------------+
//| Main Trading Logic                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only trade on new candle
   static datetime lastTime = 0;
   datetime currentTime = iTime(_Symbol, PERIOD_H1, 0);

   if(currentTime == lastTime)
      return;

   lastTime = currentTime;

   if(HasOpenPosition())
   {
      ManageTrailingStop();
      return;
   }

   // Get indicator data
   double ema[], atr[];
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(atr, true);

   CopyBuffer(emaHandle, 0, 0, 3, ema);
   CopyBuffer(atrHandle, 0, 0, 3, atr);

   double closePrev = iClose(_Symbol, PERIOD_H1, 1);
   double highPrev  = iHigh(_Symbol, PERIOD_H1, 1);
   double lowPrev   = iLow(_Symbol, PERIOD_H1, 1);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double stopLoss, takeProfit, lot;

   //================ BUY =================//
   if(closePrev > ema[1] && ask > highPrev)
   {
      stopLoss = ask - (atr[1] * ATR_Multiplier);
      double slPoints = (ask - stopLoss) / _Point;

      lot = CalculateLot(slPoints);
      takeProfit = ask + (atr[1] * ATR_Multiplier * RR_Ratio);

      if(trade.Buy(lot, _Symbol, ask, stopLoss, takeProfit, "BUY GOLD"))
         Print("✅ BUY opened");
      else
         Print("❌ BUY failed: ", GetLastError());
   }

   //================ SELL ================//
   if(closePrev < ema[1] && bid < lowPrev)
   {
      stopLoss = bid + (atr[1] * ATR_Multiplier);
      double slPoints = (stopLoss - bid) / _Point;

      lot = CalculateLot(slPoints);
      takeProfit = bid - (atr[1] * ATR_Multiplier * RR_Ratio);

      if(trade.Sell(lot, _Symbol, bid, stopLoss, takeProfit, "SELL GOLD"))
         Print("✅ SELL opened");
      else
         Print("❌ SELL failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
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

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      double price, newSL;

      // BUY
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         newSL = price - (atr[0] * 1.2);

         if(newSL > sl)
            trade.PositionModify(ticket, newSL, tp);
      }

      // SELL
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
         price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         newSL = price + (atr[0] * 1.2);

         if(newSL < sl || sl == 0)
            trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
