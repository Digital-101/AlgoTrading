//+------------------------------------------------------------------+
//|                                                TelegramScalp.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Gold Scalping EA with Telegram Signals                          |
//+------------------------------------------------------------------+
#property strict
#include <WinUser32.mqh>

input string BotToken = "Btk";
input string ChatID = "Cid";
input double RiskPercent = 1.0;
input int StopLossPips = 15;
input int TakeProfitPips = 30;
input int MaxSpread = 20;
input int MagicNumber = 987654;
input int StartHour = 8;
input int EndHour = 18;

//+------------------------------------------------------------------+
//| Function to Send Messages to Telegram                           |
//+------------------------------------------------------------------+
void SendTelegramMessage(string message) {
    string botToken = "bTK";
    string chatID = "cID";
    string url = "https://api.telegram.org/bot" + botToken + "/sendMessage";
     char result[];  // Array to store the response
    string headers; // Empty headers
    string response; // String to capture response
    int timeout = 5000; // 5-second timeout

    // Properly format the POST data
    uchar postData[];
    string requestBody = "chat_id=" + chatID + "&text=" + message;
    StringToCharArray(requestBody, postData);

    ResetLastError();
    
    // Correct function call based on MT4's syntax
    int httpCode = WebRequest("POST", url, headers, timeout, postData, result, response);
    
    if (httpCode == -1) {
        Print("❌ WebRequest Failed: ", GetLastError());
    } else {
        Print("✅ Telegram Signal Sent Successfully! Response: ", response);
    }
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
//| Open Buy Order                                                  |
//+------------------------------------------------------------------+
void OpenBuy() {
    if (MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread) return;
    
    double lot = 0.01;
    int ticket = OrderSend(Symbol(), OP_BUY, lot, Ask, 3, Ask - StopLossPips * Point, Ask + TakeProfitPips * Point, "Gold Buy", MagicNumber, 0, Blue);
    
    if (ticket > 0) {
        string signal = "📈 Gold Buy Signal!\nEntry: " + DoubleToString(Ask, 2) +
                        "\nSL: " + DoubleToString(Ask - StopLossPips * Point, 2) +
                        "\nTP: " + DoubleToString(Ask + TakeProfitPips * Point, 2);
        SendTelegramMessage(signal);
    }
}

//+------------------------------------------------------------------+
//| Open Sell Order                                                 |
//+------------------------------------------------------------------+
void OpenSell() {
    if (MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread) return;

    double lot = 0.01;
    int ticket = OrderSend(Symbol(), OP_SELL, lot, Bid, 3, Bid + StopLossPips * Point, Bid - TakeProfitPips * Point, "Gold Sell", MagicNumber, 0, Red);
    
    if (ticket > 0) {
        string signal = "📉 Gold Sell Signal!\nEntry: " + DoubleToString(Bid, 2) +
                        "\nSL: " + DoubleToString(Bid + StopLossPips * Point, 2) +
                        "\nTP: " + DoubleToString(Bid - TakeProfitPips * Point, 2);
        SendTelegramMessage(signal);
    }
}

//+------------------------------------------------------------------+
//| EA Main Logic                                                   |
//+------------------------------------------------------------------+
void OnTick() {
    if (Hour() < StartHour || Hour() > EndHour) return;

    double emaShort = GetEMA(5, 0);
    double emaLong = GetEMA(20, 0);
    double rsiValue = GetRSI(0);

    if (emaShort > emaLong && rsiValue > 30) {
        OpenBuy();
    }

    if (emaShort < emaLong && rsiValue < 70) {
        OpenSell();
    }
}
