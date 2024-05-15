//+------------------------------------------------------------------+
//|                                                   BB-RSI-opt.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


// Define Bollinger Bands and RSI parameters
input int BB_Period = 20;
input double BB_Deviation = 2.0;
input int RSI_Period = 14;
input double RSI_Overbought = 70.0;
input double RSI_Oversold = 30.0;
input double Interest_Rate = 0.05; // Annual interest rate

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   double upperBB, lowerBB, rsiValue;
    
    // Calculate Bollinger Bands
    if (!iBands(_Symbol, 0, BB_Period, BB_Deviation, 0, 0, upperBB, 0, lowerBB, 0))
        return;
    
    // Calculate RSI
    if (!iRSI(_Symbol, 0, RSI_Period, 0, 0, rsiValue))
        return;
    
    // Check conditions for opening a trade
    if (Close[1] < lowerBB && rsiValue < RSI_Oversold)
    {
        // Calculate investment return
        double entryPrice = Ask;
        double stopLoss = entryPrice - 100 * _Point; // Example: 100 pips stop loss
        double takeProfit = entryPrice + 200 * _Point; // Example: 200 pips take profit
        double investmentReturn = (takeProfit - entryPrice) / entryPrice;
        
        // Calculate interest on investment
        datetime tradeOpenTime = TimeCurrent();
        datetime tradeCloseTime = tradeOpenTime + 24 * 3600; // Close trade after 24 hours
        double timeDifferenceHours = (tradeCloseTime - tradeOpenTime) / 3600;
        double interestAmount = entryPrice * InvestmentReturn * Interest_Rate * timeDifferenceHours / 24.0; // Daily interest
        
        // Print investment return and interest
        Print("Investment Return: ", DoubleToString(investmentReturn * 100, 2), "%");
        Print("Interest Amount: ", DoubleToString(interestAmount, 2));
        
        // Place the trade
        OrderSend(_Symbol, OP_BUY, 0.1, entryPrice, 3, stopLoss, takeProfit, "Buy Trade", 0, 0, clrGreen);
    }
  }
//+------------------------------------------------------------------+
