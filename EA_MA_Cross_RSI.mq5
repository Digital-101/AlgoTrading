//+------------------------------------------------------------------+
//|                                              EA_MA_Cross_RSI.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//MA
int ma_Handle;
double ma_Buffer[];

//RSI
int rsi_Handle;
double rsi_Buffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   ma_Handle = iMA(_Symbol,_Period, 7,0,MODE_EMA,PRICE_CLOSE);
   rsi_Handle = iRSI(_Symbol, _Period, 3, PRICE_CLOSE);
   
   if(ma_Handle<0 || rsi_Handle<0)
     {
      Alert("Error trying to create Handles for indicator - error: ", GetLastError(), "!");
      return(-1);
     }
     
     //Add Indicator to chart
     ChartIndicatorAdd(0,0,ma_Handle);
     ChartIndicatorAdd(0,1,rsi_Handle);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(ma_Handle);
   IndicatorRelease(rsi_Handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//DATA CAPTURE
void OnTick()
  {
//---
   //Copy 3D data vector to buffer
   CopyBuffer(ma_Handle,0,0,3,ma_Buffer);
   CopyBuffer(rsi_Handle,0,0,3,rsi_Buffer);
    
   //sort data vector
   ArraySetAsSeries(ma_Buffer,true);
   ArraySetAsSeries(rsi_Buffer,true);
   
   Print("ma_Buffer = ", ma_Buffer[0]);
   Print("rsi_Buffer = ", rsi_Buffer[0]);
   Print("=====================================");
  }
//+------------------------------------------------------------------+
