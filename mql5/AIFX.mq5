//+------------------------------------------------------------------+
//|                                                      BlackfxAI.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Blackfx AI Replica"
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

//--- Input Parameters
input int      FastLength = 9;       // Fast MA Length
input int      SlowLength = 21;      // Slow MA Length
input int      RsiLength = 14;       // RSI Length
input int      ConfidenceThreshold = 75;  // Min Confidence % (0-100)
input bool     RangeFilterEnabled = true; // Enable Range Filter?
input int      AtrLength = 14;       // ATR Length
input double   MinATR = 1.5;         // Min ATR (Volatility Threshold)

//--- Indicator Buffers
double FastMABuffer[];
double SlowMABuffer[];
double BuySignalBuffer[];
double SellSignalBuffer[];
double ConfidenceBuffer[];
double AtrBuffer[];

//--- Global Variables
int rsiHandle;
int atrHandle;
int stochHandle;
int fastMaHandle;
int slowMaHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, FastMABuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SlowMABuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BuySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ConfidenceBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, AtrBuffer, INDICATOR_CALCULATIONS);
   
   //--- Set indicator parameters
   ArraySetAsSeries(FastMABuffer, true);
   ArraySetAsSeries(SlowMABuffer, true);
   ArraySetAsSeries(BuySignalBuffer, true);
   ArraySetAsSeries(SellSignalBuffer, true);
   ArraySetAsSeries(ConfidenceBuffer, true);
   ArraySetAsSeries(AtrBuffer, true);
   
   //--- Set drawing styles
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrRoyalBlue);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrDarkOrange);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2);
   
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Triangle up
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, -10);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrLime);
   
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // Triangle down
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 10);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrRed);
   
   //--- Get indicator handles
   rsiHandle = iRSI(NULL, 0, RsiLength, PRICE_CLOSE);
   atrHandle = iATR(NULL, 0, AtrLength);
   stochHandle = iStochastic(NULL, 0, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   fastMaHandle = iMA(NULL, 0, FastLength, 0, MODE_EMA, PRICE_CLOSE);
   slowMaHandle = iMA(NULL, 0, SlowLength, 0, MODE_EMA, PRICE_CLOSE);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Check for minimum bars required
   if(rates_total < MathMax(FastLength, MathMax(SlowLength, MathMax(RsiLength, AtrLength))))
      return(0);
      
   //--- Set array as series
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   //--- Get calculated count
   int limit = rates_total - prev_calculated;
   if(prev_calculated > 0) limit++;
   
   //--- Copy MA values
   CopyBuffer(fastMaHandle, 0, 0, limit, FastMABuffer);
   CopyBuffer(slowMaHandle, 0, 0, limit, SlowMABuffer);
   
   //--- Main calculation loop
   for(int i = limit-1; i >= 0; i--)
   {
      //--- Get RSI, Stochastic and ATR values
      double rsi[1], stochK[1], stochD[1], atr[1];
      CopyBuffer(rsiHandle, 0, i, 1, rsi);
      CopyBuffer(stochHandle, 0, i, 1, stochK); // %K line
      CopyBuffer(atrHandle, 0, i, 1, atr);
      
      //--- Calculate confidence score
      ConfidenceBuffer[i] = (rsi[0] + stochK[0]) / 2.0;
      
      //--- Calculate ATR condition
      AtrBuffer[i] = atr[0];
      bool isVolatileEnough = (AtrBuffer[i] >= MinATR) || !RangeFilterEnabled;
      
      //--- Determine signals
      bool trendUp = FastMABuffer[i] > SlowMABuffer[i];
      bool trendDown = FastMABuffer[i] < SlowMABuffer[i];
      
      BuySignalBuffer[i] = EMPTY_VALUE;
      SellSignalBuffer[i] = EMPTY_VALUE;
      
      if(ConfidenceBuffer[i] >= ConfidenceThreshold && trendUp && isVolatileEnough)
         BuySignalBuffer[i] = low[i] - 10 * _Point;
      
      if(ConfidenceBuffer[i] <= (100 - ConfidenceThreshold) && trendDown && isVolatileEnough)
         SellSignalBuffer[i] = high[i] + 10 * _Point;
   }
   
   //--- Display confidence score on last bar
   if(prev_calculated == 0)
   {
      string text = "Confidence: " + DoubleToString(ConfidenceBuffer[0], 1) + "%";
      ObjectCreate(0, "ConfidenceLabel", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "ConfidenceLabel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, "ConfidenceLabel", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "ConfidenceLabel", OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, "ConfidenceLabel", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "ConfidenceLabel", OBJPROP_BGCOLOR, clrRoyalBlue);
      ObjectSetInteger(0, "ConfidenceLabel", OBJPROP_BACK, false);
      ObjectSetString(0, "ConfidenceLabel", OBJPROP_TEXT, text);
      ObjectSetString(0, "ConfidenceLabel", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "ConfidenceLabel", OBJPROP_FONTSIZE, 10);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, -1, OBJ_LABEL);
}
