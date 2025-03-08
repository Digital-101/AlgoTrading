//+------------------------------------------------------------------+
//|                                                    GoldScalp.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Gold Scalping EA for Small Accounts                             |
//+------------------------------------------------------------------+
#property strict

input double RiskPercent = 1.0; // Risk 1% per trade
input int StopLossPips = 15;   // Tight SL for small capital
input int TakeProfitPips = 30; // TP must be at least 2x SL
input int MaxSpread = 20;      // Avoid high spread trades
input int MagicNumber = 987654;
input int StartHour = 8;       // Trade only during London & NY session
input int EndHour = 18;

double AccountRiskLot() {
    double riskAmount = (AccountBalance() * RiskPercent) / 100;
    double lotSize = riskAmount / (StopLossPips * Point * MarketInfo(Symbol(), MODE_TICKVALUE));
    return NormalizeDouble(MathMax(0.01, lotSize), 2); // Minimum 0.01 lots
}

//+------------------------------------------------------------------+
//| Get Indicator Values                                            |
//+------------------------------------------------------------------+
double GetEMA(int period, int shift) {
    return iMA(Symbol(), 0, period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

double GetRSI(int shift) {
    return iRSI(Symbol(), 0, 14, PRICE_CLOSE, shift);
}

//+------------------------------------------------------------------+
//| Check Open Orders                                               |
//+------------------------------------------------------------------+
bool OrderExists(int type) {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderMagicNumber() == MagicNumber && OrderType() == type) return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Open Buy Order                                                  |
//+------------------------------------------------------------------+
void OpenBuy() {
    if (!OrderExists(OP_BUY) && MarketInfo(Symbol(), MODE_SPREAD) <= MaxSpread) {
        double lot = AccountRiskLot();
        OrderSend(Symbol(), OP_BUY, lot, Ask, 3, Ask - StopLossPips * Point, Ask + TakeProfitPips * Point, "Gold Buy", MagicNumber, 0, Blue);
    }
}

//+------------------------------------------------------------------+
//| Open Sell Order                                                 |
//+------------------------------------------------------------------+
void OpenSell() {
    if (!OrderExists(OP_SELL) && MarketInfo(Symbol(), MODE_SPREAD) <= MaxSpread) {
        double lot = AccountRiskLot();
        OrderSend(Symbol(), OP_SELL, lot, Bid, 3, Bid + StopLossPips * Point, Bid - TakeProfitPips * Point, "Gold Sell", MagicNumber, 0, Red);
    }
}

//+------------------------------------------------------------------+
//| EA Main Logic                                                   |
//+------------------------------------------------------------------+
void OnTick() {
    if (Hour() < StartHour || Hour() > EndHour) return; // Avoid trading outside session

    double emaShort = GetEMA(5, 0);
    double emaLong = GetEMA(20, 0);
    double rsiValue = GetRSI(0);

    // Buy Condition: EMA 5 crosses above EMA 20 + RSI above 30
    if (emaShort > emaLong && rsiValue > 30) {
        OpenBuy();
    }

    // Sell Condition: EMA 5 crosses below EMA 20 + RSI below 70
    if (emaShort < emaLong && rsiValue < 70) {
        OpenSell();
    }
}
 
//---
