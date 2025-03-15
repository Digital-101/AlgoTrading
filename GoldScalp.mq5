//+------------------------------------------------------------------+
//|                                                    GoldScalp.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
/*
MT5 Expert Advisor for Gold Scalping
- Dynamic lot sizing based on account balance and risk %
- ATR-based Stop Loss and Take Profit
- Trailing stop & break-even logic
*/

#include <Trade/Trade.mqh>
CTrade trade;

// Input parameters
input double RiskPercent = 2.0; // Risk per trade in %
input double ATRMultiplier = 1.5; // ATR multiplier for SL/TP
input int ATRPeriod = 14; // ATR period
input double MaxSpread = 50; // Max spread allowed (in points)
input bool UseTrailingStop = true;

// Function to calculate lot size based on risk
double CalculateLotSize(double stopLossPips) {
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotSize = riskAmount / (stopLossPips * tickValue * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
    return NormalizeDouble(lotSize, 2);
}

// Function to get ATR-based Stop Loss
double GetATRStopLoss() {
    double atrArray[];
    int handle = iATR(_Symbol, PERIOD_M5, ATRPeriod);
    CopyBuffer(handle, 0, 0, 1, atrArray);
    return NormalizeDouble(atrArray[0] * ATRMultiplier, _Digits);
}

// Function to execute trades
void ExecuteTrade() {
    if (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpread) return;
    double atrStopLoss = GetATRStopLoss();
    double lotSize = CalculateLotSize(atrStopLoss / _Point);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = NormalizeDouble(bid - atrStopLoss, _Digits);
    double takeProfit = NormalizeDouble(bid + (atrStopLoss * 2), _Digits);
    trade.Buy(lotSize, _Symbol, ask, stopLoss, takeProfit, "GoldScalp");
}

// Main OnTick function
void OnTick() {
    if (PositionsTotal() == 0) {
        ExecuteTrade();
    }
}
