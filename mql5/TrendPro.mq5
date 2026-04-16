//+------------------------------------------------------------------+
//|      Trend EA PRO - CLEAN GUI (AUTO TRADING)                     |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include <Controls/Dialog.mqh>
#include <Controls/Label.mqh>

CTrade trade;

//================ INPUTS =================//
input double RiskPercent = 1.0;
input int EMA_Period = 50;
input int ATR_Period = 14;

//================ GLOBALS =================//
int emaHandle, atrHandle;

//================ GUI CLASS =================//
class CMyPanel : public CAppDialog
{
public:
   CLabel title;

   CLabel sessionLbl, newsLbl, tradingLbl, tradesLbl;
   CLabel balanceLbl, equityLbl, profitLbl;

   bool CreatePanel()
   {
      if(!Create(0,"TrendFollowing",0,20,20,300,240))
         return false;

      // TITLE
      title.Create(0,"title",0,10,5,260,25);
      title.Text("📊 Trend EA PRO");
      title.FontSize(12);
      Add(title);

      int y = 35;

      // Labels
      sessionLbl.Create(0,"session",0,10,y,260,20); Add(sessionLbl); y+=22;
      newsLbl.Create(0,"news",0,10,y,260,20); Add(newsLbl); y+=22;
      tradingLbl.Create(0,"trading",0,10,y,260,20); Add(tradingLbl); y+=22;
      tradesLbl.Create(0,"trades",0,10,y,260,20); Add(tradesLbl); y+=25;

      balanceLbl.Create(0,"balance",0,10,y,260,20); Add(balanceLbl); y+=22;
      equityLbl.Create(0,"equity",0,10,y,260,20); Add(equityLbl); y+=22;
      profitLbl.Create(0,"profit",0,10,y,260,20); Add(profitLbl);

      return true;
   }

   void Update(string session,string news,int trades,double balance,double equity)
   {
      double profit = equity - balance;

      // TEXT
      sessionLbl.Text("Session   : " + session);
      newsLbl.Text("News      : " + news);
      tradingLbl.Text("Trading   : AUTO");
      tradesLbl.Text("Positions : " + IntegerToString(trades));

      balanceLbl.Text("Balance   : R" + DoubleToString(balance,2));
      equityLbl.Text("Equity    : R" + DoubleToString(equity,2));
      profitLbl.Text("Profit    : R" + DoubleToString(profit,2));

      // COLORS
      sessionLbl.Color(session=="OFF" ? clrRed : clrGreen);
      newsLbl.Color(news=="BLOCKED" ? clrRed : clrGreen);

      profitLbl.Color(profit>=0 ? clrGreen : clrRed);
   }
};

CMyPanel panel;

//+------------------------------------------------------------------+
//| INIT                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   emaHandle = iMA(_Symbol, PERIOD_H1, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_H1, ATR_Period);

   panel.CreatePanel();
   panel.Run();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| SESSION                                                         |
//+------------------------------------------------------------------+
string GetSession()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);

   if(t.hour >= 8 && t.hour < 17) return "LONDON";
   if(t.hour >= 13 && t.hour < 22) return "NEW YORK";
   return "OFF";
}

//+------------------------------------------------------------------+
//| NEWS                                                            |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);

   int now = t.hour*60 + t.min;
   int news = 14*60 + 30;

   return (MathAbs(now-news) <= 30);
}

//+------------------------------------------------------------------+
//| LOT SIZE                                                        |
//+------------------------------------------------------------------+
double LotSize(double slPoints)
{
   double risk = AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100.0;
   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   if(tickValue==0 || tickSize==0) return 0.01;

   return NormalizeDouble(risk/(slPoints*tickValue/tickSize),2);
}

//+------------------------------------------------------------------+
//| MAIN                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   string session = GetSession();
   string news = IsNewsTime() ? "BLOCKED" : "OK";

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int trades     = PositionsTotal();

   panel.Update(session, news, trades, balance, equity);

   // FILTERS
   if(session=="OFF") return;
   if(IsNewsTime()) return;

   // ONLY 1 TRADE AT A TIME
   if(trades > 0) return;

   static datetime lastBar=0;
   datetime current=iTime(_Symbol,PERIOD_H1,0);
   if(current==lastBar) return;
   lastBar=current;

   double ema[], atr[];
   ArraySetAsSeries(ema,true);
   ArraySetAsSeries(atr,true);

   // SAFE COPY
   if(CopyBuffer(emaHandle,0,0,2,ema) < 2) return;
   if(CopyBuffer(atrHandle,0,0,2,atr) < 2) return;

   double closePrev=iClose(_Symbol,PERIOD_H1,1);
   double openPrev=iOpen(_Symbol,PERIOD_H1,1);

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double spread = (ask - bid) / _Point;

   // Avoid high spread (important for GOLD)
   if(spread > 50) return;

   double lot, sl, tp;

   // ================= BUY LOGIC =================
   // Trend + bullish candle
   if(closePrev > ema[1] && closePrev > openPrev)
   {
      sl = bid - (atr[1] * 1.5);
      tp = bid + (atr[1] * 3.0);

      lot = LotSize((bid - sl)/_Point);

      if(lot > 0)
      {
         Print("BUY SIGNAL");
         trade.Buy(lot, _Symbol, ask, sl, tp);
      }
   }

   // ================= SELL LOGIC =================
   // Trend + bearish candle
   if(closePrev < ema[1] && closePrev < openPrev)
   {
      sl = ask + (atr[1] * 1.5);
      tp = ask - (atr[1] * 3.0);

      lot = LotSize((sl - ask)/_Point);

      if(lot > 0)
      {
         Print("SELL SIGNAL");
         trade.Sell(lot, _Symbol, bid, sl, tp);
      }
   }
}