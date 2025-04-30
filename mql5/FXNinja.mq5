//+------------------------------------------------------------------+
//|                                                      FXNinja.mq5 |
//|                        Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.48"

//+------------------------------------------------------------------+
//| Includes                                                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>
#include <Indicators\BillWilliams.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
input int      MAPeriod = 35;             // MA Period (14-50)
input int      RSIPeriod = 14;            // RSI Period (10-20)
input int      BBPeriod = 20;             // Bollinger Bands Period (15-30)
input double   BBDeviation = 2.0;         // Bollinger Bands Deviation (1.5-2.5)
input double   StopLoss = 400;            // Stop Loss in points
input double   TakeProfit = 1000;         // Take Profit in points
input double   RiskPerTrade = 1.0;        // Risk % per trade
input int      MaxSlippage = 3;           // Maximum slippage
input color    BuyColor = clrDodgerBlue;  // Buy signal color
input color    SellColor = clrOrangeRed;  // Sell signal color
input int      FontSize = 12;             // Display font size
input double   MaxPositionSize = 1.0;     // Maximum lot size
input double   MinAccountBalance = 200.0; // Minimum account balance

//+------------------------------------------------------------------+
//| Global Variables                                                |
//+------------------------------------------------------------------+
CTrade trade;
int maHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int bbHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
datetime lastTradeTime = 0;
int todayTrades = 0;
datetime lastTradeDay = 0;
CChartObjectLabel infoLabel, signalLabel, maLabel, rsiLabel, bbLabel, lotSizeLabel, balanceLabel;

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   //Check if user is allowed to use program
   long accountCustomer = 2001048432;
   long accountNo = AccountInfoInteger(ACCOUNT_LOGIN);
   if(accountCustomer == accountNo)
     {
         Print(__FUNCTION__, "> License verified");
     }else{
         Print(__FUNCTION__, "> License is Invalid...");
         //ExpertRemove();
         return(INIT_FAILED);
     }

   // Initialize indicators with error checking
   maHandle = iMA(_Symbol, _Period, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE)
   {
      Print("Failed to create MA indicator: ", GetLastError());
      return(INIT_FAILED);
   }

   rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
   {
      Print("Failed to create RSI indicator: ", GetLastError());
      return(INIT_FAILED);
   }

   bbHandle = iBands(_Symbol, _Period, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE)
   {
      Print("Failed to create Bollinger Bands indicator: ", GetLastError());
      return(INIT_FAILED);
   }
   
   // Configure trade settings
   trade.SetExpertMagicNumber(12345);
   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Create display labels
   if(!CreateInfoLabels())
   {
      Print("Failed to create display labels");
      return(INIT_FAILED);
   }
   
   // Initialize trade counter
   MqlDateTime today;
   TimeCurrent(today);
   lastTradeDay = StructToTime(today);
   lastTradeTime = 0;
   
   Print("EA initialized successfully on ", _Symbol, " ", EnumToString(_Period));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Create information labels                                       |
//+------------------------------------------------------------------+
bool CreateInfoLabels()
{
   // Info label
   if(!infoLabel.Create(0, "InfoLabel", 0, 10, 20))
   {
      Print("Failed to create InfoLabel");
      return false;
   }
   infoLabel.Description("FX Ninja EA v2.48");
   infoLabel.Color(clrWhite);
   infoLabel.FontSize(FontSize);
   
   // Balance label
   if(!balanceLabel.Create(0, "BalanceLabel", 0, 10, 40))
   {
      Print("Failed to create BalanceLabel");
      return false;
   }
   balanceLabel.Color(clrWhite);
   balanceLabel.FontSize(FontSize);
   
   // Signal label
   if(!signalLabel.Create(0, "SignalLabel", 0, 10, 70))
   {
      Print("Failed to create SignalLabel");
      return false;
   }
   signalLabel.Description("Waiting for signal...");
   signalLabel.Color(clrGray);
   signalLabel.FontSize(FontSize + 2);
   
   // MA label
   if(!maLabel.Create(0, "MALabel", 0, 10, 100))
   {
      Print("Failed to create MALabel");
      return false;
   }
   maLabel.Color(clrGold);
   maLabel.FontSize(FontSize);
   
   // RSI label
   if(!rsiLabel.Create(0, "RSILabel", 0, 10, 130))
   {
      Print("Failed to create RSILabel");
      return false;
   }
   rsiLabel.Color(clrDeepSkyBlue);
   rsiLabel.FontSize(FontSize);
   
   // BB label
   if(!bbLabel.Create(0, "BBLabel", 0, 10, 160))
   {
      Print("Failed to create BBLabel");
      return false;
   }
   bbLabel.Color(clrLimeGreen);
   bbLabel.FontSize(FontSize);
   
   // Lot size label
   if(!lotSizeLabel.Create(0, "LotSizeLabel", 0, 10, 190))
   {
      Print("Failed to create LotSizeLabel");
      return false;
   }
   lotSizeLabel.Color(clrWhite);
   lotSizeLabel.FontSize(FontSize);
   
   return true;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicators
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   
   // Remove labels
   infoLabel.Delete();
   balanceLabel.Delete();
   signalLabel.Delete();
   maLabel.Delete();
   rsiLabel.Delete();
   bbLabel.Delete();
   lotSizeLabel.Delete();
}

//+------------------------------------------------------------------+
//| Calculate position size                                         |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance < MinAccountBalance) return 0.0;
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), MaxPositionSize);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double riskAmount = balance * RiskPerTrade / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue <= 0 || tickSize <= 0 || point <= 0 || StopLoss <= 0) return 0.0;
   
   double lotSize = riskAmount / (StopLoss * tickValue * (point / tickSize));
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Margin check
   double marginRequired;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginRequired))
      return 0.0;
   
   if(marginRequired > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      return 0.0;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Validate stop levels                                            |
//+------------------------------------------------------------------+
bool ValidateStops(double entryPrice, double &sl, double &tp, bool isBuy)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (stopLevel > 0 ? stopLevel : 10) * point + spread;
   
   if(isBuy)
   {
      sl = entryPrice - StopLoss * point;
      tp = entryPrice + TakeProfit * point;
      
      if(entryPrice - sl < minDist) sl = entryPrice - minDist;
      if(tp - entryPrice < minDist) tp = entryPrice + minDist;
      
      return (sl < entryPrice && tp > entryPrice);
   }
   else
   {
      sl = entryPrice + StopLoss * point;
      tp = entryPrice - TakeProfit * point;
      
      if(sl - entryPrice < minDist) sl = entryPrice + minDist;
      if(entryPrice - tp < minDist) tp = entryPrice - minDist;
      
      return (sl > entryPrice && tp < entryPrice);
   }
}

//+------------------------------------------------------------------+
//| Check if new trade is allowed                                   |
//+------------------------------------------------------------------+
bool IsNewTradeAllowed()
{
   if(PositionsTotal() > 0) return false;
   
   MqlDateTime today, lastTradeDate;
   TimeCurrent(today);
   TimeToStruct(lastTradeDay, lastTradeDate);
   
   if(today.day != lastTradeDate.day || today.mon != lastTradeDate.mon || today.year != lastTradeDate.year)
   {
      todayTrades = 0;
      lastTradeDay = StructToTime(today);
   }
   
   return (todayTrades < 5 && (TimeCurrent() - lastTradeTime >= 1800));
}

//+------------------------------------------------------------------+
//| Update display                                                  |
//+------------------------------------------------------------------+
void UpdateDisplay(double ma, double rsi, double bbUpper, double bbLower, double bbMiddle, string signal, double lots)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   balanceLabel.Description(StringFormat("Balance: %.2f | Equity: %.2f", balance, equity));
   balanceLabel.Color(equity < balance ? clrRed : clrLawnGreen);
   
   infoLabel.Description(StringFormat("FX Ninja v2.48 | %s %s | Trades: %d/5",
                                  _Symbol, EnumToString(_Period), todayTrades));
   
   signalLabel.Description("Signal: " + signal);
   signalLabel.Color(signal == "BUY" ? BuyColor : (signal == "SELL" ? SellColor : clrGray));
   
   maLabel.Description(StringFormat("MA(%d): %.5f", MAPeriod, ma));
   rsiLabel.Description(StringFormat("RSI(%d): %.2f", RSIPeriod, rsi));
   rsiLabel.Color(rsi > 70 ? SellColor : (rsi < 30 ? BuyColor : clrDeepSkyBlue));
   
   bbLabel.Description(StringFormat("BB(%d): %.5f | %.5f | %.5f", BBPeriod, bbUpper, bbMiddle, bbLower));
   lotSizeLabel.Description(StringFormat("Lot Size: %.2f", lots));
   lotSizeLabel.Color(lots <= 0 ? clrRed : clrWhite);
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;
   
   // Get indicator values
   double ma[1], rsi[1], bbUpper[1], bbLower[1], bbMiddle[1];
   if(CopyBuffer(maHandle, 0, 0, 1, ma) != 1 ||
      CopyBuffer(rsiHandle, 0, 0, 1, rsi) != 1 ||
      CopyBuffer(bbHandle, 1, 0, 1, bbUpper) != 1 ||
      CopyBuffer(bbHandle, 2, 0, 1, bbLower) != 1 ||
      CopyBuffer(bbHandle, 0, 0, 1, bbMiddle) != 1)
   {
      Print("Error copying indicator buffers");
      UpdateDisplay(0, 0, 0, 0, 0, "Data Error", 0);
      return;
   }
   
   // Get current prices
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Calculate lot size
   double lotSize = CalculateLotSize();
   if(lotSize <= 0)
   {
      UpdateDisplay(ma[0], rsi[0], bbUpper[0], bbLower[0], bbMiddle[0], "Lot Size Error", 0);
      return;
   }
   
   // Trading logic
   string signal = "None";
   if(IsNewTradeAllowed())
   {
      bool buyCondition = (rsi[0] < 30) && (bid < bbLower[0]);
      bool sellCondition = (rsi[0] > 70) && (bid > bbUpper[0]);
      
      if(buyCondition)
      {
         signal = "BUY";
         double sl, tp;
         if(ValidateStops(ask, sl, tp, true))
         {
            if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "RSI/BB Buy"))
            {
               todayTrades++;
               lastTradeTime = TimeCurrent();
               Print("Buy order executed at ", ask);
            }
         }
      }
      else if(sellCondition)
      {
         signal = "SELL";
         double sl, tp;
         if(ValidateStops(bid, sl, tp, false))
         {
            if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "RSI/BB Sell"))
            {
               todayTrades++;
               lastTradeTime = TimeCurrent();
               Print("Sell order executed at ", bid);
            }
         }
      }
   }
   
   // Update display
   UpdateDisplay(ma[0], rsi[0], bbUpper[0], bbLower[0], bbMiddle[0], signal, lotSize);
}
//+------------------------------------------------------------------+
