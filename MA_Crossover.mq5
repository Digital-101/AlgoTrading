//+------------------------------------------------------------------+
//|                                             MA_Crossover_Bot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh> // Include the CTrade class

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input bool BotEnabled = true; // Enable/disable the bot
CTrade trade; // Declare the trade object

int OnInit()
  {
   // Initialization code
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Deinitialization code
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if (!BotEnabled) return; // Stop trading if the bot is disabled

   // Define currency pairs
   string symbols[] = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD"};
   double riskPercent = 1.0; // Risk 1% of account balance per trade
   double stopLossATR = 2.0; // Stop-loss multiplier based on ATR

   for (int i = 0; i < ArraySize(symbols); i++)
     {
      string symbol = symbols[i];
      double atr = iATR(symbol, PERIOD_CURRENT, 14); // Corrected iATR call
      double stopLoss = atr * stopLossATR;
      double takeProfit = stopLoss * 2; // 1:2 risk-reward ratio

      // Moving Average crossover strategy
      double maShort = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE); // Corrected iMA call
      double maLong = iMA(symbol, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE); // Corrected iMA call

      if (maShort > maLong && PositionsTotal() == 0)
        {
         double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE); // Corrected account balance
         double lot = balance * riskPercent / 100 / stopLoss;
         lot = NormalizeDouble(lot, 2); // Round to 2 decimal places

         trade.Buy(lot, symbol, askPrice, askPrice - stopLoss, askPrice + takeProfit, "MA Crossover Buy");
        }
      else if (maShort < maLong && PositionsTotal() == 0)
        {
         double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE); // Corrected account balance
         double lot = balance * riskPercent / 100 / stopLoss;
         lot = NormalizeDouble(lot, 2); // Round to 2 decimal places

         trade.Sell(lot, symbol, bidPrice, bidPrice + stopLoss, bidPrice - takeProfit, "MA Crossover Sell");
        }
     }
  }
