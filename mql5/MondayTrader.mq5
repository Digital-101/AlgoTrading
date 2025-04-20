//+------------------------------------------------------------------+
//|                     MondayTrader EA - MT5 Version                |
//|                 Copyright 2024, Forex Strategy Builder          |
//|                        https://www.forexsb.com                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Forex Strategy Builder"
#property link      "https://www.forexsb.com"
#property version   "1.11"
#property strict

#include <Trade/Trade.mqh>

// Input parameters
input double RiskPercent = 1.0;          // Risk per trade (% of balance)
input double TakeProfitMultiplier = 3;   // TP/SL ratio (3:1)
input int ATRPeriod = 14;                // ATR period for volatility
input int MaxTradesPerDay = 2;           // Maximum trades per session
input double LotSizeMultiplier = 0.1;    // Base lot size multiplier
input int StartHour = 0;                 // Trading start hour (GMT)
input int EndHour = 5;                   // Trading end hour (GMT)
input bool UseMondayOnly = true;         // Trade only on Mondays
input bool UseTrailingStop = true;       // Enable trailing stop
input double TrailingStep = 0.0020;      // Trailing stop step (200 pips)

// Global variables
CTrade trade;
int tradesToday = 0;
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("MondayTrader EA initialized.");
    Comment("MondayTrader EA loaded and running.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    Comment("MondayTrader EA running...");
    if (!IsTradingTime()) return;
    if (tradesToday >= MaxTradesPerDay) return;

    CheckForTrade();
    ManagePositions();
}

//+------------------------------------------------------------------+
//| Check if it's the correct trading time                           |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);

    if (UseMondayOnly && timeStruct.day_of_week != 1)
    {
        Comment("It's not Monday. EA idle.");
        return false;
    }

    if (timeStruct.hour >= StartHour && timeStruct.hour < EndHour)
        return true;

    return false;
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPoints)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (RiskPercent / 100.0);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotSize = (riskAmount / (stopLossPoints * tickValue)) * LotSizeMultiplier;
    lotSize = NormalizeDouble(lotSize, 2);

    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    if (lotSize < minLot) lotSize = minLot;
    if (lotSize > maxLot) lotSize = maxLot;

    return lotSize;
}

//+------------------------------------------------------------------+
//| Check for trade signal                                           |
//+------------------------------------------------------------------+
void CheckForTrade()
{
    if (TimeCurrent() - lastTradeTime < 60) return;

    double atr[];
    if (!CopyBuffer(iATR(_Symbol, PERIOD_H1, ATRPeriod), 0, 1, 1, atr)) return;
    double atrValue = atr[0];

    double stopLoss = atrValue * 1.5;
    double takeProfit = stopLoss * TakeProfitMultiplier;
    double lotSize = CalculateLotSize(stopLoss / _Point);

    if (CheckBuySignal())
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if (trade.Buy(lotSize, _Symbol, price, price - stopLoss, price + takeProfit, "Monday Buy"))
        {
            tradesToday++;
            lastTradeTime = TimeCurrent();
        }
    }
    else if (CheckSellSignal())
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (trade.Sell(lotSize, _Symbol, price, price + stopLoss, price - takeProfit, "Monday Sell"))
        {
            tradesToday++;
            lastTradeTime = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| Buy signal: Monday open gap down                                 |
//+------------------------------------------------------------------+
bool CheckBuySignal()
{
    double fridayClose = iClose(_Symbol, PERIOD_D1, 1);
    double mondayOpen = iOpen(_Symbol, PERIOD_D1, 0);
    return (mondayOpen < fridayClose && iClose(_Symbol, PERIOD_M15, 0) > mondayOpen);
}

//+------------------------------------------------------------------+
//| Sell signal: Monday open gap up                                  |
//+------------------------------------------------------------------+
bool CheckSellSignal()
{
    double fridayClose = iClose(_Symbol, PERIOD_D1, 1);
    double mondayOpen = iOpen(_Symbol, PERIOD_D1, 0);
    return (mondayOpen > fridayClose && iClose(_Symbol, PERIOD_M15, 0) < mondayOpen);
}

//+------------------------------------------------------------------+
//| Manage positions (trailing stop)                                 |
//+------------------------------------------------------------------+
void ManagePositions()
{
    if (!UseTrailingStop) return;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            long type = PositionGetInteger(POSITION_TYPE);

            if (type == POSITION_TYPE_BUY)
            {
                double newSl = currentPrice - TrailingStep;
                if (newSl > sl && newSl > openPrice)
                    trade.PositionModify(ticket, newSl, tp);
            }
            else if (type == POSITION_TYPE_SELL)
            {
                double newSl = currentPrice + TrailingStep;
                if (newSl < sl && newSl < openPrice)
                    trade.PositionModify(ticket, newSl, tp);
            }
        }
    }
} // end
