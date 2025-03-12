//+------------------------------------------------------------------+
//|                                              NasdaqMondayTrader  |
//|                        Trades Nasdaq every Monday                |
//+------------------------------------------------------------------+
input double LotSize = 0.1;          // Lot size for trading
input int MagicNumber = 123456;      // Magic number for the EA
input string TelegramToken = "";     // Your Telegram bot token
input string ChatID = "";            // Your Telegram chat ID

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Check if inputs are valid
   if (LotSize <= 0 || MagicNumber <= 0 || TelegramToken == "" || ChatID == "")
     {
      Print("Error: Invalid input parameters.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Cleanup code if needed
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check if today is Monday
   if (DayOfWeek() == 1) // 1 = Monday
     {
      // Check if we already have an open position
      if (PositionsTotal() == 0)
        {
         // Place a buy order (example)
         int ticket = OrderSend(_Symbol, OP_BUY, LotSize, Ask, 3, 0, 0, "Monday Trade", MagicNumber);
         if (ticket > 0)
           {
            string message = "Buy order placed for " + _Symbol + " at " + DoubleToString(Ask, 5);
            SendTelegramMessage(TelegramToken, ChatID, message);
           }
         else
           {
            Print("Error placing order: ", GetLastError());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Function to send Telegram message                                |
//+------------------------------------------------------------------+
void SendTelegramMessage(string token, string chat_id, string text)
  {
   string url = "https://api.telegram.org/bot" + token + "/sendMessage?chat_id=" + chat_id + "&text=" + text;
   int result = WebRequest("GET", url, "", NULL, 0, NULL, 0, NULL, 0);
   if (result == -1)
     {
      Print("Error sending Telegram message: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Function to get the day of the week                              |
//+------------------------------------------------------------------+
int DayOfWeek()
  {
   MqlDateTime time;
   TimeCurrent(time);
   return time.day_of_week; // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  }
//+------------------------------------------------------------------+
